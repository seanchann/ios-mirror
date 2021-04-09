// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/app/application_delegate/app_state.h"

#include <memory>

#include "base/bind.h"
#include "base/ios/block_types.h"
#import "base/ios/ios_util.h"
#import "base/test/task_environment.h"
#import "ios/chrome/app/app_startup_parameters.h"
#import "ios/chrome/app/application_delegate/app_state_observer.h"
#import "ios/chrome/app/application_delegate/app_state_testing.h"
#import "ios/chrome/app/application_delegate/browser_launcher.h"
#import "ios/chrome/app/application_delegate/fake_startup_information.h"
#import "ios/chrome/app/application_delegate/memory_warning_helper.h"
#import "ios/chrome/app/application_delegate/metrics_mediator.h"
#import "ios/chrome/app/application_delegate/mock_tab_opener.h"
#import "ios/chrome/app/application_delegate/startup_information.h"
#import "ios/chrome/app/application_delegate/tab_switching.h"
#import "ios/chrome/app/application_delegate/user_activity_handler.h"
#import "ios/chrome/app/main_application_delegate.h"
#import "ios/chrome/app/safe_mode_app_state_agent.h"
#include "ios/chrome/app/safe_mode_app_state_agent.h"
#include "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#include "ios/chrome/browser/chrome_url_constants.h"
#import "ios/chrome/browser/device_sharing/device_sharing_manager.h"
#import "ios/chrome/browser/geolocation/omnibox_geolocation_config.h"
#import "ios/chrome/browser/main/browser.h"
#import "ios/chrome/browser/main/test_browser.h"
#include "ios/chrome/browser/ntp_snippets/ios_chrome_content_suggestions_service_factory.h"
#import "ios/chrome/browser/signin/authentication_service_factory.h"
#import "ios/chrome/browser/signin/authentication_service_fake.h"
#include "ios/chrome/browser/system_flags.h"
#import "ios/chrome/browser/ui/commands/application_commands.h"
#import "ios/chrome/browser/ui/commands/browser_commands.h"
#import "ios/chrome/browser/ui/commands/command_dispatcher.h"
#import "ios/chrome/browser/ui/commands/open_new_tab_command.h"
#import "ios/chrome/browser/ui/main/browser_interface_provider.h"
#import "ios/chrome/browser/ui/main/connection_information.h"
#import "ios/chrome/browser/ui/main/test/fake_scene_state.h"
#import "ios/chrome/browser/ui/main/test/stub_browser_interface.h"
#import "ios/chrome/browser/ui/main/test/stub_browser_interface_provider.h"
#import "ios/chrome/browser/ui/safe_mode/safe_mode_coordinator.h"
#import "ios/chrome/browser/ui/settings/settings_navigation_controller.h"
#include "ios/chrome/test/block_cleanup_test.h"
#include "ios/chrome/test/ios_chrome_scoped_testing_chrome_browser_provider.h"
#import "ios/chrome/test/scoped_key_window.h"
#include "ios/public/provider/chrome/browser/distribution/app_distribution_provider.h"
#include "ios/public/provider/chrome/browser/test_chrome_browser_provider.h"
#include "ios/public/provider/chrome/browser/user_feedback/test_user_feedback_provider.h"
#import "ios/testing/ocmock_complex_type_helper.h"
#import "ios/testing/scoped_block_swizzler.h"
#include "ios/web/public/test/web_task_environment.h"
#include "ios/web/public/thread/web_task_traits.h"
#import "third_party/ocmock/OCMock/OCMock.h"
#include "third_party/ocmock/gtest_support.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

// Exposes private safe mode start/stop methods.
@interface AppState (Private)
@property(nonatomic, strong) SafeModeCoordinator* safeModeCoordinator;

- (void)startSafeMode;
- (void)stopSafeMode;
- (void)coordinatorDidExitSafeMode:(SafeModeCoordinator*)coordinator;
@end

// App state observer that is used to replace the main controller to transition
// through stages.
@interface AppStateObserverToMockMainController : NSObject <AppStateObserver>
@end
@implementation AppStateObserverToMockMainController
- (void)appState:(AppState*)appState
    didTransitionFromInitStage:(InitStage)previousInitStage {
  if (appState.initStage == InitStageStart) {
    [appState queueTransitionToNextInitStage];
  }
}
@end

#pragma mark - Class definition.

namespace {

// A block that takes self as argument and return a BOOL.
typedef BOOL (^DecisionBlock)(id self);
// A block that takes the arguments of UserActivityHandler's
// +handleStartupParametersWithTabOpener.
typedef void (^HandleStartupParam)(
    id self,
    id<TabOpening> tabOpener,
    id<ConnectionInformation> connectionInformation,
    id<StartupInformation> startupInformation,
    ChromeBrowserState* browserState);
// A block ths returns values of AppState connectedScenes.
typedef NSArray<SceneState*>* (^ScenesBlock)(id self);

class FakeAppDistributionProvider : public AppDistributionProvider {
 public:
  FakeAppDistributionProvider() : cancel_called_(false) {}
  ~FakeAppDistributionProvider() override {}

  void CancelDistributionNotifications() override { cancel_called_ = true; }
  bool cancel_called() { return cancel_called_; }

 private:
  bool cancel_called_;
  DISALLOW_COPY_AND_ASSIGN(FakeAppDistributionProvider);
};

class FakeUserFeedbackProvider : public TestUserFeedbackProvider {
 public:
  FakeUserFeedbackProvider() : synchronize_called_(false) {}
  ~FakeUserFeedbackProvider() override {}
  void Synchronize() override { synchronize_called_ = true; }
  bool synchronize_called() { return synchronize_called_; }

 private:
  bool synchronize_called_;
  DISALLOW_COPY_AND_ASSIGN(FakeUserFeedbackProvider);
};

class FakeChromeBrowserProvider : public ios::TestChromeBrowserProvider {
 public:
  FakeChromeBrowserProvider()
      : app_distribution_provider_(
            std::make_unique<FakeAppDistributionProvider>()),
        user_feedback_provider_(std::make_unique<FakeUserFeedbackProvider>()) {}
  ~FakeChromeBrowserProvider() override {}

  AppDistributionProvider* GetAppDistributionProvider() const override {
    return app_distribution_provider_.get();
  }

