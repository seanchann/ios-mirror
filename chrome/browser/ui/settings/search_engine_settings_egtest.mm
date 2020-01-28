// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "base/strings/sys_string_conversions.h"
#import "base/test/ios/wait_util.h"
#include "ios/chrome/grit/ios_strings.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey_ui.h"
#import "ios/chrome/test/earl_grey/chrome_matchers.h"
#import "ios/chrome/test/earl_grey/chrome_test_case.h"
#include "ios/testing/earl_grey/disabled_test_macros.h"
#import "ios/testing/earl_grey/earl_grey_test.h"
#include "net/test/embedded_test_server/embedded_test_server.h"
#include "net/test/embedded_test_server/http_request.h"
#include "net/test/embedded_test_server/http_response.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

const char kPageURL[] = "/";
const char kOpenSearch[] = "/opensearch.xml";
const char kSearchURL[] = "/search?q=";
const char kCustomSearchEngineName[] = "Custom Search Engine";

NSString* GetCustomeSearchEngineLabel() {
  return [NSString stringWithFormat:@"%s, 127.0.0.1", kCustomSearchEngineName];
}

std::string GetSearchExample() {
  return std::string(kSearchURL) + "example";
}

// Responses for the test http server. |server_url| is the URL of the server,
// used for absolute URL in the response. |open_search_queried| is set to true
// when the OpenSearchDescription is queried.
std::unique_ptr<net::test_server::HttpResponse> StandardResponse(
    std::string* server_url,
    bool* open_search_queried,
    const net::test_server::HttpRequest& request) {
  std::unique_ptr<net::test_server::BasicHttpResponse> http_response =
      std::make_unique<net::test_server::BasicHttpResponse>();
  http_response->set_code(net::HTTP_OK);

  if (request.relative_url == kPageURL) {
    http_response->set_content("<head><link rel=\"search\" "
                               "type=\"application/opensearchdescription+xml\" "
                               "title=\"Custom Search Engine\" href=\"" +
                               std::string(kOpenSearch) +
                               "\"></head><body>Test Search</body>");
  } else if (request.relative_url == kOpenSearch) {
    *open_search_queried = true;
    http_response->set_content(
        "<OpenSearchDescription xmlns=\"http://a9.com/-/spec/opensearch/1.1/\">"
        "<ShortName>" +
        std::string(kCustomSearchEngineName) +
        "</ShortName>"
        "<Description>Description</Description>"
        "<Url type=\"text/html\" method=\"get\" template=\"" +
        *server_url + kSearchURL +
        "{searchTerms}\"/>"
        "</OpenSearchDescription>");
  } else if (request.relative_url == GetSearchExample()) {
    http_response->set_content("<head><body>Search Result</body>");

  } else {
    return nullptr;
  }
  return std::move(http_response);
}

}  // namespace

@interface SearchEngineSettingsTestCase : ChromeTestCase {
  std::string _serverURL;
  bool _openSearchCalled;
}

@end

@implementation SearchEngineSettingsTestCase

// Deletes a custom search engine by swiping and tapping on the "Delete" button.
- (void)testDeleteCustomSearchEngineSwipeAndTap {
  // TODO(crbug.com/1046290): fix for iPad 13.3 and reenable.
  if (@available(iOS 13.3, *)) {
    if ([ChromeEarlGrey isIPadIdiom]) {
      EARL_GREY_TEST_DISABLED(@"Test disabled on iPad with iOS > 13.3.");
    }
  }

  if (@available(iOS 13, *)) {
  } else {
    EARL_GREY_TEST_SKIPPED(
        @"Test disabled on iOS 12 as this feature isn't present.");
  }
  [self enterSettingsWithCustomSearchEngine];

  id<GREYMatcher> customSearchEngineCell =
      grey_accessibilityLabel(GetCustomeSearchEngineLabel());

  [[EarlGrey selectElementWithMatcher:customSearchEngineCell]
      assertWithMatcher:grey_sufficientlyVisible()];

  [[EarlGrey selectElementWithMatcher:customSearchEngineCell]
      performAction:grey_swipeSlowInDirectionWithStartPoint(kGREYDirectionLeft,
                                                            0.3, 0.5)];

  [[EarlGrey selectElementWithMatcher:grey_accessibilityLabel(@"Delete")]
      performAction:grey_tap()];

  [[EarlGrey selectElementWithMatcher:customSearchEngineCell]
      assertWithMatcher:grey_nil()];
}

