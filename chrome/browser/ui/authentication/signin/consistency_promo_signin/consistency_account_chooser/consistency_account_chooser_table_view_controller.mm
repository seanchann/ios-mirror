// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/authentication/signin/consistency_promo_signin/consistency_account_chooser/consistency_account_chooser_table_view_controller.h"

#import "base/check.h"
#import "base/mac/foundation_util.h"
#import "ios/chrome/browser/ui/authentication/cells/table_view_identity_item.h"
#import "ios/chrome/browser/ui/authentication/signin/consistency_promo_signin/consistency_account_chooser/consistency_account_chooser_table_view_controller_action_delegate.h"
#import "ios/chrome/browser/ui/authentication/signin/consistency_promo_signin/consistency_account_chooser/consistency_account_chooser_table_view_controller_model_delegate.h"
#import "ios/chrome/browser/ui/authentication/signin/consistency_promo_signin/consistency_account_chooser/identity_item_configurator.h"
#import "ios/chrome/browser/ui/table_view/cells/table_view_image_item.h"
#import "ios/chrome/common/ui/colors/semantic_color_names.h"
#import "ios/chrome/grit/ios_strings.h"
#import "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

// List of sections.
typedef NS_ENUM(NSInteger, SectionIdentifier) {
  IdentitySectionIdentifier = kSectionIdentifierEnumZero,
  AddAccountSectionIdentifier,
};

typedef NS_ENUM(NSInteger, ItemType) {
  // IdentitySectionIdentifier section.
  IdentityItemType = kItemTypeEnumZero,
  // AddAccountSectionIdentifier section.
  AddAccountItemType,
};

// Table view header/footer height.
CGFloat kSectionHeaderHeight = 8.;
CGFloat kSectionFooterHeight = 8.;

}  // naemspace

@interface ConsistencyAccountChooserTableViewController ()

@end

@implementation ConsistencyAccountChooserTableViewController

#pragma mark - UIView

- (void)viewDidLoad {
  [super viewDidLoad];
  [self loadModel];
  [self.tableView reloadData];
  self.view.backgroundColor = UIColor.clearColor;
}

#pragma mark - UITableViewController

- (void)loadModel {
  [super loadModel];
  [self loadIdentitySection];
  [self loadAddAccountSection];
}

- (void)tableView:(UITableView*)tableView
    didSelectRowAtIndexPath:(NSIndexPath*)indexPath {
  [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
  ListItem* item = [self.tableViewModel itemAtIndexPath:indexPath];
  switch ((ItemType)item.type) {
    case IdentityItemType: {
      TableViewIdentityItem* identityItem =
          base::mac::ObjCCastStrict<TableViewIdentityItem>(item);
      DCHECK(identityItem);
      [self.actionDelegate
          consistencyAccountChooserTableViewController:self
                           didSelectIdentityWithGaiaID:identityItem.gaiaID];
      break;
    }
    case AddAccountItemType:
      [self.actionDelegate
          consistencyAccountChooserTableViewControllerDidTapOnAddAccount:self];
      break;
  }
}

- (CGFloat)tableView:(UITableView*)tableView
    heightForHeaderInSection:(NSInteger)section {
  return kSectionHeaderHeight;
}

- (CGFloat)tableView:(UITableView*)tableView
    heightForFooterInSection:(NSInteger)section {
  return kSectionFooterHeight;
}

#pragma mark - Private

// Creates the identity section in the table view model.
- (void)loadIdentitySection {
  TableViewModel* model = self.tableViewModel;
  [model addSectionWithIdentifier:IdentitySectionIdentifier];
  [self loadIdentityItems];
}

// Creates all the identity items in the table view model.
- (void)loadIdentityItems {
  TableViewModel* model = self.tableViewModel;
  for (IdentityItemConfigurator* configurator in self.modelDelegate
           .sortedIdentityItemConfigurators) {
    TableViewIdentityItem* item =
        [[TableViewIdentityItem alloc] initWithType:IdentityItemType];
    [configurator configureIdentityChooser:item];
    [model addItem:item toSectionWithIdentifier:IdentitySectionIdentifier];
  }
}

// Creates the add account section in the table view model.
- (void)loadAddAccountSection {
  TableViewModel* model = self.tableViewModel;
  [model addSectionWithIdentifier:AddAccountSectionIdentifier];
  TableViewImageItem* item =
      [[TableViewImageItem alloc] initWithType:AddAccountItemType];
  item.title = l10n_util::GetNSString(IDS_IOS_CONSISTENCY_PROMO_ADD_ACCOUNT);
  item.textColor = [UIColor colorNamed:kBlueColor];
  [model addItem:item toSectionWithIdentifier:AddAccountSectionIdentifier];
}

#pragma mark - ConsistencyAccountChooserConsumer

- (void)reloadAllIdentities {
  TableViewModel* model = self.tableViewModel;
  [model deleteAllItemsFromSectionWithIdentifier:IdentitySectionIdentifier];
  [self loadIdentityItems];
  [self.tableView reloadData];
}

- (void)reloadIdentityForIdentityItemConfigurator:
    (IdentityItemConfigurator*)configurator {
  TableViewModel* model = self.tableViewModel;
  NSArray* items =
      [model itemsInSectionWithIdentifier:IdentitySectionIdentifier];
  for (TableViewIdentityItem* item in items) {
    if ([item.gaiaID isEqual:configurator.gaiaID]) {
      [configurator configureIdentityChooser:item];
      [self reconfigureCellsForItems:@[ item ]];
      break;
    }
  }
}

@end
