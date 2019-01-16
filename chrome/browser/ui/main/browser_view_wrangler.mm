// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/main/browser_view_wrangler.h"

#include "base/files/file_path.h"
#include "base/strings/sys_string_conversions.h"
#include "ios/chrome/browser/application_context.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#include "ios/chrome/browser/crash_report/crash_report_helper.h"
#import "ios/chrome/browser/device_sharing/device_sharing_manager.h"
#import "ios/chrome/browser/main/browser.h"
#import "ios/chrome/browser/sessions/session_ios.h"
#import "ios/chrome/browser/sessions/session_service_ios.h"
#import "ios/chrome/browser/sessions/session_window_ios.h"
#import "ios/chrome/browser/tabs/tab.h"
#import "ios/chrome/browser/tabs/tab_model.h"
#import "ios/chrome/browser/tabs/tab_model_observer.h"
#import "ios/chrome/browser/ui/browser_view_controller.h"
#import "ios/chrome/browser/ui/browser_view_controller_dependency_factory.h"
#import "ios/chrome/browser/ui/main/browser_coordinator.h"
#include "ios/public/provider/chrome/browser/chrome_browser_provider.h"
#import "ios/web/public/web_state/web_state.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

// Internal implementation of BrowserInterface -- for the most part a wrapper
// around BrowserCoordinator.
@interface WrangledBrowser : NSObject <BrowserInterface>

@property(nonatomic, weak, readonly) BrowserCoordinator* coordinator;

- (instancetype)initWithCoordinator:(BrowserCoordinator*)coordinator;

@end

@implementation WrangledBrowser

- (instancetype)initWithCoordinator:(BrowserCoordinator*)coordinator {
  if (self = [super init]) {
    _coordinator = coordinator;
  }
  return self;
}

- (UIViewController*)viewController {
  return self.coordinator.viewController;
}

- (BrowserViewController*)bvc {
  return self.coordinator.viewController;
}

- (TabModel*)tabModel {
  return self.coordinator.tabModel;
}

- (ios::ChromeBrowserState*)browserState {
  return self.coordinator.viewController.browserState;
}

- (BOOL)userInteractionEnabled {
  return self.coordinator.active;
}

- (void)setUserInteractionEnabled:(BOOL)userInteractionEnabled {
  self.coordinator.active = userInteractionEnabled;
}

- (BOOL)incognito {
  return self.browserState->IsOffTheRecord();
}

- (void)clearPresentedStateWithCompletion:(ProceduralBlock)completion
                           dismissOmnibox:(BOOL)dismissOmnibox {
  [self.coordinator clearPresentedStateWithCompletion:completion
                                       dismissOmnibox:dismissOmnibox];
}

@end

@interface BrowserViewWrangler ()<TabModelObserver> {
  ios::ChromeBrowserState* _browserState;
  __weak id<TabModelObserver> _tabModelObserver;
  __weak id<ApplicationCommands> _applicationCommandEndpoint;
  __weak id<BrowserStateStorageSwitching> _storageSwitcher;
  BOOL _isShutdown;

  std::unique_ptr<Browser> _mainBrowser;
  std::unique_ptr<Browser> _otrBrowser;
}

@property(nonatomic, strong, readwrite) WrangledBrowser* mainInterface;
@property(nonatomic, strong, readwrite) WrangledBrowser* incognitoInterface;

// Backing objects.
@property(nonatomic) BrowserCoordinator* mainBrowserCoordinator;
@property(nonatomic) BrowserCoordinator* incognitoBrowserCoordinator;
//@property(nonatomic, readonly) TabModel* mainTabModel;
//@property(nonatomic, readonly) TabModel* otrTabModel;
@property(nonatomic, readonly) Browser* mainBrowser;
@property(nonatomic, readonly) Browser* otrBrowser;

// Responsible for maintaining all state related to sharing to other devices.
// Redeclared readwrite from the readonly declaration in the Testing interface.
@property(nonatomic, strong, readwrite)
    DeviceSharingManager* deviceSharingManager;

