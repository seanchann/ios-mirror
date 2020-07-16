// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/settings/password/passwords_mediator.h"

#include "components/password_manager/core/browser/leak_detection_dialog_utils.h"
#include "components/password_manager/core/browser/password_store.h"
#include "components/password_manager/core/common/password_manager_features.h"
#include "ios/chrome/browser/passwords/password_check_observer_bridge.h"
#include "ios/chrome/browser/passwords/password_store_observer_bridge.h"
#import "ios/chrome/browser/passwords/save_passwords_consumer.h"
#import "ios/chrome/browser/signin/authentication_service.h"
#include "ios/chrome/browser/sync/sync_setup_service.h"
#import "ios/chrome/browser/ui/settings/password/passwords_consumer.h"
#import "ios/chrome/browser/ui/table_view/cells/table_view_cells_constants.h"
#include "ios/chrome/browser/ui/ui_feature_flags.h"
#import "ios/chrome/browser/ui/util/uikit_ui_util.h"
#import "ios/chrome/common/string_util.h"
#import "ios/chrome/common/ui/colors/semantic_color_names.h"
#include "ios/chrome/grit/ios_chromium_strings.h"
#import "net/base/mac/url_conversions.h"
#include "ui/base/l10n/l10n_util_mac.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface PasswordsMediator () <PasswordCheckObserver,
                                 PasswordStoreObserver,
                                 SavePasswordsConsumerDelegate> {
  // The service responsible for password check feature.
  scoped_refptr<IOSChromePasswordCheckManager> _passwordCheckManager;

  // The interface for getting and manipulating a user's saved passwords.
  scoped_refptr<password_manager::PasswordStore> _passwordStore;

  // Service used to check if user is signed in.
  AuthenticationService* _authService;

  // Service to check if passwords are synced.
  SyncSetupService* _syncService;

  // A helper object for passing data about changes in password check status
  // and changes to compromised credentials list.
  std::unique_ptr<PasswordCheckObserverBridge> _passwordCheckObserver;

  // A helper object for passing data about saved passwords from a finished
  // password store request to the PasswordsTableViewController.
  std::unique_ptr<ios::SavePasswordsConsumer> _savedPasswordsConsumer;

  // A helper object which listens to the password store changes.
  std::unique_ptr<PasswordStoreObserverBridge> _passwordStoreObserver;

  // Current state of password check.
  PasswordCheckState _currentState;
}

@end

@implementation PasswordsMediator

- (instancetype)
    initWithPasswordStore:
        (scoped_refptr<password_manager::PasswordStore>)passwordStore
     passwordCheckManager:
         (scoped_refptr<IOSChromePasswordCheckManager>)passwordCheckManager
              authService:(AuthenticationService*)authService
              syncService:(SyncSetupService*)syncService {
  self = [super init];
  if (self) {
    _passwordStore = passwordStore;
    _authService = authService;
    _syncService = syncService;
    _savedPasswordsConsumer =
        std::make_unique<ios::SavePasswordsConsumer>(self);

    if (base::FeatureList::IsEnabled(
            password_manager::features::kPasswordCheck)) {
      _passwordCheckManager = passwordCheckManager;
      _passwordCheckObserver = std::make_unique<PasswordCheckObserverBridge>(
          self, _passwordCheckManager.get());
      _passwordStoreObserver =
          std::make_unique<PasswordStoreObserverBridge>(self);
      _passwordStore->AddObserver(_passwordStoreObserver.get());
    }
  }
  return self;
}

- (void)dealloc {
  if (_passwordStoreObserver) {
    _passwordStore->RemoveObserver(_passwordStoreObserver.get());
  }
}

- (void)setConsumer:(id<PasswordsConsumer>)consumer {
  if (_consumer == consumer)
    return;
  _consumer = consumer;
  [self loginsDidChange];

  if (base::FeatureList::IsEnabled(
          password_manager::features::kPasswordCheck)) {
    _currentState = _passwordCheckManager->GetPasswordCheckState();
    [self.consumer setPasswordCheckUIState:
                       [self computePasswordCheckUIStateWith:_currentState]];
  }
}

