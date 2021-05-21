// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/default_promo/default_browser_promo_non_modal_scheduler.h"

#import "base/time/time.h"
#import "ios/chrome/browser/main/browser.h"
#import "ios/chrome/browser/main/browser_observer_bridge.h"
#import "ios/chrome/browser/overlays/public/overlay_presenter.h"
#import "ios/chrome/browser/overlays/public/overlay_presenter_observer_bridge.h"
#import "ios/chrome/browser/ui/commands/application_commands.h"
#import "ios/chrome/browser/ui/commands/command_dispatcher.h"
#import "ios/chrome/browser/ui/default_promo/default_browser_promo_non_modal_commands.h"
#import "ios/chrome/browser/ui/default_promo/default_browser_promo_non_modal_metrics_util.h"
#import "ios/chrome/browser/ui/default_promo/default_browser_utils.h"
#import "ios/chrome/browser/ui/main/scene_state.h"
#import "ios/chrome/browser/web_state_list/active_web_state_observation_forwarder.h"
#include "ios/chrome/browser/web_state_list/web_state_list.h"
#import "ios/chrome/browser/web_state_list/web_state_list_observer_bridge.h"
#import "ios/web/public/web_state.h"
#import "ios/web/public/web_state_observer_bridge.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

// Default time interval to wait to show the promo after loading a webpage.
// This should allow any initial overlays to be presented first.
const NSTimeInterval kShowPromoWebpageLoadWaitTime = 3;

// Default time interval to wait to show the promo after the share action is
// completed.
const NSTimeInterval kShowPromoPostShareWaitTime = 1;

// Number of times to show the promo to a user.
const int kPromoShownTimesLimit = 2;

bool PromoCanBeDisplayed() {
  return !UserInPromoCooldown() &&
         UserInteractionWithNonModalPromoCount() < kPromoShownTimesLimit;
}

typedef NS_ENUM(NSUInteger, PromoReason) {
  PromoReasonNone,
  PromoReasonOmniboxPaste,
  PromoReasonExternalLink,
  PromoReasonShare
};

}  // namespace

@interface DefaultBrowserPromoNonModalScheduler () <WebStateListObserving,
                                                    CRWWebStateObserver,
                                                    OverlayPresenterObserving,
                                                    BrowserObserving> {
  std::unique_ptr<WebStateListObserverBridge> _webStateListObserver;
  std::unique_ptr<web::WebStateObserverBridge> _webStateObserver;
  std::unique_ptr<ActiveWebStateObservationForwarder> _forwarder;
  std::unique_ptr<OverlayPresenterObserverBridge> _overlayObserver;
  // Observe the browser the web state list is tied to to deregister any
  // observers before the browser is destroyed.
  std::unique_ptr<BrowserObserverBridge> _browserObserver;
}

// Type of the promo being triggered, use for metrics only.
@property(nonatomic) NonModalPromoTriggerType promoTypeForMetrics;

// Time when a non modal promo was shown on screen, used for metrics only.
@property(nonatomic) base::TimeTicks promoShownTime;

// Timer for showing the promo after page load.
@property(nonatomic, strong) NSTimer* showPromoTimer;

// Timer for dismissing the promo after it is shown.
@property(nonatomic, strong) NSTimer* dismissPromoTimer;

// WebState that the triggering event occured in.
@property(nonatomic, assign) web::WebState* webStateToListenTo;

// The handler used to respond to the promo show/hide commands.
@property(nonatomic, readonly) id<DefaultBrowserPromoNonModalCommands> handler;

// Whether or not the promo is currently showing.
@property(nonatomic, assign) BOOL promoIsShowing;

// The web state list used to listen to page load and
// WebState change events.
@property(nonatomic, assign) WebStateList* webStateList;

// The overlay presenter used to prevent the
// promo from showing over an overlay.
@property(nonatomic, assign) OverlayPresenter* overlayPresenter;

// The trigger reason for the in-progress promo flow.
@property(nonatomic, assign) PromoReason currentPromoReason;

@end

@implementation DefaultBrowserPromoNonModalScheduler

- (instancetype)init {
  if (self = [super init]) {
    _webStateListObserver = std::make_unique<WebStateListObserverBridge>(self);
    _webStateObserver = std::make_unique<web::WebStateObserverBridge>(self);
    _overlayObserver = std::make_unique<OverlayPresenterObserverBridge>(self);
    _browserObserver = std::make_unique<BrowserObserverBridge>(self);
    _promoTypeForMetrics = NonModalPromoTriggerType::kUnknown;
  }
  return self;
}

- (void)logUserPastedInOmnibox {
  if (self.currentPromoReason != PromoReasonNone) {
    return;
  }

  // This assumes that the currently active webstate is the one that the paste
  // occured in.
  web::WebState* activeWebState = self.webStateList->GetActiveWebState();
  // There should always be an active web state when pasting in the omnibox.
  if (!activeWebState) {
    return;
  }

  self.currentPromoReason = PromoReasonOmniboxPaste;

  // Store the pasted web state, so when that web state's page load finishes,
  // the promo can be shown.
  self.webStateToListenTo = activeWebState;

  self.promoTypeForMetrics = NonModalPromoTriggerType::kPastedLink;
}

