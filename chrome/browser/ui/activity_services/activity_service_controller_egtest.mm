// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <XCTest/XCTest.h>

#include <memory>

#include "base/ios/ios_util.h"
#include "components/strings/grit/components_strings.h"
#include "ios/chrome/grit/ios_strings.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey_ui.h"
#import "ios/chrome/test/earl_grey/chrome_matchers.h"
#import "ios/chrome/test/earl_grey/web_http_server_chrome_test_case.h"
#import "ios/testing/earl_grey/earl_grey_test.h"
#include "ios/web/public/test/http_server/error_page_response_provider.h"
#import "ios/web/public/test/http_server/http_server.h"
#include "ios/web/public/test/http_server/http_server_util.h"
#include "ios/web/public/test/http_server/response_provider.h"
#include "ui/base/l10n/l10n_util_mac.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
id<GREYMatcher> CopyButton() {
  return grey_allOf(
      grey_accessibilityTrait(UIAccessibilityTraitButton),
      grey_descendant(
          chrome_test_util::StaticTextWithAccessibilityLabel(@"Copy")),
      nil);
}

// Assert the activity service is visible by checking the "copy" button.
void AssertActivityServiceVisible() {
  [[EarlGrey selectElementWithMatcher:CopyButton()]
      assertWithMatcher:grey_interactable()];
}

// Assert the activity service is not visible by checking the "copy" button.
void AssertActivityServiceNotVisible() {
  [[EarlGrey selectElementWithMatcher:grey_allOf(CopyButton(),
                                                 grey_interactable(), nil)]
      assertWithMatcher:grey_nil()];
}

}  // namespace

// Earl grey integration tests for Activity Service Controller.
@interface ActivityServiceControllerTestCase : WebHttpServerChromeTestCase
@end

@implementation ActivityServiceControllerTestCase

- (void)testActivityServiceControllerIsDisabled {
  // TODO(crbug.com/996541) Starting in Xcode 11 beta 6, the share button does
  // not appear (even with a delay) flakily.
  if (@available(iOS 13, *))
    EARL_GREY_TEST_DISABLED(@"Test disabled on iOS13.");

  // Open an un-shareable page.
  GURL kURL("chrome://version");
  [ChromeEarlGrey loadURL:kURL];
  // Verify that the share button is disabled.
  id<GREYMatcher> share_button = chrome_test_util::TabShareButton();
  [[EarlGrey selectElementWithMatcher:share_button]
      assertWithMatcher:grey_accessibilityTrait(
                            UIAccessibilityTraitNotEnabled)];
}

- (void)testOpenActivityServiceControllerAndCopy {
  if (!base::ios::IsRunningOnIOS13OrLater()) {
    EARL_GREY_TEST_DISABLED(@"Test disabled on iOS12.");
  }
  // Set up mock http server.
  std::map<GURL, std::string> responses;
  GURL url = web::test::HttpServer::MakeUrl("http://potato");
  responses[url] = "tomato";
  web::test::SetUpSimpleHttpServer(responses);

  // Open page and open the share menu.
  [ChromeEarlGrey loadURL:url];
  [ChromeEarlGreyUI openShareMenu];

  // Verify that the share menu is up and contains a Copy action.
  AssertActivityServiceVisible();
  [[EarlGrey selectElementWithMatcher:CopyButton()]
      assertWithMatcher:grey_interactable()];

  // Start the Copy action and verify that the share menu gets dismissed.
  [[EarlGrey selectElementWithMatcher:CopyButton()] performAction:grey_tap()];
  AssertActivityServiceNotVisible();
}

@end
