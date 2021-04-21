// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/authentication/signin/consistency_promo_signin/consistency_promo_signin_coordinator.h"

#import "base/mac/foundation_util.h"
#import "components/signin/public/base/account_consistency_method.h"
#import "components/signin/public/identity_manager/objc/identity_manager_observer_bridge.h"
#import "ios/chrome/browser/browser_state/chrome_browser_state.h"
#import "ios/chrome/browser/main/browser.h"
#import "ios/chrome/browser/signin/authentication_service.h"
#import "ios/chrome/browser/signin/authentication_service_factory.h"
#import "ios/chrome/browser/signin/constants.h"
#import "ios/chrome/browser/signin/identity_manager_factory.h"
#import "ios/chrome/browser/ui/authentication/signin/consistency_promo_signin/bottom_sheet/bottom_sheet_navigation_controller.h"
#import "ios/chrome/browser/ui/authentication/signin/consistency_promo_signin/bottom_sheet/bottom_sheet_presentation_controller.h"
#import "ios/chrome/browser/ui/authentication/signin/consistency_promo_signin/bottom_sheet/bottom_sheet_slide_transition_animator.h"
#import "ios/chrome/browser/ui/authentication/signin/consistency_promo_signin/consistency_default_account/consistency_default_account_coordinator.h"
#import "ios/chrome/browser/ui/authentication/signin/signin_coordinator+protected.h"
#import "ios/chrome/common/ui/colors/semantic_color_names.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface ConsistencyPromoSigninCoordinator () <
    BottomSheetPresentationControllerPresentationDelegate,
    ConsistencyDefaultAccountCoordinatorDelegate,
    IdentityManagerObserverBridgeDelegate,
    UINavigationControllerDelegate,
    UIViewControllerTransitioningDelegate>

// Navigation controller presented from the bottom.
@property(nonatomic, strong)
    BottomSheetNavigationController* navigationController;
// Interaction transition to swipe from left to right to pop a view controller
// from |self.navigationController|.
@property(nonatomic, strong)
    UIPercentDrivenInteractiveTransition* interactionTransition;
// Coordinator for the first screen.
@property(nonatomic, strong)
    ConsistencyDefaultAccountCoordinator* defaultAccountCoordinator;
// Chrome interface to the iOS shared authentication library.
@property(nonatomic, assign) AuthenticationService* authenticationService;
// Manager for user's Google identities.
@property(nonatomic, assign) signin::IdentityManager* identityManager;
@end

@implementation ConsistencyPromoSigninCoordinator {
  // Observer for changes to the user's Google identities.
  std::unique_ptr<signin::IdentityManagerObserverBridge>
      _identityManagerObserverBridge;
  // Callback used when the user's primary account is set or changes
  // its consent level.
  signin_ui::CompletionCallback _onPrimaryAccountSetCompletion;
}

#pragma mark - SigninCoordinator

- (void)interruptWithAction:(SigninCoordinatorInterruptAction)action
                 completion:(ProceduralBlock)completion {
  __weak __typeof(self) weakSelf = self;
  _onPrimaryAccountSetCompletion = nil;
  [self.navigationController
      dismissViewControllerAnimated:YES
                         completion:^() {
                           [weakSelf finishedWithResult:
                                         SigninCoordinatorResultInterrupted
                                               identity:nil];
                         }];
}

- (void)start {
  [super start];
  self.defaultAccountCoordinator = [[ConsistencyDefaultAccountCoordinator alloc]
      initWithBaseViewController:nil
                         browser:self.browser];
  self.defaultAccountCoordinator.delegate = self;
  [self.defaultAccountCoordinator start];

  self.authenticationService = AuthenticationServiceFactory::GetForBrowserState(
      self.browser->GetBrowserState());
  self.identityManager = IdentityManagerFactory::GetForBrowserState(
      self.browser->GetBrowserState());
  _identityManagerObserverBridge.reset(
      new signin::IdentityManagerObserverBridge(self.identityManager, self));

  self.navigationController = [[BottomSheetNavigationController alloc]
      initWithRootViewController:self.defaultAccountCoordinator.viewController];
  self.navigationController.delegate = self;
  UIScreenEdgePanGestureRecognizer* edgeSwipeGesture =
      [[UIScreenEdgePanGestureRecognizer alloc]
          initWithTarget:self
                  action:@selector(swipeAction:)];
  edgeSwipeGesture.edges = UIRectEdgeLeft;
  [self.navigationController.view addGestureRecognizer:edgeSwipeGesture];
  self.navigationController.modalPresentationStyle = UIModalPresentationCustom;
  self.navigationController.transitioningDelegate = self;
  [self.baseViewController presentViewController:self.navigationController
                                        animated:YES
                                      completion:nil];
}

- (void)stop {
  [super stop];
  DCHECK(!_onPrimaryAccountSetCompletion);
}

#pragma mark - Private

// Creates the first view controller.
- (UIViewController*)firstViewController {
  // Needs implementation.
  NOTIMPLEMENTED();
  return nil;
}

// Dismisses the bottom sheet view controller.
- (void)dismissNavigationViewController {
  __weak __typeof(self) weakSelf = self;
  [self.navigationController
      dismissViewControllerAnimated:YES
                         completion:^() {
                           [weakSelf finishedWithResult:
                                         SigninCoordinatorResultCanceledByUser
                                               identity:nil];
                         }];
}

// Calls the sign-in completion block.
- (void)finishedWithResult:(SigninCoordinatorResult)signinResult
                  identity:(ChromeIdentity*)identity {
  SigninCompletionInfo* completionInfo =
      [SigninCompletionInfo signinCompletionInfoWithIdentity:identity];
  [self runCompletionCallbackWithSigninResult:signinResult
                               completionInfo:completionInfo];
}

