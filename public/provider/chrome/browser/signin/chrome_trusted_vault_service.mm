// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/public/provider/chrome/browser/signin/chrome_trusted_vault_service.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace ios {

ChromeTrustedVaultService::ChromeTrustedVaultService() {}

ChromeTrustedVaultService::~ChromeTrustedVaultService() {}

void ChromeTrustedVaultService::AddObserver(Observer* observer) {
  observer_list_.AddObserver(observer);
}

void ChromeTrustedVaultService::RemoveObserver(Observer* observer) {
  observer_list_.RemoveObserver(observer);
}

void ChromeTrustedVaultService::GetDegradedRecoverabilityStatus(
    ChromeIdentity* chrome_identity,
    base::OnceCallback<void(bool)> callback) {
  std::move(callback).Run(false);
}

void ChromeTrustedVaultService::Reauthentication(
    ChromeIdentity* chrome_identity,
    UIViewController* presentingViewController,
    void (^callback)(BOOL success, NSError* error)) {}

void ChromeTrustedVaultService::ReauthenticationForFetchKeys(
    ChromeIdentity* chrome_identity,
    UIViewController* presentingViewController,
    void (^callback)(BOOL success, NSError* error)) {
  Reauthentication(chrome_identity, presentingViewController, callback);
}

void ChromeTrustedVaultService::FixDegradedRecoverability(
    ChromeIdentity* chrome_identity,
    UIViewController* presentingViewController,
    void (^callback)(BOOL success, NSError* error)) {
  Reauthentication(chrome_identity, presentingViewController, callback);
}

void ChromeTrustedVaultService::ReauthenticationForOptIn(
    ChromeIdentity* chrome_identity,
    UIViewController* presentingViewController,
    void (^callback)(BOOL success, NSError* error)) {}

void ChromeTrustedVaultService::NotifyKeysChanged() {
  for (Observer& observer : observer_list_) {
    observer.OnTrustedVaultKeysChanged();
  }
}

void ChromeTrustedVaultService::NotifyRecoverabilityChanged() {
  for (Observer& observer : observer_list_) {
    observer.OnTrustedVaultRecoverabilityChanged();
  }
}

void ChromeTrustedVaultService::CancelDialog(BOOL animated,
                                             void (^callback)(void)) {}

void ChromeTrustedVaultService::CancelReauthentication(BOOL animated,
                                                       void (^callback)(void)) {
  CancelDialog(animated, callback);
}

}  // namespace ios