  UserFeedbackProvider* GetUserFeedbackProvider() const override {
    return user_feedback_provider_.get();
  }

 private:
  std::unique_ptr<FakeAppDistributionProvider> app_distribution_provider_;
  std::unique_ptr<FakeUserFeedbackProvider> user_feedback_provider_;
  DISALLOW_COPY_AND_ASSIGN(FakeChromeBrowserProvider);
};

// Sets init stage expected transition calls from |start| to |end|.
void SetInitStageTransitionExpectations(id mock,
                                        AppState* app_state,
                                        InitStage start,
                                        InitStage end) {
  ASSERT_LE(end, InitStageFinal);
  ASSERT_GE(end, InitStageStart);

  InitStage current_stage = start;

  // Handle the particular case of InitStageStart.
  if (current_stage == InitStageStart) {
    [[mock expect] appState:app_state willTransitionToInitStage:InitStageStart];
    [[mock expect] appState:app_state
        didTransitionFromInitStage:InitStageStart];
  }

  while (current_stage != end) {
    InitStage next_stage = static_cast<InitStage>(current_stage + 1);
    [[mock expect] appState:app_state willTransitionToInitStage:next_stage];
    [[mock expect] appState:app_state didTransitionFromInitStage:current_stage];
    current_stage = next_stage;
  }
}

}  // namespace

// An app state observer that will call [AppState
// queueTransitionToNextInitStage] once (when a flag is set) from one of
// willTransitionToInitStage: and didTransitionFromInitStage: Defaults to
// willTransitioin.
@interface AppStateTransitioningObserver : NSObject <AppStateObserver>
// When set, will call queueTransitionToNextInitStage on
// didTransitionFromInitStage; otherwise, on willTransitionToInitStage
@property(nonatomic, assign) BOOL triggerOnDidTransition;
// Will do nothing when this is not set.
// Will call queueTransitionToNextInitStage on correct callback and reset this
// flag when it's set. The flag is init to YES when the object is created.
@property(nonatomic, assign) BOOL needsQueueTransition;
@end

@implementation AppStateTransitioningObserver

- (instancetype)init {
  self = [super init];
  if (self) {
    _needsQueueTransition = YES;
  }
  return self;
}

- (void)appState:(AppState*)appState
    willTransitionToInitStage:(InitStage)nextInitStage {
  if (self.needsQueueTransition && !self.triggerOnDidTransition) {
    [appState queueTransitionToNextInitStage];
    self.needsQueueTransition = NO;
  }
}

- (void)appState:(AppState*)appState
    didTransitionFromInitStage:(InitStage)previousInitStage {
  if (self.needsQueueTransition && self.triggerOnDidTransition) {
    [appState queueTransitionToNextInitStage];
    self.needsQueueTransition = NO;
  }
}
@end

class AppStateTest : public BlockCleanupTest {
 protected:
  AppStateTest() {
    // Init mocks.
    browser_launcher_mock_ =
        [OCMockObject mockForProtocol:@protocol(BrowserLauncher)];
    startup_information_mock_ =
        [OCMockObject mockForProtocol:@protocol(StartupInformation)];
    connection_information_mock_ =
        [OCMockObject mockForProtocol:@protocol(ConnectionInformation)];
    main_application_delegate_ =
        [OCMockObject mockForClass:[MainApplicationDelegate class]];
    window_ = [OCMockObject mockForClass:[UIWindow class]];
    app_state_observer_mock_ =
        [OCMockObject mockForProtocol:@protocol(AppStateObserver)];

    interface_provider_ = [[StubBrowserInterfaceProvider alloc] init];

    app_state_observer_to_mock_main_controller_ =
        [AppStateObserverToMockMainController alloc];
  }

  void SetUp() override {
    BlockCleanupTest::SetUp();
    TestChromeBrowserState::Builder test_cbs_builder;
    test_cbs_builder.AddTestingFactory(
        IOSChromeContentSuggestionsServiceFactory::GetInstance(),
        IOSChromeContentSuggestionsServiceFactory::GetDefaultFactory());
    test_cbs_builder.AddTestingFactory(
        AuthenticationServiceFactory::GetInstance(),
        base::BindRepeating(
            &AuthenticationServiceFake::CreateAuthenticationService));
    browser_state_ = test_cbs_builder.Build();
  }

  void swizzleConnectedScenes(NSArray<SceneState*>* connectedScenes) {
    connected_scenes_swizzle_block_ = ^NSArray<SceneState*>*(id self) {
      return connectedScenes;
    };
    connected_scenes_swizzler_.reset(
        new ScopedBlockSwizzler([AppState class], @selector(connectedScenes),
                                connected_scenes_swizzle_block_));
  }

  void swizzleSafeModeShouldStart(BOOL shouldStart) {
    safe_mode_swizzle_block_ = ^BOOL(id self) {
      return shouldStart;
    };
    safe_mode_swizzler_.reset(new ScopedBlockSwizzler(
        [SafeModeCoordinator class], @selector(shouldStart),
        safe_mode_swizzle_block_));
  }

  void swizzleMetricsMediatorDisableReporting() {
    metrics_mediator_called_ = NO;

    metrics_mediator_swizzle_block_ = ^{
      metrics_mediator_called_ = YES;
    };

    metrics_mediator_swizzler_.reset(new ScopedBlockSwizzler(
        [MetricsMediator class], @selector(disableReporting),
        metrics_mediator_swizzle_block_));
  }

  void swizzleHandleStartupParameters(
      id<TabOpening> expectedTabOpener,
      ChromeBrowserState* expectedBrowserState) {
    handle_startup_swizzle_block_ =
        ^(id self, id<TabOpening> tabOpener,
          id<ConnectionInformation> connectionInformation,
          id<StartupInformation> startupInformation,
          ChromeBrowserState* browserState) {
          ASSERT_EQ(connection_information_mock_, connectionInformation);
          ASSERT_EQ(startup_information_mock_, startupInformation);
          ASSERT_EQ(expectedTabOpener, tabOpener);
          ASSERT_EQ(expectedBrowserState, browserState);
        };

    handle_startup_swizzler_.reset(new ScopedBlockSwizzler(
        [UserActivityHandler class],
        @selector
        (handleStartupParametersWithTabOpener:
                        connectionInformation:startupInformation:browserState:),
        handle_startup_swizzle_block_));
  }