#pragma mark - SwipeGesture

// Called when the swipe gesture is active. This method controls the sliding
// between two view controls in |self.navigationController|.
- (void)swipeAction:(UIScreenEdgePanGestureRecognizer*)gestureRecognizer {
  if (!gestureRecognizer.view) {
    self.interactionTransition = nil;
    return;
  }
  UIView* view = gestureRecognizer.view;
  CGFloat percentage =
      [gestureRecognizer translationInView:view].x / view.bounds.size.width;
  switch (gestureRecognizer.state) {
    case UIGestureRecognizerStateBegan:
      self.interactionTransition =
          [[UIPercentDrivenInteractiveTransition alloc] init];
      [self.navigationController popViewControllerAnimated:YES];
      [self.interactionTransition updateInteractiveTransition:percentage];
      break;
    case UIGestureRecognizerStateChanged:
      [self.interactionTransition updateInteractiveTransition:percentage];
      break;
    case UIGestureRecognizerStateEnded:
      if (percentage > .5 &&
          gestureRecognizer.state != UIGestureRecognizerStateCancelled) {
        [self.interactionTransition finishInteractiveTransition];
      } else {
        [self.interactionTransition cancelInteractiveTransition];
      }
      self.interactionTransition = nil;
      break;
    case UIGestureRecognizerStatePossible:
    case UIGestureRecognizerStateCancelled:
    case UIGestureRecognizerStateFailed:
      break;
  }
}

#pragma mark - BottomSheetPresentationControllerPresentationDelegate

- (void)bottomSheetPresentationControllerDismissViewController:
    (BottomSheetPresentationController*)controller {
  [self dismissNavigationViewController];
}

#pragma mark - ConsistencyDefaultAccountCoordinatorDelegate

- (void)consistencyDefaultAccountCoordinatorSkip:
    (ConsistencyDefaultAccountCoordinator*)coordinator {
  [self dismissNavigationViewController];
}

- (void)consistencyDefaultAccountCoordinatorOpenIdentityChooser:
    (ConsistencyDefaultAccountCoordinator*)coordinator {
  NOTREACHED();
}

- (void)consistencyDefaultAccountCoordinator:
            (ConsistencyDefaultAccountCoordinator*)coordinator
                            selectedIdentity:(ChromeIdentity*)identity {
  __weak __typeof(self) weakSelf = self;
  // |onPrimaryAccountChanged| notification is sent immediately after calling
  // SignIn. All callbacks should be set prior to this operation.
  _onPrimaryAccountSetCompletion = ^(BOOL success) {
    [weakSelf.navigationController
        dismissViewControllerAnimated:YES
                           completion:^() {
                             [weakSelf finishedWithResult:
                                           SigninCoordinatorResultSuccess
                                                 identity:identity];
                           }];
  };
  self.authenticationService->SignIn(identity);
}

#pragma mark - IdentityManagerObserverBridgeDelegate

- (void)onPrimaryAccountChanged:
    (const signin::PrimaryAccountChangeEvent&)event {
  if (_onPrimaryAccountSetCompletion == nil) {
    return;
  }
  // Since sign-in UI blocks all other Chrome screens until it is dismissed
  // an account change event must come from the bottomsheet.
  // TODO(crbug.com/1081764): Update if sign-in UI becomes non-blocking.
  DCHECK(event.GetEventTypeFor(signin::ConsentLevel::kSignin) ==
         signin::PrimaryAccountChangeEvent::Type::kSet);
  _onPrimaryAccountSetCompletion(/*success=*/YES);
  _onPrimaryAccountSetCompletion = nil;
}

#pragma mark - UINavigationControllerDelegate

- (id<UIViewControllerAnimatedTransitioning>)
               navigationController:
                   (UINavigationController*)navigationController
    animationControllerForOperation:(UINavigationControllerOperation)operation
                 fromViewController:(UIViewController*)fromVC
                   toViewController:(UIViewController*)toVC {
  DCHECK_EQ(navigationController, self.navigationController);
  switch (operation) {
    case UINavigationControllerOperationNone:
      return nil;
    case UINavigationControllerOperationPush:
      return [[BottomSheetSlideTransitionAnimator alloc]
             initWithAnimation:BottomSheetSlideAnimationPushing
          navigationController:self.navigationController];
    case UINavigationControllerOperationPop:
      return [[BottomSheetSlideTransitionAnimator alloc]
             initWithAnimation:BottomSheetSlideAnimationPopping
          navigationController:self.navigationController];
  }
  NOTREACHED();
  return nil;
}

- (id<UIViewControllerInteractiveTransitioning>)
                           navigationController:
                               (UINavigationController*)navigationController
    interactionControllerForAnimationController:
        (id<UIViewControllerAnimatedTransitioning>)animationController {
  return self.interactionTransition;
}

#pragma mark - UIViewControllerTransitioningDelegate

- (UIPresentationController*)
    presentationControllerForPresentedViewController:
        (UIViewController*)presentedViewController
                            presentingViewController:
                                (UIViewController*)presentingViewController
                                sourceViewController:(UIViewController*)source {
  DCHECK_EQ(self.navigationController, presentedViewController);
  BottomSheetPresentationController* controller =
      [[BottomSheetPresentationController alloc]
          initWithBottomSheetNavigationController:self.navigationController
                         presentingViewController:presentingViewController];
  controller.presentationDelegate = self;
  return controller;
}

@end
