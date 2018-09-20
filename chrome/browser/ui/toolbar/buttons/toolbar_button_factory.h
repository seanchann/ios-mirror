// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_TOOLBAR_BUTTONS_TOOLBAR_BUTTON_FACTORY_H_
#define IOS_CHROME_BROWSER_UI_TOOLBAR_BUTTONS_TOOLBAR_BUTTON_FACTORY_H_

#import <UIKit/UIKit.h>

#import "ios/chrome/browser/ui/toolbar/buttons/toolbar_style.h"

@protocol ApplicationCommands;
@protocol BrowserCommands;
@protocol OmniboxFocuser;
@class ToolbarButton;
@class ToolbarButtonVisibilityConfiguration;
@class ToolbarTabGridButton;
@class ToolbarToolsMenuButton;
@class ToolbarConfiguration;

// ToolbarButton Factory protocol to create ToolbarButton objects with certain
// style and configuration, depending of the implementation.
// A dispatcher is used to send the commands associated with the buttons.
@interface ToolbarButtonFactory : NSObject

- (instancetype)initWithStyle:(ToolbarStyle)style NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

@property(nonatomic, assign, readonly) ToolbarStyle style;
// Configuration object for styling. It is used by the factory to set the style
// of the buttons title.
@property(nonatomic, strong, readonly)
    ToolbarConfiguration* toolbarConfiguration;
// Dispatcher used to initialize targets for the buttons.
@property(nonatomic, weak)
    id<ApplicationCommands, BrowserCommands, OmniboxFocuser>
        dispatcher;
// Configuration object for the visibility of the buttons.
@property(nonatomic, strong)
    ToolbarButtonVisibilityConfiguration* visibilityConfiguration;

// Back ToolbarButton.
- (ToolbarButton*)backButton;
// Forward ToolbarButton.
- (ToolbarButton*)forwardButton;
// Tab Grid ToolbarButton.
- (ToolbarTabGridButton*)tabGridButton;
// StackView ToolbarButton.
// TODO(crbug.com/800266): Remove this.
- (ToolbarButton*)stackViewButton;
// Tools Menu ToolbarButton.
- (ToolbarToolsMenuButton*)toolsMenuButton;
// Share ToolbarButton.
- (ToolbarButton*)shareButton;
// Reload ToolbarButton.
- (ToolbarButton*)reloadButton;
// Stop ToolbarButton.
- (ToolbarButton*)stopButton;
// Bookmark ToolbarButton.
- (ToolbarButton*)bookmarkButton;
// VoiceSearch ToolbarButton.
// TODO(crbug.com/800266): Remove this.
- (ToolbarButton*)voiceSearchButton;
// ContractToolbar ToolbarButton.
// TODO(crbug.com/800266): Remove this.
- (ToolbarButton*)contractButton;
// ToolbarButton to focus the omnibox.
- (ToolbarButton*)omniboxButton;
// LocationBar LeadingButton. Currently used for the incognito icon when the
// Toolbar is expanded on incognito mode. It can return nil.
- (ToolbarButton*)locationBarLeadingButton;
// Button to cancel the edit of the location bar.
- (UIButton*)cancelButton;

// Returns images for Voice Search in an array representing the NORMAL/PRESSED
// state
// TODO(crbug.com/800266): Remove this.
- (NSArray<UIImage*>*)voiceSearchImages;
// Returns images for TTS in an array representing the NORMAL/PRESSED states.
// TODO(crbug.com/800266): Remove this.
- (NSArray<UIImage*>*)TTSImages;

@end

#endif  // IOS_CHROME_BROWSER_UI_TOOLBAR_BUTTONS_TOOLBAR_BUTTON_FACTORY_H_
