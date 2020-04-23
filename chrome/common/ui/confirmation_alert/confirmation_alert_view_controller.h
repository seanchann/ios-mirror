// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_COMMON_UI_CONFIRMATION_ALERT_CONFIRMATION_ALERT_VIEW_CONTROLLER_H_
#define IOS_CHROME_COMMON_UI_CONFIRMATION_ALERT_CONFIRMATION_ALERT_VIEW_CONTROLLER_H_

#import <UIKit/UIKit.h>

// A11y Identifiers for testing.
extern NSString* const kConfirmationAlertMoreInfoAccessibilityIdentifier;
extern NSString* const kConfirmationAlertTitleAccessibilityIdentifier;
extern NSString* const kConfirmationAlertSubtitleAccessibilityIdentifier;
extern NSString* const kConfirmationAlertPrimaryActionAccessibilityIdentifier;
extern NSString* const
    kConfirmationAlertBarPrimaryActionAccessibilityIdentifier;

@protocol ConfirmationAlertActionHandler;

// A view controller useful to show modal alerts and confirmations. The main
// content consists in a big image, a title, and a subtitle which are contained
// in a scroll view for cases when the content doesn't fit in the screen.
@interface ConfirmationAlertViewController : UIViewController

// The headline below the image. Must be set before the view is loaded.
@property(nonatomic, strong) NSString* titleString;

// Text style for the title. If nil, will default to UIFontTextStyleTitle1.
@property(nonatomic, strong) NSString* titleTextStyle;

// The subtitle below the title. Must be set before the view is loaded.
@property(nonatomic, strong) NSString* subtitleString;

// Controls if there is a primary action in the view. Must be set before the
// view is loaded.
@property(nonatomic) BOOL primaryActionAvailable;

// The text for the primary action. Must be set before the view is loaded.
@property(nonatomic, strong) NSString* primaryActionString;

// The image. Must be set before the view is loaded.
@property(nonatomic, strong) UIImage* image;

// Value to determine whether or not the image's size should be scaled.
@property(nonatomic) BOOL imageHasFixedSize;

// Controls if, when we run out of view space, we should hide the action button
// instead of the image.
@property(nonatomic) BOOL alwaysShowImage;

// The style of the primary action button added to the toolbar. Must be set if
// both alwaysShowImage and primaryActionAvailable are set to YES.
@property(nonatomic) UIBarButtonSystemItem primaryActionBarButtonStyle;

// Controls if there is a help button in the view. Must be set before the
// view is loaded.
@property(nonatomic) BOOL helpButtonAvailable;

// The help button item in the top left of the view. Nil if not available.
@property(nonatomic, readonly) UIBarButtonItem* helpButton;

// The action handler for interactions in this View Controller.
@property(nonatomic, weak) id<ConfirmationAlertActionHandler> actionHandler;

@end

#endif  // IOS_CHROME_COMMON_UI_CONFIRMATION_ALERT_CONFIRMATION_ALERT_VIEW_CONTROLLER_H_
