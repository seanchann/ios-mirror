// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/overscroll_actions/overscroll_actions_tab_helper.h"

#import <UIKit/UIKit.h>

#import "base/test/ios/wait_util.h"
#include "ios/chrome/browser/browser_state/test_chrome_browser_state.h"
#import "ios/chrome/browser/ui/overscroll_actions/overscroll_actions_controller.h"
#import "ios/chrome/browser/ui/overscroll_actions/overscroll_actions_view.h"
#import "ios/chrome/common/colors/incognito_color_util.h"
#import "ios/chrome/common/colors/semantic_color_names.h"
#import "ios/chrome/test/fakes/fake_overscroll_actions_controller_delegate.h"
#import "ios/web/public/test/fakes/test_web_state.h"
#include "ios/web/public/test/test_web_thread_bundle.h"
#import "ios/web/public/ui/crw_web_view_proxy.h"
#import "ios/web/public/ui/crw_web_view_scroll_view_proxy.h"
#include "testing/gtest/include/gtest/gtest.h"
#import "testing/gtest_mac.h"
#include "testing/platform_test.h"
#import "third_party/ocmock/OCMock/OCMock.h"
#include "third_party/ocmock/gtest_support.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

// Test fixture for OverscrollActionsTabHelper class.
class OverscrollActionsTabHelperTest : public PlatformTest {
 protected:
  OverscrollActionsTabHelperTest()
      : browser_state_(TestChromeBrowserState::Builder().Build()),
        overscroll_delegate_(
            [[FakeOverscrollActionsControllerDelegate alloc] init]),
        scroll_view_proxy_([[CRWWebViewScrollViewProxy alloc] init]),
        ui_scroll_view_([[UIScrollView alloc] init]) {
    OverscrollActionsTabHelper::CreateForWebState(&web_state_);
    [scroll_view_proxy_ setScrollView:ui_scroll_view_];
    id web_view_proxy_mock = OCMProtocolMock(@protocol(CRWWebViewProxy));
    [[[web_view_proxy_mock stub] andReturn:scroll_view_proxy_] scrollViewProxy];
    web_state_.SetWebViewProxy(web_view_proxy_mock);
    // Setting insets to imitate having omnibox & toolbar.
    scroll_view_proxy_.contentInset = UIEdgeInsetsMake(40, 0, 82, 0);
  }

  OverscrollActionsTabHelper* overscroll_tab_helper() {
    return OverscrollActionsTabHelper::FromWebState(&web_state_);
  }

  UIView* action_view() {
    return overscroll_delegate_.headerView.subviews.firstObject;
  }

  // Simulates scroll on the |scroll_view_proxy_| view, which should trigger
  // page refresh action.
  void SimulatePullForRefreshAction() {
    [scroll_view_proxy_ scrollViewWillBeginDragging:ui_scroll_view_];
    // Wait until scroll action is allowed. There is no condition to wait, just
    // a time period.
    base::test::ios::SpinRunLoopWithMinDelay(base::TimeDelta::FromSecondsD(
        kMinimumPullDurationToTransitionToReadyInSeconds));
    [scroll_view_proxy_ scrollViewDidScroll:ui_scroll_view_];
    scroll_view_proxy_.contentOffset = CGPointMake(0, -293);
    CGPoint target_offset = CGPointMake(0, -92);
    [scroll_view_proxy_ scrollViewWillEndDragging:ui_scroll_view_
                                     withVelocity:CGPointMake(0, -1.5)
                              targetContentOffset:&target_offset];
    [overscroll_delegate_.headerView layoutIfNeeded];
    [scroll_view_proxy_ scrollViewDidEndDragging:ui_scroll_view_
                                  willDecelerate:NO];
  }

  web::TestWebThreadBundle thread_bundle_;
  std::unique_ptr<ios::ChromeBrowserState> browser_state_;
  web::TestWebState web_state_;
  FakeOverscrollActionsControllerDelegate* overscroll_delegate_;
  CRWWebViewScrollViewProxy* scroll_view_proxy_;
  UIScrollView* ui_scroll_view_;
};

