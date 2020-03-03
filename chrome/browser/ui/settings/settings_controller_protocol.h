// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_SETTINGS_SETTINGS_CONTROLLER_PROTOCOL_H_
#define IOS_CHROME_BROWSER_UI_SETTINGS_SETTINGS_CONTROLLER_PROTOCOL_H_

#import <UIKit/UIKit.h>

// Protocol for settings view controllers.
@protocol SettingsControllerProtocol <NSObject>

@optional

// Notifies the controller that the settings screen is being dismissed.
- (void)settingsWillBeDismissed;

// Notifies the controller that is popped out from the settings navigation
// controller.
- (void)viewControllerWasPopped;

@end

#endif  // IOS_CHROME_BROWSER_UI_SETTINGS_SETTINGS_CONTROLLER_PROTOCOL_H_
