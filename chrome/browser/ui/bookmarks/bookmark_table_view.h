// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_BOOKMARKS_BOOKMARK_TABLE_VIEW_H_
#define IOS_CHROME_BROWSER_UI_BOOKMARKS_BOOKMARK_TABLE_VIEW_H_

#import <UIKit/UIKit.h>
#include <set>

#import "ios/chrome/browser/ui/bookmarks/cells/bookmark_home_promo_item.h"

@class BookmarkHomeSharedState;
@class BookmarkTableView;
class GURL;
@protocol SigninPresenter;
@class SigninPromoViewConfigurator;
@class SigninPromoViewMediator;

namespace bookmarks {
class BookmarkNode;
}  // namespace bookmarks

namespace ios {
class ChromeBrowserState;
}

// Delegate to handle actions on the table.
@protocol BookmarkTableViewDelegate<BookmarkHomePromoItemDelegate>

// Returns the SigninPromoViewMediator to use for the sign-in promo view in the
// bookmark table view.
@property(nonatomic, readonly) SigninPromoViewMediator* signinPromoViewMediator;

// Tells the delegate that a URL was selected for navigation.
- (void)bookmarkTableView:(BookmarkTableView*)view
    selectedUrlForNavigation:(const GURL&)url;

// Tells the delegate that a Folder was selected for navigation.
- (void)bookmarkTableView:(BookmarkTableView*)view
    selectedFolderForNavigation:(const bookmarks::BookmarkNode*)folder;

// Tells the delegate that |nodes| were selected for deletion.
- (void)bookmarkTableView:(BookmarkTableView*)view
    selectedNodesForDeletion:
        (const std::set<const bookmarks::BookmarkNode*>&)nodes;

// Returns true if a bookmarks promo cell should be shown.
- (BOOL)bookmarkTableViewShouldShowPromoCell:(BookmarkTableView*)view;

// Tells the delegate that nodes were selected in edit mode.
- (void)bookmarkTableView:(BookmarkTableView*)view
        selectedEditNodes:
            (const std::set<const bookmarks::BookmarkNode*>&)nodes;

// Tells the delegate to show context menu for the given |node|.
- (void)bookmarkTableView:(BookmarkTableView*)view
    showContextMenuForNode:(const bookmarks::BookmarkNode*)node;

// Tells the delegate that |node| was moved to a new |position|.
- (void)bookmarkTableView:(BookmarkTableView*)view
              didMoveNode:(const bookmarks::BookmarkNode*)node
               toPosition:(int)position;

// Tells the delegate to refresh the context bar.
- (void)bookmarkTableViewRefreshContextBar:(BookmarkTableView*)view;

// Returns true if this table is at the top of the navigation stack.
- (BOOL)isAtTopOfNavigation:(BookmarkTableView*)view;

// TODO(crbug.com/840381): Temporarily made public while migrating code
// out of BookmarkTableView.
- (void)bookmarkTableViewRefreshContents:(BookmarkTableView*)view;

@end

@interface BookmarkTableView : UIView

// Shows all sub-folders and sub-urls of a folder node (that is set as the root
// node) in a UITableView. Note: This class intentionally does not try to
// maintain state through a folder transition. A new instance of this class is
// pushed on the navigation stack for a different root node.
- (instancetype)initWithSharedState:(BookmarkHomeSharedState*)sharedState
                       browserState:(ios::ChromeBrowserState*)browserState
                           delegate:(id<BookmarkTableViewDelegate>)delegate
                              frame:(CGRect)frame NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;
- (instancetype)initWithFrame:(CGRect)frame
                        style:(UITableViewStyle)style NS_UNAVAILABLE;
- (instancetype)initWithCoder:(NSCoder*)aDecoder NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype) new NS_UNAVAILABLE;

// Called when something outside the view causes the promo state to change.
- (void)promoStateChangedAnimated:(BOOL)animated;

// Configures the sign-in promo view using |configurator|, and reloads the table
// view if |identityChanged| is YES.
- (void)configureSigninPromoWithConfigurator:
            (SigninPromoViewConfigurator*)configurator
                             identityChanged:(BOOL)identityChanged;

// Called when adding a new folder
- (void)addNewFolder;

// Returns a vector of edit nodes.
- (std::vector<const bookmarks::BookmarkNode*>)getEditNodesInVector;

// Returns if current root node allows new folder to be created on it.
- (BOOL)allowsNewFolder;

// Returns the row position that is visible.
- (CGFloat)contentPosition;

// Scrolls the table view to the desired row position.
- (void)setContentPosition:(CGFloat)position;

// Called when back or done button of navigation bar is tapped.
- (void)navigateAway;

// TODO(crbug.com/840381): Temporarily made public while migrating code
// out of BookmarkTableView.
- (void)loadFaviconAtIndexPath:(NSIndexPath*)indexPath
        continueToGoogleServer:(BOOL)continueToGoogleServer;
- (void)cancelLoadingFaviconAtIndexPath:(NSIndexPath*)indexPath;
- (void)cancelAllFaviconLoads;
- (void)restoreRowSelection;
- (void)showLoadingSpinnerBackground;
- (void)hideLoadingSpinnerBackground;
- (void)showEmptyBackground;
- (void)hideEmptyBackground;

@end

#endif  // IOS_CHROME_BROWSER_UI_BOOKMARKS_BOOKMARK_TABLE_VIEW_H_
