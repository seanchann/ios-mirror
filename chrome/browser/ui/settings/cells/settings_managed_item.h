// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_SETTINGS_CELLS_SETTINGS_MANAGED_ITEM_H_
#define IOS_CHROME_BROWSER_UI_SETTINGS_CELLS_SETTINGS_MANAGED_ITEM_H_

#import <UIKit/UIKit.h>

#import "ios/chrome/browser/ui/table_view/cells/table_view_item.h"

// SettingsManagedItem is a model class that uses SettingsManagedCell.
@interface SettingsManagedItem : TableViewItem

// The filename for the leading icon. If empty, no icon will be shown.
@property(nonatomic, copy) NSString* iconImageName;

// The main text string.
@property(nonatomic, copy) NSString* text;

// The detail text string.
@property(nonatomic, copy) NSString* detailText;

// The status text string.
@property(nonatomic, copy) NSString* statusText;

@end

#endif  // IOS_CHROME_BROWSER_UI_SETTINGS_CELLS_SETTINGS_MANAGED_ITEM_H_