- (NSAttributedString*)passwordCheckErrorInfo {
  if (!_passwordCheckManager->GetCompromisedCredentials().empty())
    return nil;

  NSString* message;
  GURL linkURL;

  switch (_currentState) {
    case PasswordCheckState::kRunning:
    case PasswordCheckState::kNoPasswords:
    case PasswordCheckState::kCanceled:
    case PasswordCheckState::kIdle:
      return nil;
    case PasswordCheckState::kSignedOut:
      message = l10n_util::GetNSString(IDS_IOS_PASSWORD_CHECK_ERROR_SIGNED_OUT);
      break;
    case PasswordCheckState::kOffline:
      message = l10n_util::GetNSString(IDS_IOS_PASSWORD_CHECK_ERROR_OFFLINE);
      break;
    case PasswordCheckState::kQuotaLimit:
      if ([self canUseAccountPasswordCheckup]) {
        message = l10n_util::GetNSString(
            IDS_IOS_PASSWORD_CHECK_ERROR_QUOTA_LIMIT_VISIT_GOOGLE);
        linkURL = password_manager::GetPasswordCheckupURL(
            password_manager::PasswordCheckupReferrer::kPasswordCheck);
      } else {
        message =
            l10n_util::GetNSString(IDS_IOS_PASSWORD_CHECK_ERROR_QUOTA_LIMIT);
      }
      break;
    case PasswordCheckState::kOther:
      message = l10n_util::GetNSString(IDS_IOS_PASSWORD_CHECK_ERROR_OTHER);
      break;
  }
  return [self configureTextWithLink:message link:linkURL];
}

#pragma mark - PasswordCheckObserver

- (void)passwordCheckStateDidChange:(PasswordCheckState)state {
  if (state == _currentState)
    return;

  DCHECK(self.consumer);
  [self.consumer
      setPasswordCheckUIState:[self computePasswordCheckUIStateWith:state]];
}

- (void)compromisedCredentialsDidChange:
    (password_manager::CompromisedCredentialsManager::CredentialsView)
        credentials {
  DCHECK(self.consumer);
  [self.consumer setPasswordCheckUIState:
                     [self computePasswordCheckUIStateWith:_currentState]];
}

#pragma mark - Private Methods

// Returns PasswordCheckUIState based on PasswordCheckState.
- (PasswordCheckUIState)computePasswordCheckUIStateWith:
    (PasswordCheckState)newState {
  BOOL wasRunning = _currentState == PasswordCheckState::kRunning;
  _currentState = newState;

  switch (_currentState) {
    case PasswordCheckState::kRunning:
      return PasswordCheckStateRunning;
    case PasswordCheckState::kNoPasswords:
      return PasswordCheckStateDisabled;
    case PasswordCheckState::kSignedOut:
    case PasswordCheckState::kOffline:
    case PasswordCheckState::kQuotaLimit:
    case PasswordCheckState::kOther:
      return _passwordCheckManager->GetCompromisedCredentials().empty()
                 ? PasswordCheckStateError
                 : PasswordCheckStateUnSafe;
    case PasswordCheckState::kCanceled:
    case PasswordCheckState::kIdle: {
      if (!_passwordCheckManager->GetCompromisedCredentials().empty()) {
        return PasswordCheckStateUnSafe;
      } else if (_currentState == PasswordCheckState::kIdle) {
        // Safe state is only possible after the state transitioned from
        // kRunning to kIdle.
        return wasRunning ? PasswordCheckStateSafe : PasswordCheckStateDefault;
      }
      return PasswordCheckStateDefault;
    }
  }
}

// Compute whether user is capable to run password check in Google Account.
- (BOOL)canUseAccountPasswordCheckup {
  return (_authService->IsAuthenticated() &&
          _authService->GetAuthenticatedIdentity()) &&
         (_syncService->IsSyncEnabled() &&
          !_syncService->IsEncryptEverythingEnabled());
}

// Configures text for Error Info Popover.
- (NSAttributedString*)configureTextWithLink:(NSString*)text link:(GURL)link {
  NSRange range;

  NSString* strippedText = ParseStringWithLink(text, &range);

  NSRange fullRange = NSMakeRange(0, strippedText.length);
  NSMutableAttributedString* attributedText =
      [[NSMutableAttributedString alloc] initWithString:strippedText];
  [attributedText addAttribute:NSForegroundColorAttributeName
                         value:[UIColor colorNamed:kTextSecondaryColor]
                         range:fullRange];

  [attributedText
      addAttribute:NSFontAttributeName
             value:[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline]
             range:fullRange];

  if (range.location != NSNotFound && range.length != 0) {
    NSURL* URL = net::NSURLWithGURL(link);
    id linkValue = URL ? URL : @"";
    [attributedText addAttribute:NSLinkAttributeName
                           value:linkValue
                           range:range];
  }

  return attributedText;
}

#pragma mark - PasswordStoreObserver

- (void)loginsDidChange {
  // Cancel ongoing requests to the password store and issue a new request.
  _savedPasswordsConsumer->cancelable_task_tracker()->TryCancelAll();
  _passwordStore->GetAllLogins(_savedPasswordsConsumer.get());
}

#pragma mark - SavePasswordsConsumerDelegate

- (void)onGetPasswordStoreResults:
    (std::vector<std::unique_ptr<autofill::PasswordForm>>)results {
  DCHECK(self.consumer);
  [self.consumer setPasswordsForms:std::move(results)];
}

@end
