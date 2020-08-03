// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_MENU_ACTION_FACTORY_H_
#define IOS_CHROME_BROWSER_UI_MENU_ACTION_FACTORY_H_

#import <UIKit/UIKit.h>

#import "base/ios/block_types.h"
#import "ios/chrome/browser/ui/menu/menu_action_type.h"
#import "ios/chrome/browser/ui/menu/menu_histograms.h"
#import "ios/chrome/browser/window_activities/window_activity_helpers.h"

class Browser;
class GURL;

// Factory providing methods to create UIActions with consistent titles, images
// and metrics structure.
API_AVAILABLE(ios(13.0))
@interface ActionFactory : NSObject

// Initializes a factory instance for the current |browser| to create action
// instances for the given |scenario|.
- (instancetype)initWithBrowser:(Browser*)browser
                       scenario:(MenuScenario)scenario;

// Creates a UIAction instance configured with the given |title| and |image|.
// Upon execution, the action's |type| will be recorded and the |block| will be
// run.
- (UIAction*)actionWithTitle:(NSString*)title
                       image:(UIImage*)image
                        type:(MenuActionType)type
                       block:(ProceduralBlock)block;

// Creates a UIAction instance configured to copy the given |URL| to the
// pasteboard.
- (UIAction*)actionToCopyURL:(const GURL)URL;

// Creates a UIAction instance configured for deletion which will invoke
// the given delete |block| when executed.
- (UIAction*)actionToDeleteWithBlock:(ProceduralBlock)block;

// Creates a UIAction instance configured for opening the |URL| in a new tab and
// which will invoke the given |completion| block after execution.
- (UIAction*)actionToOpenInNewTabWithURL:(const GURL)URL
                              completion:(ProceduralBlock)completion;

// Creates a UIAction instance whose title and icon are configured for opening a
// URL in a new tab. When triggered, the action will invoke the |block| which
// needs to open a URL in a new tab.
- (UIAction*)actionToOpenInNewTabWithBlock:(ProceduralBlock)block;

// Creates a UIAction instance configured for opening the |URL| in a new
// incognito tab and which will invoke the given |completion| block after
// execution.
- (UIAction*)actionToOpenInNewIncognitoTabWithURL:(const GURL)URL
                                       completion:(ProceduralBlock)completion;

// Creates a UIAction instance whose title and icon are configured for opening a
// URL in a new incognito tab. When triggered, the action will invoke the
// |block| which needs to open a URL in a new incognito tab.
- (UIAction*)actionToOpenInNewIncognitoTabWithBlock:(ProceduralBlock)block;

// Creates a UIAction instance configured for opening the |URL| in a new window
// from |activityOrigin|, and which will invoke the given |completion| block
// after execution.
- (UIAction*)actionToOpenInNewWindowWithURL:(const GURL)URL
                             activityOrigin:(WindowActivityOrigin)activityOrigin
                                 completion:(ProceduralBlock)completion;

@end

#endif  // IOS_CHROME_BROWSER_UI_MENU_ACTION_FACTORY_H_