// Tests that OverscrollActionsControllerDelegate is set correctly and triggered
// When there is a view pull.
// TODO(crbug.com/944599): Fails on device.
#if TARGET_IPHONE_SIMULATOR
#define MAYBE_TestDelegateTrigger TestDelegateTrigger
#else
#define MAYBE_TestDelegateTrigger DISABLED_TestDelegateTrigger
#endif
TEST_F(OverscrollActionsTabHelperTest, MAYBE_TestDelegateTrigger) {
  web_state_.SetBrowserState(browser_state_.get());
  overscroll_tab_helper()->SetDelegate(overscroll_delegate_);
  // Start pull for page refresh action.
  SimulatePullForRefreshAction();

  // Wait for the layout calls and the delegate call.
  using base::test::ios::WaitUntilConditionOrTimeout;
  using base::test::ios::kWaitForUIElementTimeout;
  EXPECT_TRUE(WaitUntilConditionOrTimeout(kWaitForUIElementTimeout, ^{
    return overscroll_delegate_.selectedAction == OverscrollAction::REFRESH;
  }));
}

// Tests that overscrolls actions view style is set correctly, for regular
// browsing browser state.
// TODO(crbug.com/944599): Fails on device.
#if TARGET_IPHONE_SIMULATOR
#define MAYBE_TestRegularBrowserStateStyle TestRegularBrowserStateStyle
#else
#define MAYBE_TestRegularBrowserStateStyle DISABLED_TestRegularBrowserStateStyle
#endif
TEST_F(OverscrollActionsTabHelperTest, MAYBE_TestRegularBrowserStateStyle) {
  web_state_.SetBrowserState(browser_state_.get());
  overscroll_tab_helper()->SetDelegate(overscroll_delegate_);
  SimulatePullForRefreshAction();
  UIColor* expected_color = [UIColor colorNamed:kBackgroundColor];
  EXPECT_TRUE(action_view());
  EXPECT_NSEQ(expected_color, action_view().backgroundColor);
}

// Tests that overscrolls actions view style is set correctly, for off the
// record browser state.
// TODO(crbug.com/944599): Fails on device.
#if TARGET_IPHONE_SIMULATOR
#define MAYBE_TestOffTheRecordBrowserStateStyle \
  TestOffTheRecordBrowserStateStyle
#else
#define MAYBE_TestOffTheRecordBrowserStateStyle \
  DISABLED_TestOffTheRecordBrowserStateStyle
#endif
TEST_F(OverscrollActionsTabHelperTest,
       MAYBE_TestOffTheRecordBrowserStateStyle) {
  web_state_.SetBrowserState(
      browser_state_->GetOffTheRecordChromeBrowserState());
  overscroll_tab_helper()->SetDelegate(overscroll_delegate_);
  SimulatePullForRefreshAction();
  // For iOS 13 and dark mode, the incognito overscroll actions view uses a
  // dynamic color.
  UIColor* expected_color =
      color::IncognitoDynamicColor(true, [UIColor colorNamed:kBackgroundColor],
                                   [UIColor colorNamed:kBackgroundDarkColor]);
  EXPECT_TRUE(action_view());
  EXPECT_NSEQ(expected_color, action_view().backgroundColor);
}

// Tests that overscroll state is reset when Clear() is called.
TEST_F(OverscrollActionsTabHelperTest, TestClear) {
  web_state_.SetBrowserState(browser_state_.get());
  overscroll_tab_helper()->SetDelegate(overscroll_delegate_);
  OverscrollActionsController* controller =
      overscroll_tab_helper()->GetOverscrollActionsController();
  EXPECT_EQ(OverscrollState::NO_PULL_STARTED, controller.overscrollState);
  SimulatePullForRefreshAction();
  EXPECT_EQ(OverscrollState::ACTION_READY, controller.overscrollState);
  overscroll_tab_helper()->Clear();
  EXPECT_EQ(OverscrollState::NO_PULL_STARTED, controller.overscrollState);
}