// Creates a new autoreleased tab model for |browserState|; if |empty| is NO,
// then any existing tabs that have been saved for |browserState| will be
// loaded; otherwise, the tab model will be created empty.
- (TabModel*)tabModelForBrowserState:(ios::ChromeBrowserState*)browserState
                               empty:(BOOL)empty;

// Setters for the main and otr Browsers.
- (void)setMainBrowser:(std::unique_ptr<Browser>)browser;
- (void)setOtrBrowser:(std::unique_ptr<Browser>)browser;

// Creates a new off-the-record ("incognito") browser state for |_browserState|,
// then calls -tabModelForBrowserState:empty: and returns a Browser for the
// result.
- (std::unique_ptr<Browser>)buildOtrBrowser:(BOOL)empty;

// Creates the correct BrowserCoordinator for the corresponding browser state
// and Browser.
- (BrowserCoordinator*)coordinatorForBrowser:(Browser*)browser;
@end

@implementation BrowserViewWrangler

@synthesize currentInterface = _currentInterface;

- (instancetype)initWithBrowserState:(ios::ChromeBrowserState*)browserState
                    tabModelObserver:(id<TabModelObserver>)tabModelObserver
          applicationCommandEndpoint:
              (id<ApplicationCommands>)applicationCommandEndpoint
                     storageSwitcher:
                         (id<BrowserStateStorageSwitching>)storageSwitcher {
  if ((self = [super init])) {
    _browserState = browserState;
    _tabModelObserver = tabModelObserver;
    _applicationCommandEndpoint = applicationCommandEndpoint;
    _storageSwitcher = storageSwitcher;
  }
  return self;
}

- (void)dealloc {
  DCHECK(_isShutdown) << "-shutdown must be called before -dealloc";
}

- (void)createMainBrowser {
  TabModel* tabModel = [self tabModelForBrowserState:_browserState empty:NO];

  _mainBrowser = Browser::Create(_browserState, tabModel);
  // Follow loaded URLs in the main tab model to send those in case of
  // crashes.
  breakpad::MonitorURLsForTabModel(self.mainBrowser->GetTabModel());
  ios::GetChromeBrowserProvider()->InitializeCastService(
      self.mainBrowser->GetTabModel());
}

#pragma mark - BrowserViewInformation property implementations

- (void)setCurrentInterface:(WrangledBrowser*)interface {
  DCHECK(interface);
  // |interface| must be one of the interfaces this class already owns.
  DCHECK(self.mainInterface == interface ||
         self.incognitoInterface == interface);
  if (self.currentInterface == interface) {
    return;
  }

  if (self.currentInterface) {
    // Tell the current BVC it moved to the background.
    [self.currentInterface.bvc setPrimary:NO];

    // Data storage for the browser is always owned by the current BVC, so it
    // must be updated when switching between BVCs.
    [_storageSwitcher
        changeStorageFromBrowserState:self.currentInterface.browserState
                       toBrowserState:interface.browserState];
  }

  _currentInterface = interface;

  // The internal state of the Handoff Manager depends on the current BVC.
  [self updateDeviceSharingManager];
}

- (id<BrowserInterface>)mainInterface {
  if (!_mainInterface) {
    // The backing coordinator should not have been created yet.
    DCHECK(!_mainBrowserCoordinator);
    _mainBrowserCoordinator = [self coordinatorForBrowser:self.mainBrowser];
    [_mainBrowserCoordinator start];
    DCHECK(_mainBrowserCoordinator.viewController);
    _mainInterface =
        [[WrangledBrowser alloc] initWithCoordinator:_mainBrowserCoordinator];
  }
  return _mainInterface;
}