  AppState* getAppStateWithOpenNTP(BOOL shouldOpenNTP, UIWindow* window) {
    AppState* appState = getAppStateWithRealWindow(window);

    id application = [OCMockObject mockForClass:[UIApplication class]];
    id metricsMediator = [OCMockObject mockForClass:[MetricsMediator class]];
    id memoryHelper = [OCMockObject mockForClass:[MemoryWarningHelper class]];
    id tabOpener = [OCMockObject mockForProtocol:@protocol(TabOpening)];
    Browser* browser = interface_provider_.currentInterface.browser;

    [[metricsMediator stub] updateMetricsStateBasedOnPrefsUserTriggered:NO];
    [[memoryHelper stub] resetForegroundMemoryWarningCount];
    [[[memoryHelper stub] andReturnValue:@0] foregroundMemoryWarningCount];
    [[[tabOpener stub] andReturnValue:@(shouldOpenNTP)]
        shouldOpenNTPTabOnActivationOfBrowser:browser];

    void (^swizzleBlock)() = ^{
    };

    ScopedBlockSwizzler swizzler(
        [MetricsMediator class],
        @selector(logLaunchMetricsWithStartupInformation:connectedScenes:),
        swizzleBlock);

    [appState applicationWillEnterForeground:application
                             metricsMediator:metricsMediator
                                memoryHelper:memoryHelper];

    return appState;
  }

  SafeModeAppAgent* getSafeModeAppAgent() {
    if (!safe_mode_app_agent_) {
      safe_mode_app_agent_ = [[SafeModeAppAgent alloc] init];
    }
    return safe_mode_app_agent_;
  }

  AppState* getAppStateWithMock() {
    if (!app_state_) {
      // The swizzle block needs the scene state before app_state is create, but
      // the scene state needs the app state. So this alloc before swizzling
      // and initiate after app state is created.
      main_scene_state_ = [FakeSceneState alloc];
      swizzleConnectedScenes(@[ main_scene_state_ ]);

      app_state_ =
          [[AppState alloc] initWithBrowserLauncher:browser_launcher_mock_
                                 startupInformation:startup_information_mock_
                                applicationDelegate:main_application_delegate_];
      app_state_.mainSceneState = main_scene_state_;

      main_scene_state_ = [main_scene_state_ initWithAppState:app_state_];
      main_scene_state_.window = getWindowMock();

      [app_state_ addAgent:getSafeModeAppAgent()];
      [app_state_ addObserver:app_state_observer_to_mock_main_controller_];
    }
    return app_state_;
  }

  AppState* getAppStateWithRealWindow(UIWindow* window) {
    if (!app_state_) {
      // The swizzle block needs the scene state before app_state is create, but
      // the scene state needs the app state. So this alloc before swizzling
      // and initiate after app state is created.
      main_scene_state_ = [FakeSceneState alloc];
      swizzleConnectedScenes(@[ main_scene_state_ ]);

      app_state_ =
          [[AppState alloc] initWithBrowserLauncher:browser_launcher_mock_
                                 startupInformation:startup_information_mock_
                                applicationDelegate:main_application_delegate_];
      app_state_.mainSceneState = main_scene_state_;

      main_scene_state_ = [main_scene_state_ initWithAppState:app_state_];
      main_scene_state_.window = window;
      [window makeKeyAndVisible];

      [app_state_ addAgent:getSafeModeAppAgent()];
      [app_state_ addObserver:app_state_observer_to_mock_main_controller_];
    }
    return app_state_;
  }

  id getBrowserLauncherMock() { return browser_launcher_mock_; }
  id getStartupInformationMock() { return startup_information_mock_; }
  id getConnectionInformationMock() { return connection_information_mock_; }
  id getApplicationDelegateMock() { return main_application_delegate_; }
  id getWindowMock() { return window_; }
  id getAppStateObserverMock() { return app_state_observer_mock_; }
  StubBrowserInterfaceProvider* getInterfaceProvider() {
    return interface_provider_;
  }
  ChromeBrowserState* getBrowserState() { return browser_state_.get(); }

  BOOL metricsMediatorHasBeenCalled() { return metrics_mediator_called_; }


 private:
  web::WebTaskEnvironment task_environment_;
  AppState* app_state_;
  FakeSceneState* main_scene_state_;
  SafeModeAppAgent* safe_mode_app_agent_;
  AppStateObserverToMockMainController*
      app_state_observer_to_mock_main_controller_;
  id browser_launcher_mock_;
  id connection_information_mock_;
  id startup_information_mock_;
  id main_application_delegate_;
  id window_;
  id app_state_observer_mock_;
  StubBrowserInterfaceProvider* interface_provider_;
  ScenesBlock connected_scenes_swizzle_block_;
  DecisionBlock safe_mode_swizzle_block_;
  HandleStartupParam handle_startup_swizzle_block_;
  ProceduralBlock metrics_mediator_swizzle_block_;
  std::unique_ptr<ScopedBlockSwizzler> safe_mode_swizzler_;
  std::unique_ptr<ScopedBlockSwizzler> connected_scenes_swizzler_;
  std::unique_ptr<ScopedBlockSwizzler> handle_startup_swizzler_;
  std::unique_ptr<ScopedBlockSwizzler> metrics_mediator_swizzler_;
  __block BOOL metrics_mediator_called_;
  std::unique_ptr<TestChromeBrowserState> browser_state_;
};

// Used to have a thread handling the closing of the IO threads.
class AppStateWithThreadTest : public PlatformTest {
 protected:
  AppStateWithThreadTest()
      : task_environment_(web::WebTaskEnvironment::REAL_IO_THREAD) {}

 private:
  web::WebTaskEnvironment task_environment_;
};

#pragma mark - Tests.

