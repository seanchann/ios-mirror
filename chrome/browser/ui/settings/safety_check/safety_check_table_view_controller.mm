// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/settings/safety_check/safety_check_table_view_controller.h"

#import "base/mac/foundation_util.h"
#include "components/strings/grit/components_strings.h"
#import "ios/chrome/browser/ui/settings/safety_check/safety_check_service_delegate.h"
#import "ios/chrome/browser/ui/settings/settings_navigation_controller.h"
#include "ios/chrome/browser/ui/ui_feature_flags.h"
#include "ios/chrome/grit/ios_strings.h"
#include "ui/base/l10n/l10n_util_mac.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

NSString* const kSafetyCheckTableViewId = @"kSafetyCheckTableViewId";

namespace {

typedef NS_ENUM(NSInteger, SectionIdentifier) {
  SectionIdentifierCheckTypes = kSectionIdentifierEnumZero,
  SectionIdentifierCheckStart,
};

}  // namespace

@interface SafetyCheckTableViewController ()

// Current state of array of items that form the safety check.
@property(nonatomic, strong) NSArray<TableViewItem*>* checkTypesItems;

// Current display state of the check start item.
@property(nonatomic, strong) TableViewItem* checkStartItem;

@end

@implementation SafetyCheckTableViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.tableView.accessibilityIdentifier = kSafetyCheckTableViewId;
  self.title =
      l10n_util::GetNSString(IDS_OPTIONS_ADVANCED_SECTION_TITLE_SAFETY_CHECK);
}

#pragma mark - SafetyCheckConsumer

- (void)setCheckItems:(NSArray<TableViewItem*>*)items {
  _checkTypesItems = items;
  [self reloadData];
}

- (void)setCheckStartItem:(TableViewItem*)item {
  _checkStartItem = item;
  [self reloadData];
}

#pragma mark - ChromeTableViewController

- (void)loadModel {
  [super loadModel];

  if (self.checkTypesItems.count) {
    [self.tableViewModel addSectionWithIdentifier:SectionIdentifierCheckTypes];
    for (TableViewItem* item in self.checkTypesItems) {
      [self.tableViewModel addItem:item
           toSectionWithIdentifier:SectionIdentifierCheckTypes];
    }
  }

  if (self.checkStartItem) {
    [self.tableViewModel addSectionWithIdentifier:SectionIdentifierCheckStart];
    [self.tableViewModel addItem:self.checkStartItem
         toSectionWithIdentifier:SectionIdentifierCheckStart];
  }
}

#pragma mark - UIViewController

- (void)didMoveToParentViewController:(UIViewController*)parent {
  [super didMoveToParentViewController:parent];
  if (!parent) {
    [self.presentationDelegate safetyCheckTableViewControllerDidRemove:self];
  }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView*)tableView
    didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
  [super tableView:tableView didSelectRowAtIndexPath:indexPath];
  TableViewItem* item = [self.tableViewModel itemAtIndexPath:indexPath];
  [self.serviceDelegate didSelectItem:item];
  [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
