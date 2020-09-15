// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/table_view/cells/table_view_info_button_item.h"

#import "ios/chrome/browser/ui/table_view/cells/table_view_info_button_cell.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@implementation TableViewInfoButtonItem

- (instancetype)initWithType:(NSInteger)type {
  self = [super initWithType:type];
  if (self) {
    self.cellClass = [TableViewInfoButtonCell class];
  }
  return self;
}

#pragma mark TableViewItem

- (void)configureCell:(TableViewInfoButtonCell*)cell
           withStyler:(ChromeTableViewStyler*)styler {
  [super configureCell:cell withStyler:styler];
  cell.textLabel.text = self.text;
  if (self.detailText) {
    cell.detailTextLabel.text = self.detailText;
    [cell updatePaddingForDetailText:YES];
  } else {
    [cell updatePaddingForDetailText:NO];
  }
  cell.statusTextLabel.text = self.statusText;
  if (self.accessibilityHint) {
    cell.accessibilityHint = self.accessibilityHint;
  }
  cell.selectionStyle = UITableViewCellSelectionStyleNone;

  // Update the icon image, if one is present.
  UIImage* iconImage = nil;
  if ([self.iconImageName length]) {
    iconImage = [UIImage imageNamed:self.iconImageName];
  }
  [cell setIconImage:iconImage withTintColor:self.tintColor];
}

@end