// Tests that if the application is in background
// -requiresHandlingAfterLaunchWithOptions saves the launchOptions and returns
// YES (to handle the launch options later).
TEST_F(AppStateTest, requiresHandlingAfterLaunchWithOptionsBackground) {
  // Setup.
  NSString* sourceApplication = @"com.apple.mobilesafari";
  NSDictionary* launchOptions =
      @{UIApplicationLaunchOptionsSourceApplicationKey : sourceApplication};

  AppState* appState = getAppStateWithMock();

  id browserLauncherMock = getBrowserLauncherMock();
  [[browserLauncherMock expect] setLaunchOptions:launchOptions];

  // Action.
  BOOL result = [appState requiresHandlingAfterLaunchWithOptions:launchOptions
                                                 stateBackground:YES];

  // Test.
  EXPECT_TRUE(result);
  EXPECT_OCMOCK_VERIFY(browserLauncherMock);

  // Verify the launch stage is still at the point of initializing the browser
  // basics when the app is backgrounded.
  EXPECT_EQ(InitStageBrowserBasic, appState.initStage);
}

// Tests that if the application is active and Safe Mode should be activated
// -requiresHandlingAfterLaunchWithOptions save the launch options and activate
// the Safe Mode.
TEST_F(AppStateTest, requiresHandlingAfterLaunchWithOptionsForegroundSafeMode) {
  // Setup.
  NSString* sourceApplication = @"com.apple.mobilesafari";
  NSDictionary* launchOptions =
      @{UIApplicationLaunchOptionsSourceApplicationKey : sourceApplication};

  base::TimeTicks now = base::TimeTicks::Now();
  [[[getStartupInformationMock() stub] andReturnValue:@YES] isColdStart];
  [[[getStartupInformationMock() stub] andDo:^(NSInvocation* invocation) {
    [invocation setReturnValue:(void*)&now];
  }] appLaunchTime];

  id windowMock = getWindowMock();
  [[[windowMock stub] andReturn:nil] rootViewController];
  [[windowMock expect] setRootViewController:[OCMArg any]];
  [[windowMock expect] makeKeyAndVisible];

  AppState* appState = getAppStateWithMock();
  ASSERT_FALSE([appState isInSafeMode]);

  id appStateObserverMock = getAppStateObserverMock();
  SetInitStageTransitionExpectations(appStateObserverMock, appState,
                                     InitStageStart, InitStageFinal);
  [appState addObserver:appStateObserverMock];
  id browserLauncherMock = getBrowserLauncherMock();
  [[browserLauncherMock expect] setLaunchOptions:launchOptions];

  // Expected calls on AppState#coordinatorDidExitSafeMode.
  [[appStateObserverMock expect] appStateDidExitSafeMode:appState];
  [[browserLauncherMock expect]
      startUpBrowserToStage:INITIALIZATION_STAGE_FOREGROUND];
  id applicationDelegateMock = getApplicationDelegateMock();
  [[applicationDelegateMock expect]
      applicationDidBecomeActive:[UIApplication sharedApplication]];

  swizzleSafeModeShouldStart(YES);

  appState.mainSceneState.activationLevel =
      SceneActivationLevelForegroundActive;

  // Action.
  BOOL result = [appState requiresHandlingAfterLaunchWithOptions:launchOptions
                                                 stateBackground:NO];

  if (base::ios::IsMultiwindowSupported()) {
    // Start the safe mode by transitioning the scene to foreground again after
    // #requiresHandlingAfterLaunchWithOptions which starts the safe mode.
    appState.mainSceneState.activationLevel =
        SceneActivationLevelForegroundActive;
  }

  EXPECT_TRUE(result);
  EXPECT_TRUE([appState isInSafeMode]);

  // Stop safe mode.
  [appState coordinatorDidExitSafeMode:appState.safeModeCoordinator];

  // Verify that the dependencies are called properly during the app journey.
  EXPECT_OCMOCK_VERIFY(windowMock);
  EXPECT_OCMOCK_VERIFY(browserLauncherMock);
  EXPECT_OCMOCK_VERIFY(appStateObserverMock);
  EXPECT_OCMOCK_VERIFY(applicationDelegateMock);

  EXPECT_EQ(InitStageFinal, appState.initStage);
}

// Tests that if the application is active
// -requiresHandlingAfterLaunchWithOptions saves the launchOptions and start the
// application in foreground.
TEST_F(AppStateTest, requiresHandlingAfterLaunchWithOptionsForeground) {
  // Setup.
  NSString* sourceApplication = @"com.apple.mobilesafari";
  NSDictionary* launchOptions =
      @{UIApplicationLaunchOptionsSourceApplicationKey : sourceApplication};

  [[[getStartupInformationMock() stub] andReturnValue:@YES] isColdStart];

  [[[getWindowMock() stub] andReturn:nil] rootViewController];

  AppState* appState = getAppStateWithMock();
  ASSERT_FALSE([appState isInSafeMode]);

  id appStateObserverMock = getAppStateObserverMock();
  SetInitStageTransitionExpectations(appStateObserverMock, appState,
                                     InitStageStart, InitStageFinal);

  [appState addObserver:appStateObserverMock];

  id applicationDelegateMock = getApplicationDelegateMock();
  [[applicationDelegateMock expect]
      applicationDidBecomeActive:[UIApplication sharedApplication]];

  id browserLauncherMock = getBrowserLauncherMock();
  BrowserInitializationStageType stageForeground =
      INITIALIZATION_STAGE_FOREGROUND;
  [[browserLauncherMock expect] startUpBrowserToStage:stageForeground];
  [[browserLauncherMock expect] setLaunchOptions:launchOptions];

  swizzleSafeModeShouldStart(NO);

  // Action.
  BOOL result = [appState requiresHandlingAfterLaunchWithOptions:launchOptions
                                                 stateBackground:NO];

  // Test.
  EXPECT_TRUE(result);
  EXPECT_EQ(InitStageFinal, appState.initStage);

  // Verify that the dependencies were called properly.
  EXPECT_OCMOCK_VERIFY(browserLauncherMock);
  EXPECT_OCMOCK_VERIFY(appStateObserverMock);
}

using AppStateNoFixtureTest = PlatformTest;