// Deletes a custom engine by swiping it.
- (void)testDeleteCustomSearchEngineSwipe {
  [self enterSettingsWithCustomSearchEngine];

  id<GREYMatcher> customSearchEngineCell =
      grey_accessibilityLabel(GetCustomeSearchEngineLabel());

  [[EarlGrey selectElementWithMatcher:customSearchEngineCell]
      performAction:grey_swipeSlowInDirectionWithStartPoint(kGREYDirectionLeft,
                                                            0.9, 0.5)];

  [[EarlGrey selectElementWithMatcher:customSearchEngineCell]
      assertWithMatcher:grey_nil()];
}

// Deletes a custom search engine by entering edit mode.
- (void)testDeleteCustomSearchEngineEdit {
  [self enterSettingsWithCustomSearchEngine];

  id<GREYMatcher> editButton = grey_allOf(
      chrome_test_util::ButtonWithAccessibilityLabelId(
          IDS_IOS_NAVIGATION_BAR_EDIT_BUTTON),
      grey_not(grey_accessibilityTrait(UIAccessibilityTraitNotEnabled)), nil);
  [[EarlGrey selectElementWithMatcher:editButton] performAction:grey_tap()];

  id<GREYMatcher> customSearchEngineCell =
      grey_accessibilityLabel(GetCustomeSearchEngineLabel());
  [[EarlGrey selectElementWithMatcher:customSearchEngineCell]
      assertWithMatcher:grey_sufficientlyVisible()];
  [[EarlGrey selectElementWithMatcher:customSearchEngineCell]
      performAction:grey_tap()];

  id<GREYMatcher> deleteButton = grey_allOf(
      grey_accessibilityLabel(@"Delete"),
      grey_accessibilityTrait(UIAccessibilityTraitButton),
      grey_not(grey_accessibilityTrait(UIAccessibilityTraitNotEnabled)), nil);
  [[EarlGrey selectElementWithMatcher:deleteButton] performAction:grey_tap()];

  [[EarlGrey selectElementWithMatcher:customSearchEngineCell]
      assertWithMatcher:grey_nil()];
}

#pragma mark - helpers

// Adds a custom search engine by navigating to a fake search engine page, then
// enters the search engine screen in Settings.
- (void)enterSettingsWithCustomSearchEngine {
  _openSearchCalled = false;
  self.testServer->RegisterRequestHandler(
      base::Bind(&StandardResponse, &(_serverURL), &(_openSearchCalled)));
  GREYAssertTrue(self.testServer->Start(), @"Test server failed to start.");
  const GURL pageURL = self.testServer->GetURL(kPageURL);
  _serverURL = pageURL.spec();
  // Remove trailing "/".
  _serverURL.pop_back();

  [ChromeEarlGrey loadURL:pageURL];

  GREYCondition* openSearchQuery =
      [GREYCondition conditionWithName:@"Wait for Open Search query"
                                 block:^BOOL {
                                   return _openSearchCalled;
                                 }];
  // Wait for the
  GREYAssertTrue([openSearchQuery
                     waitWithTimeout:base::test::ios::kWaitForPageLoadTimeout],
                 @"The open search XML hasn't been queried.");

  [ChromeEarlGrey loadURL:self.testServer->GetURL(GetSearchExample())];

  [ChromeEarlGreyUI openSettingsMenu];
  [[EarlGrey
      selectElementWithMatcher:chrome_test_util::SettingsSearchEngineButton()]
      performAction:grey_tap()];
}

@end
