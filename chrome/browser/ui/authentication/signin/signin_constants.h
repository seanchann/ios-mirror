// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_AUTHENTICATION_SIGNIN_SIGNIN_CONSTANTS_H_
#define IOS_CHROME_BROWSER_UI_AUTHENTICATION_SIGNIN_SIGNIN_CONSTANTS_H_

#import <Foundation/Foundation.h>

#import "url/gurl.h"

@class ChromeIdentity;

// Sign-in result returned Sign-in result.
typedef NS_ENUM(NSUInteger, SigninCoordinatorResult) {
  // Sign-in has been canceled by the user or by another reason.
  SigninCoordinatorResultCanceledByUser,
  // Sign-in has been done, but the user didn’t accept nor refuse to sync.
  SigninCoordinatorResultInterrupted,
  // Sign-in has been done, the user has been explicitly accepted or refused
  // sync.
  SigninCoordinatorResultSuccess,
};

// Action to do when the sign-in dialog needs to be interrupted.
typedef NS_ENUM(NSUInteger, SigninCoordinatorInterruptAction) {
  // Stops the sign-in coordinator without dismissing the view.
  SigninCoordinatorInterruptActionNoDismiss,
  // Stops the sign-in coordinator and dismisses the view without animation.
  SigninCoordinatorInterruptActionDismissWithoutAnimation,
  // Stops the sign-in coordinator and dismisses the view with animation.
  SigninCoordinatorInterruptActionDismissWithAnimation,
};

// Name of notification sent when the user has attempted a sign-in.
extern NSString* const kUserSigninAttemptedNotification;
// Name of accessibility identifier for the skip sign-in button.
extern NSString* const kSkipSigninAccessibilityIdentifier;
// Name of accessibility identifier for the add account button in the sign-in
// flow.
extern NSString* const kAddAccountAccessibilityIdentifier;
// Name of accessibility identifier for the confirmation "Yes I'm In" sign-in
// button.
extern NSString* const kConfirmationAccessibilityIdentifier;
// Name of accessibility identifier for the more button in the sign-in flow.
extern NSString* const kMoreAccessibilityIdentifier;
// Name of accessibility identifier for the web sign-in consistency sheet.
extern NSString* const kWebSigninAccessibilityIdentifier;
// Name of accessiblity identifier for "Continue As..." button that signs in
// the primary account user for the web sign-in consistency sheet.
extern NSString* const kWebSigninContinueAsButtonAccessibilityIdentifier;

// Action that is required to do to complete the sign-in. This action is in
// charge of the SigninCoordinator's owner.
typedef NS_ENUM(NSUInteger, SigninCompletionAction) {
  // No action needed.
  SigninCompletionActionNone,
  // The advanced settings sign-in view is needed to finish the sign-in.
  // This case is only used for the first run sign-in.
  SigninCompletionActionShowAdvancedSettingsSignin,
  // The completion URL needs to be opened.
  SigninCompletionActionOpenCompletionURL,
};

#endif  // IOS_CHROME_BROWSER_UI_AUTHENTICATION_SIGNIN_SIGNIN_CONSTANTS_H_