// Test that -willResignActive set cold start to NO and launch record.
TEST_F(AppStateNoFixtureTest, willResignActive) {
  // Setup.
  base::test::TaskEnvironment task_environment_;
  std::unique_ptr<Browser> browser = std::make_unique<TestBrowser>();

  StubBrowserInterfaceProvider* interfaceProvider =
      [[StubBrowserInterfaceProvider alloc] init];
  interfaceProvider.mainInterface.browser = browser.get();

  id browserLauncher =
      [OCMockObject mockForProtocol:@protocol(BrowserLauncher)];
  [[[browserLauncher stub] andReturnValue:@(INITIALIZATION_STAGE_FOREGROUND)]
      browserInitializationStage];
  [[[browserLauncher stub] andReturn:interfaceProvider] interfaceProvider];

  id applicationDelegate =
      [OCMockObject mockForClass:[MainApplicationDelegate class]];

  FakeStartupInformation* startupInformation =
      [[FakeStartupInformation alloc] init];
  [startupInformation setIsColdStart:YES];

  AppState* appState =
      [[AppState alloc] initWithBrowserLauncher:browserLauncher
                             startupInformation:startupInformation
                            applicationDelegate:applicationDelegate];

  ASSERT_TRUE([startupInformation isColdStart]);

  // Action.
  [appState willResignActiveTabModel];

  // Test.
  EXPECT_FALSE([startupInformation isColdStart]);
}

// Test that -applicationWillTerminate clears everything.
TEST_F(AppStateWithThreadTest, willTerminate) {
  // Setup.
  IOSChromeScopedTestingChromeBrowserProvider provider_(
      std::make_unique<FakeChromeBrowserProvider>());

  id browserLauncher =
      [OCMockObject mockForProtocol:@protocol(BrowserLauncher)];
  id applicationDelegate =
      [OCMockObject mockForClass:[MainApplicationDelegate class]];
  StubBrowserInterfaceProvider* interfaceProvider =
      [[StubBrowserInterfaceProvider alloc] init];
  interfaceProvider.mainInterface.userInteractionEnabled = YES;

  [[[browserLauncher stub] andReturnValue:@(INITIALIZATION_STAGE_FOREGROUND)]
      browserInitializationStage];
  [[[browserLauncher stub] andReturn:interfaceProvider] interfaceProvider];

  id startupInformation =
      [OCMockObject mockForProtocol:@protocol(StartupInformation)];
  [[startupInformation expect] stopChromeMain];

  AppState* appState =
      [[AppState alloc] initWithBrowserLauncher:browserLauncher
                             startupInformation:startupInformation
                            applicationDelegate:applicationDelegate];

  // Create a scene state so that full shutdown will run.
  if (!base::ios::IsSceneStartupSupported()) {
    appState.mainSceneState = [[SceneState alloc] initWithAppState:appState];
  }

  id application = [OCMockObject mockForClass:[UIApplication class]];

  // Action.
  [appState applicationWillTerminate:application];

  // Test.
  EXPECT_OCMOCK_VERIFY(startupInformation);
  EXPECT_OCMOCK_VERIFY(application);
  EXPECT_FALSE(interfaceProvider.mainInterface.userInteractionEnabled);
  FakeAppDistributionProvider* provider =
      static_cast<FakeAppDistributionProvider*>(
          ios::GetChromeBrowserProvider()->GetAppDistributionProvider());
  EXPECT_TRUE(provider->cancel_called());
}

// Test that -resumeSessionWithTabOpener
// restart metrics and launchs from StartupParameters if they exist.
TEST_F(AppStateTest, resumeSessionWithStartupParameters) {
  if (base::ios::IsSceneStartupSupported()) {
    // TODO(crbug.com/1045579): Session restoration not available yet in MW.
    return;
  }
  // Setup.

  // BrowserLauncher.
  StubBrowserInterfaceProvider* interfaceProvider = getInterfaceProvider();
  [[[getBrowserLauncherMock() stub]
      andReturnValue:@(INITIALIZATION_STAGE_FOREGROUND)]
      browserInitializationStage];
  [[[getBrowserLauncherMock() stub] andReturn:interfaceProvider]
      interfaceProvider];

  // StartupInformation.
  id appStartupParameters =
      [OCMockObject mockForClass:[AppStartupParameters class]];
  [[[getConnectionInformationMock() stub] andReturn:appStartupParameters]
      startupParameters];
  [[[getStartupInformationMock() stub] andReturnValue:@NO] isColdStart];

  // TabOpening.
  id tabOpener = [OCMockObject mockForProtocol:@protocol(TabOpening)];
  // TabSwitcher.
  id tabSwitcher = [OCMockObject mockForProtocol:@protocol(TabSwitching)];

  // BrowserViewInformation.
  std::unique_ptr<Browser> browser =
      std::make_unique<TestBrowser>(getBrowserState());
  interfaceProvider.mainInterface.browser = browser.get();
  interfaceProvider.mainInterface.browserState = getBrowserState();

  // Swizzle Startup Parameters.
  swizzleHandleStartupParameters(tabOpener, getBrowserState());

  ScopedKeyWindow scopedKeyWindow;
  AppState* appState = getAppStateWithOpenNTP(NO, scopedKeyWindow.Get());

  // Action.
  [appState resumeSessionWithTabOpener:tabOpener
                           tabSwitcher:tabSwitcher
                 connectionInformation:getConnectionInformationMock()];
}

// Test that -resumeSessionWithTabOpener
// restart metrics and creates a new tab from tab switcher if shouldOpenNTP is
// YES.
TEST_F(AppStateTest, resumeSessionShouldOpenNTPTabSwitcher) {
  if (base::ios::IsSceneStartupSupported()) {
    // TODO(crbug.com/1045579): Session restoration not available yet in MW.
    return;
  }

  // Setup.
  // BrowserLauncher.
  StubBrowserInterfaceProvider* interfaceProvider = getInterfaceProvider();
  [[[getBrowserLauncherMock() stub]
      andReturnValue:@(INITIALIZATION_STAGE_FOREGROUND)]
      browserInitializationStage];
  [[[getBrowserLauncherMock() stub] andReturn:interfaceProvider]
      interfaceProvider];

  // StartupInformation.
  [[[getConnectionInformationMock() stub] andReturn:nil] startupParameters];
  [[[getStartupInformationMock() stub] andReturnValue:@NO] isColdStart];

  // BrowserViewInformation.
  std::unique_ptr<Browser> browser =
      std::make_unique<TestBrowser>(getBrowserState());
  interfaceProvider.mainInterface.browser = browser.get();
  interfaceProvider.mainInterface.browserState = getBrowserState();

  // TabOpening.
  id tabOpener = [OCMockObject mockForProtocol:@protocol(TabOpening)];
  [[[tabOpener stub] andReturnValue:@YES]
      shouldOpenNTPTabOnActivationOfBrowser:browser.get()];

  // TabSwitcher.
  id tabSwitcher = [OCMockObject mockForProtocol:@protocol(TabSwitching)];
  [[[tabSwitcher stub] andReturnValue:@YES] openNewTabFromTabSwitcher];

  ScopedKeyWindow scopedKeyWindow;
  AppState* appState = getAppStateWithOpenNTP(YES, scopedKeyWindow.Get());

  // Action.
  [appState resumeSessionWithTabOpener:tabOpener
                           tabSwitcher:tabSwitcher
                 connectionInformation:getConnectionInformationMock()];

  // Test.
  EXPECT_EQ(NSUInteger(0), [scopedKeyWindow.Get() subviews].count);
}

