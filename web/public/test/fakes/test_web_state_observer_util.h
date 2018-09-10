// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_WEB_PUBLIC_TEST_FAKES_TEST_WEB_STATE_OBSERVER_UTIL_H_
#define IOS_WEB_PUBLIC_TEST_FAKES_TEST_WEB_STATE_OBSERVER_UTIL_H_

#include <memory>

#include "ios/web/public/favicon_url.h"
#include "ios/web/public/load_committed_details.h"
#include "url/gurl.h"

namespace web {

class NavigationContext;
class WebFrame;
class WebState;

// Arguments passed to |WasShown|.
struct TestWasShownInfo {
  WebState* web_state = nullptr;
};

// Arguments passed to |WasHidden|.
struct TestWasHiddenInfo {
  WebState* web_state = nullptr;
};

// Arguments passed to |DidStartNavigation|.
struct TestDidStartNavigationInfo {
  TestDidStartNavigationInfo();
  ~TestDidStartNavigationInfo();
  WebState* web_state = nullptr;
  std::unique_ptr<web::NavigationContext> context;
};

// Arguments passed to |DidFinishNavigation|.
struct TestDidFinishNavigationInfo {
  TestDidFinishNavigationInfo();
  ~TestDidFinishNavigationInfo();
  WebState* web_state = nullptr;
  std::unique_ptr<web::NavigationContext> context;
};

// Arguments passed to |NavigationItemCommitted|.
struct TestCommitNavigationInfo {
  WebState* web_state = nullptr;
  LoadCommittedDetails load_details;
};

// Arguments passed to |PageLoaded|.
struct TestLoadPageInfo {
  WebState* web_state = nullptr;
  bool success;
};

// Arguments passed to |LoadProgressChanged|.
struct TestChangeLoadingProgressInfo {
  WebState* web_state = nullptr;
  double progress;
};

// Arguments passed to |NavigationItemsPruned|.
struct TestNavigationItemsPrunedInfo {
  WebState* web_state = nullptr;
  int count;
};

// Arguments passed to |NavigationItemChanged|.
struct TestNavigationItemChangedInfo {
  WebState* web_state = nullptr;
};

// Arguments passed to |TitleWasSet|.
struct TestTitleWasSetInfo {
  WebState* web_state = nullptr;
};

// Arguments passed to |DidChangeVisibleSecurityState|.
struct TestDidChangeVisibleSecurityStateInfo {
  WebState* web_state = nullptr;
};

// Arguments passed to |DidSuppressDialog|.
struct TestDidSuppressDialogInfo {
  WebState* web_state = nullptr;
};

// Arguments passed to |FaviconUrlUpdated|.
struct TestUpdateFaviconUrlCandidatesInfo {
  TestUpdateFaviconUrlCandidatesInfo();
  ~TestUpdateFaviconUrlCandidatesInfo();
  WebState* web_state = nullptr;
  std::vector<web::FaviconURL> candidates;
};

// Arguments passed to |WebFrameDidBecomeAvailable| or
// |WebFrameWillBecomeUnavailable|.
struct TestWebFrameAvailabilityInfo {
  WebState* web_state = nullptr;
  WebFrame* web_frame = nullptr;
};

// Arguments passed to |RenderProcessGone|.
struct TestRenderProcessGoneInfo {
  WebState* web_state = nullptr;
};

// Arguments passed to |WebStateDestroyed|.
struct TestWebStateDestroyedInfo {
  WebState* web_state = nullptr;
};

// Arguments passed to |DidStartLoading|.
struct TestStartLoadingInfo {
  WebState* web_state = nullptr;
};

// Arguments passed to |DidStopLoading|.
struct TestStopLoadingInfo {
  WebState* web_state = nullptr;
};

}  // namespace web

#endif  // IOS_WEB_PUBLIC_TEST_FAKES_TEST_WEB_STATE_OBSERVER_UTIL_H_
