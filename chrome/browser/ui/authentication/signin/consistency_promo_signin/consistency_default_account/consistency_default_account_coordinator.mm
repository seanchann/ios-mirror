// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/authentication/signin/consistency_promo_signin/consistency_default_account/consistency_default_account_coordinator.h"

#import "ios/chrome/browser/ui/authentication/signin/consistency_promo_signin/consistency_default_account/consistency_default_account_mediator.h"
#import "ios/chrome/browser/ui/authentication/signin/consistency_promo_signin/consistency_default_account/consistency_default_account_view_controller.h"
#import "ios/public/provider/chrome/browser/chrome_browser_provider.h"
#import "ios/public/provider/chrome/browser/signin/chrome_identity.h"
#import "ios/public/provider/chrome/browser/signin/chrome_identity_service.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface ConsistencyDefaultAccountCoordinator () <
    ConsistencyDefaultAccountActionDelegate,
    ConsistencyDefaultAccountMediatorDelegate>

@property(nonatomic, strong)
    ConsistencyDefaultAccountViewController* defaultAccountViewController;

@property(nonatomic, strong) ConsistencyDefaultAccountMediator* mediator;

@end

@implementation ConsistencyDefaultAccountCoordinator

- (void)start {
  self.mediator = [[ConsistencyDefaultAccountMediator alloc] init];
  self.mediator.delegate = self;
  self.defaultAccountViewController =
      [[ConsistencyDefaultAccountViewController alloc] init];
  self.mediator.consumer = self.defaultAccountViewController;
  self.defaultAccountViewController.actionDelegate = self;
  [self.defaultAccountViewController view];
}

#pragma mark - Properties

- (UIViewController*)viewController {
  return self.defaultAccountViewController;
}

- (ChromeIdentity*)selectedIdentity {
  return self.mediator.selectedIdentity;
}

- (void)setSelectedIdentity:(ChromeIdentity*)identity {
  DCHECK(self.mediator);
  self.mediator.selectedIdentity = identity;
}

#pragma mark - ConsistencyDefaultAccountMediatorDelegate

- (void)consistencyDefaultAccountMediatorNoIdentities:
    (ConsistencyDefaultAccountMediator*)mediator {
  [self.delegate consistencyDefaultAccountCoordinatorSkip:self];
}

#pragma mark - ConsistencyDefaultAccountActionDelegate

- (void)consistencyDefaultAccountViewControllerSkip:
    (ConsistencyDefaultAccountViewController*)viewController {
  [self.delegate consistencyDefaultAccountCoordinatorSkip:self];
}

- (void)consistencyDefaultAccountViewControllerOpenIdentityChooser:
    (ConsistencyDefaultAccountViewController*)viewController {
  [self.delegate consistencyDefaultAccountCoordinatorOpenIdentityChooser:self];
}

- (void)consistencyDefaultAccountViewControllerContinueWithSelectedIdentity:
    (ConsistencyDefaultAccountViewController*)viewController {
  [self.delegate consistencyDefaultAccountCoordinatorSignin:self];
}

@end