// Test that -resumeSessionWithTabOpener,
// restart metrics and creates a new tab if shouldOpenNTP is YES.
TEST_F(AppStateTest, resumeSessionShouldOpenNTPNoTabSwitcher) {
  if (base::ios::IsSceneStartupSupported()) {
    // TODO(crbug.com/1045579): Session restoration not available yet in MW.
    return;
  }
  // Setup.
  // BrowserLauncher.
  StubBrowserInterfaceProvider* interfaceProvider = getInterfaceProvider();
  [[[getBrowserLauncherMock() stub]
      andReturnValue:@(INITIALIZATION_STAGE_FOREGROUND)]
      browserInitializationStage];
  [[[getBrowserLauncherMock() stub] andReturn:interfaceProvider]
      interfaceProvider];

  // StartupInformation.
  [[[getConnectionInformationMock() stub] andReturn:nil] startupParameters];
  [[[getStartupInformationMock() stub] andReturnValue:@NO] isColdStart];

  // BrowserViewInformation.
  id applicationCommandEndpoint =
      [OCMockObject mockForProtocol:@protocol(ApplicationCommands)];
  [((id<ApplicationCommands>)[applicationCommandEndpoint expect])
      openURLInNewTab:[OCMArg any]];

  std::unique_ptr<Browser> browser =
      std::make_unique<TestBrowser>(getBrowserState());
  [browser->GetCommandDispatcher()
      startDispatchingToTarget:applicationCommandEndpoint
                   forProtocol:@protocol(ApplicationCommands)];
  // To fully conform to ApplicationCommands, the dispatcher needs to dispatch
  // for ApplicationSettingsCommands as well.
  id applicationSettingsCommandEndpoint =
      [OCMockObject mockForProtocol:@protocol(ApplicationSettingsCommands)];
  [browser->GetCommandDispatcher()
      startDispatchingToTarget:applicationSettingsCommandEndpoint
                   forProtocol:@protocol(ApplicationSettingsCommands)];
  interfaceProvider.mainInterface.browser = browser.get();
  interfaceProvider.mainInterface.browserState = getBrowserState();

  // TabOpening.
  id tabOpener = [OCMockObject mockForProtocol:@protocol(TabOpening)];
  [[[tabOpener stub] andReturnValue:@YES]
      shouldOpenNTPTabOnActivationOfBrowser:browser.get()];

  // TabSwitcher.
  id tabSwitcher = [OCMockObject mockForProtocol:@protocol(TabSwitching)];
  [[[tabSwitcher stub] andReturnValue:@NO] openNewTabFromTabSwitcher];

  ScopedKeyWindow scopedKeyWindow;
  AppState* appState = getAppStateWithOpenNTP(YES, scopedKeyWindow.Get());

  // Action.
  [appState resumeSessionWithTabOpener:tabOpener
                           tabSwitcher:tabSwitcher
                 connectionInformation:getConnectionInformationMock()];

  // Test.
  EXPECT_EQ(NSUInteger(0), [scopedKeyWindow.Get() subviews].count);
}

// Tests that -applicationWillEnterForeground resets components as needed.
TEST_F(AppStateTest, applicationWillEnterForeground) {
  // Setup.
  IOSChromeScopedTestingChromeBrowserProvider provider_(
      std::make_unique<FakeChromeBrowserProvider>());
  id application = [OCMockObject mockForClass:[UIApplication class]];
  id metricsMediator = [OCMockObject mockForClass:[MetricsMediator class]];
  id memoryHelper = [OCMockObject mockForClass:[MemoryWarningHelper class]];
  StubBrowserInterfaceProvider* interfaceProvider = getInterfaceProvider();
  id tabOpener = [OCMockObject mockForProtocol:@protocol(TabOpening)];
  std::unique_ptr<Browser> browser = std::make_unique<TestBrowser>();

  BrowserInitializationStageType stage = INITIALIZATION_STAGE_FOREGROUND;
  [[[getBrowserLauncherMock() stub] andReturnValue:@(stage)]
      browserInitializationStage];
  [[[getBrowserLauncherMock() stub] andReturn:interfaceProvider]
      interfaceProvider];
  interfaceProvider.mainInterface.browserState = getBrowserState();

  [[metricsMediator expect] updateMetricsStateBasedOnPrefsUserTriggered:NO];
  [[memoryHelper expect] resetForegroundMemoryWarningCount];
  [[[memoryHelper stub] andReturnValue:@0] foregroundMemoryWarningCount];
  [[[tabOpener stub] andReturnValue:@YES]
      shouldOpenNTPTabOnActivationOfBrowser:browser.get()];

  // Simulate background before going to foreground.
  [[getStartupInformationMock() expect] expireFirstUserActionRecorder];
  swizzleMetricsMediatorDisableReporting();
  [getAppStateWithMock() applicationDidEnterBackground:application
                                          memoryHelper:memoryHelper];

  void (^swizzleBlock)() = ^{
  };

  ScopedBlockSwizzler swizzler(
      [MetricsMediator class],
      @selector(logLaunchMetricsWithStartupInformation:connectedScenes:),
      swizzleBlock);

  // Actions.
  [getAppStateWithMock() applicationWillEnterForeground:application
                                        metricsMediator:metricsMediator
                                           memoryHelper:memoryHelper];

  // Tests.
  EXPECT_OCMOCK_VERIFY(metricsMediator);
  EXPECT_OCMOCK_VERIFY(memoryHelper);
  EXPECT_OCMOCK_VERIFY(getStartupInformationMock());
  FakeUserFeedbackProvider* user_feedback_provider =
      static_cast<FakeUserFeedbackProvider*>(
          ios::GetChromeBrowserProvider()->GetUserFeedbackProvider());
  EXPECT_TRUE(user_feedback_provider->synchronize_called());
}

