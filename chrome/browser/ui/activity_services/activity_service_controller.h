// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_ACTIVITY_SERVICES_ACTIVITY_SERVICE_CONTROLLER_H_
#define IOS_CHROME_BROWSER_UI_ACTIVITY_SERVICES_ACTIVITY_SERVICE_CONTROLLER_H_

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@protocol ActivityServicePassword;
@protocol ActivityServicePositioner;
@protocol ActivityServicePresentation;
@protocol BrowserCommands;
class ChromeBrowserState;
@class ShareToData;
@protocol SnackbarCommands;

namespace ShareTo {

// Provides the result of a sharing event.
enum ShareResult {
  // The share was successful.
  SHARE_SUCCESS,
  // The share was cancelled by either the user or by the service.
  SHARE_CANCEL,
  // The share was attempted, but failed due to a network-related error.
  SHARE_NETWORK_FAILURE,
  // The share was attempted, but failed because of user authentication error.
  SHARE_SIGN_IN_FAILURE,
  // The share was attempted, but failed with an unspecified error.
  SHARE_ERROR,
  // The share was attempted, and the result is unknown.
  SHARE_UNKNOWN_RESULT,
};

}  // namespace ShareTo

// Snackbar ID for any services that wish to show snackbars.
extern NSString* const kActivityServicesSnackbarCategory;

// Controller to show the built-in services (e.g. Copy, Printing) and services
// offered by iOS App Extensions (Share, Action).
@interface ActivityServiceController : NSObject

// Return the singleton ActivityServiceController.
+ (instancetype)sharedInstance;

// Returns YES if a share is currently in progress.
- (BOOL)isActive;

// Cancels share operation.
- (void)cancelShareAnimated:(BOOL)animated;

// Shares the given data. The given providers must not be nil.  On iPad, the
// |positionProvider| must return a non-nil view and a non-zero size.
- (void)shareWithData:(ShareToData*)data
            browserState:(ChromeBrowserState*)browserState
              dispatcher:(id<BrowserCommands, SnackbarCommands>)dispatcher
        passwordProvider:(id<ActivityServicePassword>)passwordProvider
        positionProvider:(id<ActivityServicePositioner>)positionProvider
    presentationProvider:(id<ActivityServicePresentation>)presentationProvider;

@end

#endif  // IOS_CHROME_BROWSER_UI_ACTIVITY_SERVICES_ACTIVITY_SERVICE_CONTROLLER_H_
