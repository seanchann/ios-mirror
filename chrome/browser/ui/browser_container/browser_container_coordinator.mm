// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/browser_container/browser_container_coordinator.h"

#import <Availability.h>

#include "base/check.h"
#import "ios/chrome/browser/link_to_text/link_to_text_payload.h"
#import "ios/chrome/browser/main/browser.h"
#import "ios/chrome/browser/overlays/public/overlay_presenter.h"
#include "ios/chrome/browser/screen_time/screen_time_buildflags.h"
#import "ios/chrome/browser/ui/browser_container/browser_container_mediator.h"
#import "ios/chrome/browser/ui/browser_container/browser_container_view_controller.h"
#import "ios/chrome/browser/ui/commands/activity_service_commands.h"
#import "ios/chrome/browser/ui/commands/command_dispatcher.h"
#import "ios/chrome/browser/ui/commands/share_highlight_command.h"
#import "ios/chrome/browser/ui/link_to_text/link_to_text_consumer.h"
#import "ios/chrome/browser/ui/link_to_text/link_to_text_mediator.h"
#import "ios/chrome/browser/ui/overlays/overlay_container_coordinator.h"
#import "url/gurl.h"

#if BUILDFLAG(IOS_SCREEN_TIME_ENABLED)
#import "ios/chrome/browser/screen_time/features.h"
#import "ios/chrome/browser/ui/screen_time/screen_time_coordinator.h"
#endif

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface BrowserContainerCoordinator () <LinkToTextConsumer>
// Whether the coordinator is started.
@property(nonatomic, assign, getter=isStarted) BOOL started;
// Redefine property as readwrite.
@property(nonatomic, strong, readwrite)
    BrowserContainerViewController* viewController;
// The mediator used to configure the BrowserContainerConsumer.
@property(nonatomic, strong) BrowserContainerMediator* mediator;
// The mediator used for the Link to Text feature.
@property(nonatomic, strong) LinkToTextMediator* linkToTextMediator;
// The overlay container coordinator for OverlayModality::kWebContentArea.
@property(nonatomic, strong)
    OverlayContainerCoordinator* webContentAreaOverlayContainerCoordinator;
// The coodinator that manages ScreenTime.
@property(nonatomic, strong) ChromeCoordinator* screenTimeCoordinator;
// The handler for activity services commands.
@property(nonatomic, weak) id<ActivityServiceCommands> activityServiceHandler;
@end

@implementation BrowserContainerCoordinator

#pragma mark - ChromeCoordinator

- (void)start {
  if (self.started)
    return;
  self.started = YES;
  DCHECK(self.browser);
  DCHECK(!_viewController);
  self.viewController = [[BrowserContainerViewController alloc] init];
  self.webContentAreaOverlayContainerCoordinator =
      [[OverlayContainerCoordinator alloc]
          initWithBaseViewController:self.viewController
                             browser:self.browser
                            modality:OverlayModality::kWebContentArea];
  [self.webContentAreaOverlayContainerCoordinator start];
  self.viewController.webContentsOverlayContainerViewController =
      self.webContentAreaOverlayContainerCoordinator.viewController;
  OverlayPresenter* overlayPresenter = OverlayPresenter::FromBrowser(
      self.browser, OverlayModality::kWebContentArea);
  self.mediator = [[BrowserContainerMediator alloc]
                initWithWebStateList:self.browser->GetWebStateList()
      webContentAreaOverlayPresenter:overlayPresenter];
  self.activityServiceHandler = HandlerForProtocol(
      self.browser->GetCommandDispatcher(), ActivityServiceCommands);

  self.linkToTextMediator = [[LinkToTextMediator alloc]
      initWithWebStateList:self.browser->GetWebStateList()
                  consumer:self];
  self.viewController.linkToTextDelegate = self.linkToTextMediator;
  self.mediator.consumer = self.viewController;

  [self setUpScreenTimeIfEnabled];

  [super start];
}

- (void)stop {
  if (!self.started)
    return;
  self.started = NO;
  [self.webContentAreaOverlayContainerCoordinator stop];
  [self.screenTimeCoordinator stop];
  self.viewController = nil;
  self.mediator = nil;
  self.linkToTextMediator = nil;
  [super stop];
}

#pragma mark - LinkToTextConsumer

- (void)generatedPayload:(LinkToTextPayload*)payload {
  DCHECK(payload);
  ShareHighlightCommand* command =
      [[ShareHighlightCommand alloc] initWithURL:payload.URL
                                           title:payload.title
                                    selectedText:payload.selectedText
                                      sourceView:payload.sourceView
                                      sourceRect:payload.sourceRect];
  [self.activityServiceHandler shareHighlight:command];
}

- (void)linkGenerationFailed {
  // TODO(crbug.com/1136043): Show an alert.
}

#pragma mark - Private methods

// Sets up the ScreenTime coordinator, which installs and manages the ScreenTime
// blocking view.
- (void)setUpScreenTimeIfEnabled {
#if BUILDFLAG(IOS_SCREEN_TIME_ENABLED)
  if (!IsScreenTimeIntegrationEnabled())
    return;

  if (@available(iOS 14, *)) {
    ScreenTimeCoordinator* screenTimeCoordinator =
        [[ScreenTimeCoordinator alloc]
            initWithBaseViewController:self.viewController
                               browser:self.browser];
    [screenTimeCoordinator start];
    self.viewController.screenTimeViewController =
        screenTimeCoordinator.viewController;
    self.screenTimeCoordinator = screenTimeCoordinator;
  }
#endif
}

@end
