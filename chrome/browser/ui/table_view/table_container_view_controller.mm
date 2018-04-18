// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/table_view/table_container_view_controller.h"

#import "ios/chrome/browser/ui/table_view/chrome_table_view_controller.h"
#import "ios/chrome/browser/ui/table_view/chrome_table_view_styler.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@implementation TableContainerViewController
@synthesize tableViewController = _tableViewController;

#pragma mark - Public Interface

- (instancetype)initWithTable:(ChromeTableViewController*)table {
  self = [super initWithRootViewController:table];
  if (self) {
    _tableViewController = table;
  }
  return self;
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
  [self.navigationBar setBackgroundImage:[UIImage new]
                           forBarMetrics:UIBarMetricsDefault];

  if (self.tableViewController.styler.tableViewBackgroundColor !=
      [UIColor clearColor]) {
    self.navigationBar.translucent = NO;
  }

  if (@available(iOS 11, *)) {
    self.navigationBar.prefersLargeTitles = YES;
  }
}

@end