// Tests that -applicationWillEnterForeground starts the browser if the
// application is in background.
TEST_F(AppStateTest, applicationWillEnterForegroundFromBackground) {
  // Setup.
  id application = [OCMockObject mockForClass:[UIApplication class]];
  id metricsMediator = [OCMockObject mockForClass:[MetricsMediator class]];
  id memoryHelper = [OCMockObject mockForClass:[MemoryWarningHelper class]];

  BrowserInitializationStageType stage = INITIALIZATION_STAGE_BACKGROUND;
  [[[getBrowserLauncherMock() stub] andReturnValue:@(stage)]
      browserInitializationStage];

  [[[getWindowMock() stub] andReturn:nil] rootViewController];
  swizzleSafeModeShouldStart(NO);

  [[[getStartupInformationMock() stub] andReturnValue:@YES] isColdStart];
  [[getBrowserLauncherMock() expect]
      startUpBrowserToStage:INITIALIZATION_STAGE_FOREGROUND];

  // Actions.
  [getAppStateWithMock() applicationWillEnterForeground:application
                                        metricsMediator:metricsMediator
                                           memoryHelper:memoryHelper];

  // Tests.
  EXPECT_OCMOCK_VERIFY(getBrowserLauncherMock());
}

// Tests that -applicationWillEnterForeground starts the safe mode if the
// application is in background.
TEST_F(AppStateTest,
       applicationWillEnterForegroundFromBackgroundShouldStartSafeMode) {
  if (base::ios::IsMultiwindowSupported()) {
    // In Multi Window, this is not the case. Skip this test.
    return;
  }
  // Setup.
  id application = [OCMockObject mockForClass:[UIApplication class]];
  id metricsMediator = [OCMockObject mockForClass:[MetricsMediator class]];
  id memoryHelper = [OCMockObject mockForClass:[MemoryWarningHelper class]];

  base::TimeTicks now = base::TimeTicks::Now();
  [[[getStartupInformationMock() stub] andReturnValue:@YES] isColdStart];
  [[[getStartupInformationMock() stub] andDo:^(NSInvocation* invocation) {
    [invocation setReturnValue:(void*)&now];
  }] appLaunchTime];

  id window = getWindowMock();

  BrowserInitializationStageType stage = INITIALIZATION_STAGE_BACKGROUND;
  [[[getBrowserLauncherMock() stub] andReturnValue:@(stage)]
      browserInitializationStage];

  [[[window stub] andReturn:nil] rootViewController];
  [[window stub] setRootViewController:[OCMArg any]];
  swizzleSafeModeShouldStart(YES);

  // The helper below calls makeKeyAndVisible.
  [[window expect] makeKeyAndVisible];

  AppState* appState = getAppStateWithRealWindow(window);
  id browserLauncherMock = getBrowserLauncherMock();
  NSDictionary* launchOptions = @{};
  [[browserLauncherMock expect] setLaunchOptions:launchOptions];

  [appState requiresHandlingAfterLaunchWithOptions:launchOptions
                                   stateBackground:YES];

  // Starting safe mode will call makeKeyAndVisible on the window.
  [[window expect] makeKeyAndVisible];
  appState.mainSceneState.activationLevel =
      SceneActivationLevelForegroundActive;
  appState.mainSceneState.window = window;

  // Actions.
  [appState applicationWillEnterForeground:application
                           metricsMediator:metricsMediator
                              memoryHelper:memoryHelper];

  // Tests.
  EXPECT_OCMOCK_VERIFY(window);

  // Verify that the app is still in safe mode after initializing the UI when
  // entering foreground from background.
  EXPECT_TRUE([appState isInSafeMode]);

  EXPECT_EQ(InitStageSafeMode, appState.initStage);
}

// Tests that -applicationDidEnterBackground calls the metrics mediator.
TEST_F(AppStateTest, applicationDidEnterBackgroundIncognito) {
  // Setup.
  ScopedKeyWindow scopedKeyWindow;
  id application = [OCMockObject niceMockForClass:[UIApplication class]];
  id memoryHelper = [OCMockObject mockForClass:[MemoryWarningHelper class]];
  StubBrowserInterfaceProvider* interfaceProvider = getInterfaceProvider();

  std::unique_ptr<Browser> browser = std::make_unique<TestBrowser>();
  id startupInformation = getStartupInformationMock();
  id browserLauncher = getBrowserLauncherMock();
  BrowserInitializationStageType stage = INITIALIZATION_STAGE_FOREGROUND;

  AppState* appState = getAppStateWithRealWindow(scopedKeyWindow.Get());

  [[startupInformation expect] expireFirstUserActionRecorder];
  [[[memoryHelper stub] andReturnValue:@0] foregroundMemoryWarningCount];
  interfaceProvider.incognitoInterface.browser = browser.get();
  [[[browserLauncher stub] andReturnValue:@(stage)] browserInitializationStage];
  [[[browserLauncher stub] andReturn:interfaceProvider] interfaceProvider];

  swizzleMetricsMediatorDisableReporting();

  // Action.
  [appState applicationDidEnterBackground:application
                             memoryHelper:memoryHelper];

  // Tests.
  EXPECT_OCMOCK_VERIFY(startupInformation);
  EXPECT_TRUE(metricsMediatorHasBeenCalled());
}