- (id<BrowserInterface>)incognitoInterface {
  if (!_incognitoInterface) {
    // The backing coordinator should not have been created yet.
    DCHECK(!_incognitoBrowserCoordinator);
    ios::ChromeBrowserState* otrBrowserState =
        _browserState->GetOffTheRecordChromeBrowserState();
    DCHECK(otrBrowserState);
    _incognitoBrowserCoordinator = [self coordinatorForBrowser:self.otrBrowser];
    [_incognitoBrowserCoordinator start];
    DCHECK(_incognitoBrowserCoordinator.viewController);
    _incognitoInterface = [[WrangledBrowser alloc]
        initWithCoordinator:_incognitoBrowserCoordinator];
  }
  return _incognitoInterface;
}

- (Browser*)mainBrowser {
  DCHECK(_mainBrowser.get())
      << "-createMainBrowser must be called before -mainBrowser is accessed.";
  return _mainBrowser.get();
}

- (Browser*)otrBrowser {
  if (!_otrBrowser) {
    _otrBrowser = [self buildOtrBrowser:NO];
  }
  return _otrBrowser.get();
}

- (void)setMainBrowser:(std::unique_ptr<Browser>)mainBrowser {
  if (_mainBrowser.get()) {
    TabModel* tabModel = self.mainBrowser->GetTabModel();
    breakpad::StopMonitoringTabStateForTabModel(tabModel);
    breakpad::StopMonitoringURLsForTabModel(tabModel);
    [tabModel browserStateDestroyed];
    if (_tabModelObserver) {
      [tabModel removeObserver:_tabModelObserver];
    }
    [tabModel removeObserver:self];
  }

  _mainBrowser = std::move(mainBrowser);
}

- (void)setOtrBrowser:(std::unique_ptr<Browser>)otrBrowser {
  if (_otrBrowser.get()) {
    TabModel* tabModel = self.otrBrowser->GetTabModel();
    breakpad::StopMonitoringTabStateForTabModel(tabModel);
    [tabModel browserStateDestroyed];
    if (_tabModelObserver) {
      [tabModel removeObserver:_tabModelObserver];
    }
    [tabModel removeObserver:self];
  }

  _otrBrowser = std::move(otrBrowser);
}

#pragma mark - BrowserViewInformation methods

- (void)haltAllTabs {
  [self.mainBrowser->GetTabModel() haltAllTabs];
  [self.otrBrowser->GetTabModel() haltAllTabs];
}

- (void)cleanDeviceSharingManager {
  [self.deviceSharingManager updateBrowserState:NULL];
}

#pragma mark - TabModelObserver

- (void)tabModel:(TabModel*)model
    didChangeActiveTab:(Tab*)newTab
           previousTab:(Tab*)previousTab
               atIndex:(NSUInteger)index {
  [self updateDeviceSharingManager];
}

- (void)tabModel:(TabModel*)model didChangeTab:(Tab*)tab {
  [self updateDeviceSharingManager];
}

#pragma mark - Other public methods

- (void)updateDeviceSharingManager {
  if (!self.deviceSharingManager) {
    self.deviceSharingManager = [[DeviceSharingManager alloc] init];
  }
  [self.deviceSharingManager updateBrowserState:_browserState];

  GURL activeURL;
  Tab* currentTab = self.currentInterface.tabModel.currentTab;
  // Set the active URL if there's a current tab and the current BVC is not OTR.
  if (currentTab.webState && !self.currentInterface.incognito) {
    activeURL = currentTab.webState->GetVisibleURL();
  }
  [self.deviceSharingManager updateActiveURL:activeURL];
}