- (void)logUserFinishedActivityFlow {
  if (self.currentPromoReason != PromoReasonNone) {
    return;
  }
  self.currentPromoReason = PromoReasonShare;
  self.promoTypeForMetrics = NonModalPromoTriggerType::kShare;
  [self startShowPromoTimer];
}

- (void)logUserEnteredAppViaFirstPartyScheme {
  if (self.currentPromoReason != PromoReasonNone) {
    return;
  }
  // This assumes that the currently active webstate is the one that the paste
  // occured in.
  web::WebState* activeWebState = self.webStateList->GetActiveWebState();
  // There should always be an active web state when pasting in the omnibox.
  if (!activeWebState) {
    return;
  }

  self.currentPromoReason = PromoReasonExternalLink;
  self.promoTypeForMetrics = NonModalPromoTriggerType::kGrowthKitOpen;

  // Store the current web state, so when that web state's page load finishes,
  // the promo can be shown.
  self.webStateToListenTo = activeWebState;
}

- (void)logPromoWasDismissed {
  self.currentPromoReason = PromoReasonNone;
  self.promoIsShowing = NO;
  self.promoTypeForMetrics = NonModalPromoTriggerType::kUnknown;
}

- (void)logTabGridEntered {
  [self dismissPromoAnimated:YES];
}

- (void)logPopupMenuEntered {
  [self dismissPromoAnimated:YES];
}