// Tests that -applicationDidEnterBackground do nothing if the application has
// never been in a Foreground stage.
TEST_F(AppStateTest, applicationDidEnterBackgroundStageBackground) {
  // Setup.
  ScopedKeyWindow scopedKeyWindow;
  id application = [OCMockObject mockForClass:[UIApplication class]];
  id memoryHelper = [OCMockObject mockForClass:[MemoryWarningHelper class]];
  id browserLauncher = getBrowserLauncherMock();
  BrowserInitializationStageType stage = INITIALIZATION_STAGE_BACKGROUND;

  [[[browserLauncher stub] andReturnValue:@(stage)] browserInitializationStage];
  [[[browserLauncher stub] andReturn:nil] interfaceProvider];

  ASSERT_EQ(NSUInteger(0), [scopedKeyWindow.Get() subviews].count);

  // Action.
  [getAppStateWithRealWindow(scopedKeyWindow.Get())
      applicationDidEnterBackground:application
                       memoryHelper:memoryHelper];

  // Tests.
  EXPECT_EQ(NSUInteger(0), [scopedKeyWindow.Get() subviews].count);
}

// Tests that -queueTransitionToNextInitStage transitions to the next stage.
TEST_F(AppStateTest, queueTransitionToNextInitStage) {
  AppState* appState = getAppStateWithMock();
  ASSERT_EQ(appState.initStage, InitStageStart);
  [appState queueTransitionToNextInitStage];
  ASSERT_EQ(appState.initStage, static_cast<InitStage>(InitStageStart + 1));
}

// Tests that -queueTransitionToNextInitStage notifies observers.
TEST_F(AppStateTest, queueTransitionToNextInitStageNotifiesObservers) {
  // Setup.
  AppState* appState = getAppStateWithMock();
  id observer = [OCMockObject mockForProtocol:@protocol(AppStateObserver)];
  InitStage secondStage = static_cast<InitStage>(InitStageStart + 1);
  [appState addObserver:observer];

  [[[observer expect] andDo:^(NSInvocation*) {
    // Verify that the init stage isn't yet increased when calling
    // #willTransitionToInitStage.
    EXPECT_EQ(InitStageStart, appState.initStage);
  }] appState:appState willTransitionToInitStage:secondStage];
  [[[observer expect] andDo:^(NSInvocation*) {
    // Verify that the init stage is increased when calling
    // #didTransitionFromInitStage.
    EXPECT_EQ(secondStage, appState.initStage);
  }] appState:appState didTransitionFromInitStage:InitStageStart];

  [appState queueTransitionToNextInitStage];

  EXPECT_EQ(secondStage, appState.initStage);

  [observer verify];
}

// Tests that -queueTransitionToNextInitStage, when called from an observer's
// call, first completes sending previous updates and doesn't change the init
// stage, then transitions to the next init stage and sends updates.
TEST_F(AppStateTest,
       queueTransitionToNextInitStageReentrantFromWillTransitionToInitStage) {
  // Setup.
  AppState* appState = getAppStateWithMock();
  id observer1 = [OCMockObject mockForProtocol:@protocol(AppStateObserver)];
  AppStateTransitioningObserver* transitioningObserver =
      [[AppStateTransitioningObserver alloc] init];
  id observer2 = [OCMockObject mockForProtocol:@protocol(AppStateObserver)];

  InitStage secondStage = static_cast<InitStage>(InitStageStart + 1);
  InitStage thirdStage = static_cast<InitStage>(InitStageStart + 2);

  // The order is important here.
  [appState addObserver:observer1];
  [appState addObserver:transitioningObserver];
  [appState addObserver:observer2];

  // The order is important here. We want to first receive all notifications for
  // the second stage, then all the notifications for the third stage, despite
  // transitioningObserver queueing a new transition from one of the callbacks.
  [[observer1 expect] appState:appState willTransitionToInitStage:secondStage];
  [[observer1 expect] appState:appState
      didTransitionFromInitStage:InitStageStart];
  [[observer2 expect] appState:appState willTransitionToInitStage:secondStage];
  [[observer2 expect] appState:appState
      didTransitionFromInitStage:InitStageStart];
  [[observer1 expect] appState:appState willTransitionToInitStage:thirdStage];
  [[observer1 expect] appState:appState didTransitionFromInitStage:secondStage];
  [[observer2 expect] appState:appState willTransitionToInitStage:thirdStage];
  [[observer2 expect] appState:appState didTransitionFromInitStage:secondStage];
  [observer1 setExpectationOrderMatters:YES];
  [observer2 setExpectationOrderMatters:YES];

  [appState queueTransitionToNextInitStage];
  [observer1 verify];
  [observer2 verify];
}

// Tests that -queueTransitionToNextInitStage, when called from an observer's
// call, first completes sending previous updates and doesn't change the init
// stage, then transitions to the next init stage and sends updates.
TEST_F(AppStateTest,
       queueTransitionToNextInitStageReentrantFromdidTransitionFromInitStage) {
  // Setup.
  AppState* appState = getAppStateWithMock();
  id observer1 = [OCMockObject mockForProtocol:@protocol(AppStateObserver)];
  AppStateTransitioningObserver* transitioningObserver =
      [[AppStateTransitioningObserver alloc] init];
  transitioningObserver.triggerOnDidTransition = YES;
  id observer2 = [OCMockObject mockForProtocol:@protocol(AppStateObserver)];

  InitStage secondStage = static_cast<InitStage>(InitStageStart + 1);
  InitStage thirdStage = static_cast<InitStage>(InitStageStart + 2);

  // The order is important here.
  [appState addObserver:observer1];
  [appState addObserver:transitioningObserver];
  [appState addObserver:observer2];

  // The order is important here. We want to first receive all notifications for
  // the second stage, then all the notifications for the third stage, despite
  // transitioningObserver queueing a new transition from one of the callbacks.
  [[observer1 expect] appState:appState willTransitionToInitStage:secondStage];
  [[observer1 expect] appState:appState
      didTransitionFromInitStage:InitStageStart];
  [[observer2 expect] appState:appState willTransitionToInitStage:secondStage];
  [[observer2 expect] appState:appState
      didTransitionFromInitStage:InitStageStart];
  [[observer1 expect] appState:appState willTransitionToInitStage:thirdStage];
  [[observer1 expect] appState:appState didTransitionFromInitStage:secondStage];
  [[observer2 expect] appState:appState willTransitionToInitStage:thirdStage];
  [[observer2 expect] appState:appState didTransitionFromInitStage:secondStage];
  [observer1 setExpectationOrderMatters:YES];
  [observer2 setExpectationOrderMatters:YES];

  [appState queueTransitionToNextInitStage];
  [observer1 verify];
  [observer2 verify];
}
