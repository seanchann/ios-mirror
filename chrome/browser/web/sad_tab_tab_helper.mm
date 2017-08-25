// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/web/sad_tab_tab_helper.h"

#import <Foundation/Foundation.h>

#include "base/memory/ptr_util.h"
#include "base/strings/sys_string_conversions.h"
#include "ios/chrome/browser/chrome_url_constants.h"
#import "ios/chrome/browser/ui/sad_tab/sad_tab_view.h"
#import "ios/chrome/browser/web/page_placeholder_tab_helper.h"
#import "ios/web/public/navigation_manager.h"
#include "ios/web/public/web_state/navigation_context.h"
#import "ios/web/public/web_state/ui/crw_generic_content_view.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

DEFINE_WEB_STATE_USER_DATA_KEY(SadTabTabHelper);

namespace {
// The default window of time a failure of the same URL needs to occur
// to be considered a repeat failure.
NSTimeInterval const kDefaultRepeatFailureInterval = 60.0f;

// Returns true if the application is in UIApplicationStateActive state.
bool IsApplicationStateActive() {
  return UIApplication.sharedApplication.applicationState ==
         UIApplicationStateActive;
}
}

SadTabTabHelper::SadTabTabHelper(web::WebState* web_state)
    : SadTabTabHelper(web_state, kDefaultRepeatFailureInterval) {}

SadTabTabHelper::SadTabTabHelper(web::WebState* web_state,
                                 double repeat_failure_interval)
    : web::WebStateObserver(web_state),
      repeat_failure_interval_(repeat_failure_interval),
      is_visible_(false),
      requires_reload_on_becoming_visible_(false),
      requires_reload_on_becoming_active_(false) {
  AddApplicationDidBecomeActiveObserver();
}

SadTabTabHelper::~SadTabTabHelper() {
  DCHECK(!application_did_become_active_observer_);
}

void SadTabTabHelper::CreateForWebState(web::WebState* web_state) {
  DCHECK(web_state);
  if (!FromWebState(web_state)) {
    web_state->SetUserData(UserDataKey(),
                           base::WrapUnique(new SadTabTabHelper(web_state)));
  }
}

void SadTabTabHelper::CreateForWebState(web::WebState* web_state,
                                        double repeat_failure_interval) {
  DCHECK(web_state);
  if (!FromWebState(web_state)) {
    web_state->SetUserData(UserDataKey(),
                           base::WrapUnique(new SadTabTabHelper(
                               web_state, repeat_failure_interval)));
  }
}

void SadTabTabHelper::WasShown() {
  is_visible_ = true;

  if (requires_reload_on_becoming_visible_) {
    ReloadTab();
    requires_reload_on_becoming_visible_ = false;
  }
}

void SadTabTabHelper::WasHidden() {
  is_visible_ = false;
}

void SadTabTabHelper::RenderProcessGone() {
  if (!is_visible_) {
    requires_reload_on_becoming_visible_ = true;
    return;
  }

  if (!IsApplicationStateActive()) {
    requires_reload_on_becoming_active_ = true;
    return;
  }

  // Only show Sad Tab if renderer has crashed in a tab currently visible to the
  // user and only if application is active. Otherwise simpy reloading the page
  // is a better user experience.
  PresentSadTab(web_state()->GetLastCommittedURL());
}

void SadTabTabHelper::DidFinishNavigation(
    web::NavigationContext* navigation_context) {
  if (navigation_context->GetUrl().host() == kChromeUICrashHost &&
      navigation_context->GetUrl().scheme() == kChromeUIScheme) {
    PresentSadTab(navigation_context->GetUrl());
  }
}

void SadTabTabHelper::WebStateDestroyed() {
  RemoveApplicationDidBecomeActiveObserver();
}

void SadTabTabHelper::PresentSadTab(const GURL& url_causing_failure) {
  // Is this failure a repeat-failure requiring the presentation of the Feedback
  // UI rather than the Reload UI?
  double seconds_since_last_failure =
      last_failed_timer_ ? last_failed_timer_->Elapsed().InSecondsF() : DBL_MAX;

  bool repeated_failure =
      (url_causing_failure.EqualsIgnoringRef(last_failed_url_) &&
       seconds_since_last_failure < repeat_failure_interval_);

  SadTabView* sad_tab_view = [[SadTabView alloc]
           initWithMode:repeated_failure ? SadTabViewMode::FEEDBACK
                                         : SadTabViewMode::RELOAD
      navigationManager:web_state()->GetNavigationManager()];

  CRWContentView* content_view =
      [[CRWGenericContentView alloc] initWithView:sad_tab_view];

  web_state()->ShowTransientContentView(content_view);

  last_failed_url_ = url_causing_failure;
  last_failed_timer_ = base::MakeUnique<base::ElapsedTimer>();
}

void SadTabTabHelper::ReloadTab() {
  PagePlaceholderTabHelper::FromWebState(web_state())
      ->AddPlaceholderForNextNavigation();
  web_state()->GetNavigationManager()->LoadIfNecessary();
}

void SadTabTabHelper::OnAppDidBecomeActive() {
  if (!requires_reload_on_becoming_active_)
    return;
  if (is_visible_) {
    ReloadTab();
  } else {
    requires_reload_on_becoming_visible_ = true;
  }
  requires_reload_on_becoming_active_ = false;
}

void SadTabTabHelper::AddApplicationDidBecomeActiveObserver() {
  application_did_become_active_observer_ =
      [[NSNotificationCenter defaultCenter]
          addObserverForName:UIApplicationDidBecomeActiveNotification
                      object:nil
                       queue:nil
                  usingBlock:^(NSNotification*) {
                    OnAppDidBecomeActive();
                  }];
}

void SadTabTabHelper::RemoveApplicationDidBecomeActiveObserver() {
  if (application_did_become_active_observer_) {
    [[NSNotificationCenter defaultCenter]
        removeObserver:application_did_become_active_observer_];
    application_did_become_active_observer_ = nil;
  }
}