- (void)logUserPerformedPromoAction {
  LogNonModalPromoAction(NonModalPromoAction::kAccepted,
                         self.promoTypeForMetrics,
                         UserInteractionWithNonModalPromoCount());
  LogNonModalTimeOnScreen(self.promoShownTime);
  self.promoShownTime = base::TimeTicks();
  LogUserInteractionWithNonModalPromo();

  if (NonModalPromosInstructionsEnabled()) {
    id<ApplicationSettingsCommands> handler =
        HandlerForProtocol(self.dispatcher, ApplicationSettingsCommands);
    [handler showDefaultBrowserSettingsFromViewController:nil];
  } else {
    NSURL* settingsURL =
        [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    [[UIApplication sharedApplication] openURL:settingsURL
                                       options:{}
                             completionHandler:nil];
  }
}

- (void)logUserDismissedPromo {
  LogNonModalPromoAction(NonModalPromoAction::kDismiss,
                         self.promoTypeForMetrics,
                         UserInteractionWithNonModalPromoCount());
  LogNonModalTimeOnScreen(self.promoShownTime);
  self.promoShownTime = base::TimeTicks();
  LogUserInteractionWithNonModalPromo();
}

- (void)dismissPromoAnimated:(BOOL)animated {
  [self cancelDismissPromoTimer];
  [self.handler dismissDefaultBrowserNonModalPromoAnimated:animated];
}

- (void)setBrowser:(Browser*)browser {
  if (_browser) {
    _browser->RemoveObserver(_browserObserver.get());
    self.webStateList = nullptr;
    self.overlayPresenter = nullptr;
  }

  _browser = browser;

  if (_browser) {
    _browser->AddObserver(_browserObserver.get());
    self.webStateList = _browser->GetWebStateList();
    self.overlayPresenter = OverlayPresenter::FromBrowser(
        _browser, OverlayModality::kInfobarBanner);
  }
}

- (void)setWebStateList:(WebStateList*)webStateList {
  if (_webStateList) {
    _webStateList->RemoveObserver(_webStateListObserver.get());
    _forwarder = nullptr;
  }
  _webStateList = webStateList;
  if (_webStateList) {
    _webStateList->AddObserver(_webStateListObserver.get());
    _forwarder = std::make_unique<ActiveWebStateObservationForwarder>(
        _webStateList, _webStateObserver.get());
  }
}

- (void)setOverlayPresenter:(OverlayPresenter*)overlayPresenter {
  if (_overlayPresenter) {
    _overlayPresenter->RemoveObserver(_overlayObserver.get());
  }

  _overlayPresenter = overlayPresenter;

  if (_overlayPresenter) {
    _overlayPresenter->AddObserver(_overlayObserver.get());
  }
}

- (id<DefaultBrowserPromoNonModalCommands>)handler {
  return HandlerForProtocol(self.dispatcher,
                            DefaultBrowserPromoNonModalCommands);
}

#pragma mark - WebStateListObserving

- (void)webStateList:(WebStateList*)webStateList
    didChangeActiveWebState:(web::WebState*)newWebState
                oldWebState:(web::WebState*)oldWebState
                    atIndex:(int)atIndex
                     reason:(ActiveWebStateChangeReason)reason {
  if (newWebState != self.webStateToListenTo) {
    [self cancelShowPromoTimer];
  }
}

- (void)webStateList:(WebStateList*)webStateList
    didInsertWebState:(web::WebState*)webState
              atIndex:(int)index
           activating:(BOOL)activating {
  // For the external link open, the opened link can open in a new webstate.
  // Assume that is the case if a new WebState is inserted and activated when
  // the current web state is the one that was active when the link was opened.
  if (self.currentPromoReason == PromoReasonExternalLink &&
      self.webStateList->GetActiveWebState() == self.webStateToListenTo &&
      activating) {
    self.webStateToListenTo = webState;
  }
}

#pragma mark - CRWWebStateObserver

- (void)webState:(web::WebState*)webState didLoadPageWithSuccess:(BOOL)success {
  if (success && webState == self.webStateToListenTo) {
    self.webStateToListenTo = nil;
    [self startShowPromoTimer];
  }
}

#pragma mark - OverlayPresenterObserving

- (void)overlayPresenter:(OverlayPresenter*)presenter
    willShowOverlayForRequest:(OverlayRequest*)request
          initialPresentation:(BOOL)initialPresentation {
  [self cancelShowPromoTimer];
  [self dismissPromoAnimated:YES];
}

#pragma mark - SceneStateObserver

- (void)sceneState:(SceneState*)sceneState
    transitionedToActivationLevel:(SceneActivationLevel)level {
  if (level <= SceneActivationLevelBackground) {
    if (self.promoTypeForMetrics != NonModalPromoTriggerType::kUnknown &&
        !self.promoIsShowing) {
      LogNonModalPromoAction(NonModalPromoAction::kBackgroundCancel,
                             self.promoTypeForMetrics,
                             UserInteractionWithNonModalPromoCount());
      self.promoTypeForMetrics = NonModalPromoTriggerType::kUnknown;
    }
    [self cancelShowPromoTimer];
    [self cancelDismissPromoTimer];
    [self.handler dismissDefaultBrowserNonModalPromoAnimated:NO];
  }
}

#pragma mark - BrowserObserving

- (void)browserDestroyed:(Browser*)browser {
  self.browser = nullptr;
}

#pragma mark - Timer Management

// Start the timer to show a promo. |self.currentPromoReason| must be set to
// the reason for this promo flow and must not be |PromoReasonNone|.
- (void)startShowPromoTimer {
  DCHECK(self.currentPromoReason != PromoReasonNone);

  if (!PromoCanBeDisplayed() || self.promoIsShowing || self.showPromoTimer) {
    return;
  }

  NSTimeInterval promoTimeInterval;
  switch (self.currentPromoReason) {
    case PromoReasonNone:
      NOTREACHED();
      promoTimeInterval = kShowPromoWebpageLoadWaitTime;
      break;
    case PromoReasonOmniboxPaste:
      promoTimeInterval = kShowPromoWebpageLoadWaitTime;
      break;
    case PromoReasonExternalLink:
      promoTimeInterval = kShowPromoWebpageLoadWaitTime;
      break;
    case PromoReasonShare:
      promoTimeInterval = kShowPromoPostShareWaitTime;
      break;
  }

  self.showPromoTimer =
      [NSTimer scheduledTimerWithTimeInterval:promoTimeInterval
                                       target:self
                                     selector:@selector(showPromoTimerFinished)
                                     userInfo:nil
                                      repeats:NO];
}

- (void)cancelShowPromoTimer {
  [self.showPromoTimer invalidate];
  self.showPromoTimer = nil;
  self.currentPromoReason = PromoReasonNone;
}

- (void)showPromoTimerFinished {
  if (!PromoCanBeDisplayed() || self.promoIsShowing) {
    return;
  }
  self.showPromoTimer = nil;
  [self.handler showDefaultBrowserNonModalPromo];
  self.promoIsShowing = YES;
  LogNonModalPromoAction(NonModalPromoAction::kAppear, self.promoTypeForMetrics,
                         UserInteractionWithNonModalPromoCount());
  self.promoShownTime = base::TimeTicks::Now();
  [self startDismissPromoTimer];
}

- (void)startDismissPromoTimer {
  if (self.dismissPromoTimer) {
    return;
  }
  self.dismissPromoTimer = [NSTimer
      scheduledTimerWithTimeInterval:NonModalPromosTimeout()
                              target:self
                            selector:@selector(dismissPromoTimerFinished)
                            userInfo:nil
                             repeats:NO];
}

- (void)cancelDismissPromoTimer {
  [self.dismissPromoTimer invalidate];
  self.dismissPromoTimer = nil;
}

- (void)dismissPromoTimerFinished {
  self.dismissPromoTimer = nil;
  if (self.promoIsShowing) {
    LogNonModalPromoAction(NonModalPromoAction::kTimeout,
                           self.promoTypeForMetrics,
                           UserInteractionWithNonModalPromoCount());
    LogNonModalTimeOnScreen(self.promoShownTime);
    self.promoShownTime = base::TimeTicks();
    LogUserInteractionWithNonModalPromo();
    [self.handler dismissDefaultBrowserNonModalPromoAnimated:YES];
  }
}

@end