- (void)destroyAndRebuildIncognitoBrowser {
  // It is theoretically possible that a Tab has been added to |_otrTabModel|
  // since the deletion has been scheduled. It is unlikely to happen for real
  // because it would require superhuman speed.
  DCHECK(![self.otrBrowser->GetTabModel() count]);
  DCHECK(_browserState);

  // Stop watching the OTR tab model's state for crashes.
  breakpad::StopMonitoringTabStateForTabModel(self.otrBrowser->GetTabModel());

  // At this stage, a new incognitoBrowserCoordinator shouldn't be lazily
  // constructed by calling the property getter.
  BOOL otrBVCIsCurrent = self.currentInterface == self.incognitoInterface;
  @autoreleasepool {
    // At this stage, a new incognitoBrowserCoordinator shouldn't be lazily
    // constructed by calling the property getter.
    [_incognitoBrowserCoordinator stop];
    _incognitoBrowserCoordinator = nil;
    _incognitoInterface = nil;

    // There's no guarantee the tab model was ever added to the BVC (or even
    // that the BVC was created), so ensure the tab model gets notified.
    [self setOtrBrowser:nullptr];
    if (otrBVCIsCurrent) {
      _currentInterface = nil;
    }
  }

  _browserState->DestroyOffTheRecordChromeBrowserState();

  // An empty _otrTabModel must be created at this point, because it is then
  // possible to prevent the tabChanged notification being sent. Otherwise,
  // when it is created, a notification with no tabs will be sent, and it will
  // be immediately deleted.
  [self setOtrBrowser:[self buildOtrBrowser:YES]];
  DCHECK(![self.otrBrowser->GetTabModel() count]);
  DCHECK(_browserState->HasOffTheRecordChromeBrowserState());

  if (otrBVCIsCurrent) {
    self.currentInterface = self.incognitoInterface;
  }
}

- (void)shutdown {
  DCHECK(!_isShutdown);
  _isShutdown = YES;

  // Disconnect the DeviceSharingManager.
  [self cleanDeviceSharingManager];

  // At this stage, new BrowserCoordinators shouldn't be lazily constructed by
  // calling their property getters.
  [_mainBrowserCoordinator stop];
  _mainBrowserCoordinator = nil;
  [_incognitoBrowserCoordinator stop];
  _incognitoBrowserCoordinator = nil;

  [self.mainBrowser->GetTabModel() closeAllTabs];
  [self.otrBrowser->GetTabModel() closeAllTabs];
  // Handles removing observers and stopping breakpad monitoring.
  [self setMainBrowser:nullptr];
  [self setOtrBrowser:nullptr];

  _browserState = nullptr;
}

#pragma mark - Internal methods

- (std::unique_ptr<Browser>)buildOtrBrowser:(BOOL)empty {
  DCHECK(_browserState);
  // Ensure that the OTR ChromeBrowserState is created.
  ios::ChromeBrowserState* otrBrowserState =
      _browserState->GetOffTheRecordChromeBrowserState();
  DCHECK(otrBrowserState);
  TabModel* tabModel = [self tabModelForBrowserState:otrBrowserState
                                               empty:empty];
  return Browser::Create(otrBrowserState, tabModel);
}

- (TabModel*)tabModelForBrowserState:(ios::ChromeBrowserState*)browserState
                               empty:(BOOL)empty {
  SessionWindowIOS* sessionWindow = nil;
  if (!empty) {
    // Load existing saved tab model state.
    NSString* statePath =
        base::SysUTF8ToNSString(browserState->GetStatePath().AsUTF8Unsafe());
    SessionIOS* session =
        [[SessionServiceIOS sharedService] loadSessionFromDirectory:statePath];
    if (session) {
      DCHECK_EQ(session.sessionWindows.count, 1u);
      sessionWindow = session.sessionWindows[0];
    }
  }

  // Create tab model from saved session (nil is ok).
  TabModel* tabModel =
      [[TabModel alloc] initWithSessionWindow:sessionWindow
                               sessionService:[SessionServiceIOS sharedService]
                                 browserState:browserState];
  // Add observers.
  if (_tabModelObserver) {
    [tabModel addObserver:_tabModelObserver];
    [tabModel addObserver:self];
  }
  breakpad::MonitorTabStateForTabModel(tabModel);

  return tabModel;
}

- (BrowserCoordinator*)coordinatorForBrowser:(Browser*)browser {
  BrowserCoordinator* coordinator = [[BrowserCoordinator alloc]
      initWithBaseViewController:nil
                    browserState:browser->GetBrowserState()];
  coordinator.tabModel = browser->GetTabModel();
  coordinator.applicationCommandHandler = _applicationCommandEndpoint;
  return coordinator;
}

@end
