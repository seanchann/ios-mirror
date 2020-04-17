// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/test/app/browsing_data_test_util.h"

#import <WebKit/WebKit.h>

#include "base/logging.h"
#include "base/task/cancelable_task_tracker.h"
#include "base/task/post_task.h"
#import "base/test/ios/wait_util.h"
#include "components/browsing_data/core/browsing_data_utils.h"
#include "components/history/core/browser/history_service.h"
#include "components/keyed_service/core/service_access_type.h"
#import "ios/chrome/app/main_controller.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#include "ios/chrome/browser/browsing_data/browsing_data_remove_mask.h"
#include "ios/chrome/browser/history/history_service_factory.h"
#import "ios/chrome/browser/ui/commands/browsing_data_commands.h"
#import "ios/chrome/test/app/chrome_test_util.h"
#include "ios/web/public/security/certificate_policy_cache.h"
#include "ios/web/public/thread/web_task_traits.h"
#include "ios/web/public/thread/web_thread.h"
#import "ios/web/web_state/ui/wk_web_view_configuration_provider.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using base::test::ios::WaitUntilConditionOrTimeout;

namespace {

bool ClearBrowsingData(bool off_the_record, BrowsingDataRemoveMask mask) {
  ChromeBrowserState* browser_state =
      off_the_record ? chrome_test_util::GetCurrentIncognitoBrowserState()
                     : chrome_test_util::GetOriginalBrowserState();

  __block bool did_complete = false;
  [chrome_test_util::GetMainController()
      removeBrowsingDataForBrowserState:browser_state
                             timePeriod:browsing_data::TimePeriod::ALL_TIME
                             removeMask:mask
                        completionBlock:^{
                          did_complete = true;
                        }];
  return WaitUntilConditionOrTimeout(
      base::test::ios::kWaitForClearBrowsingDataTimeout, ^{
        return did_complete;
      });
}
}  // namespace

namespace chrome_test_util {

bool RemoveBrowsingCache() {
  return ClearBrowsingData(/*off_the_record=*/false,
                           BrowsingDataRemoveMask::REMOVE_CACHE_STORAGE);
}

bool ClearBrowsingHistory() {
  return ClearBrowsingData(/*off_the_record=*/false,
                           BrowsingDataRemoveMask::REMOVE_HISTORY);
}

bool ClearAllBrowsingData(bool off_the_record) {
  return ClearBrowsingData(off_the_record, BrowsingDataRemoveMask::REMOVE_ALL);
}

bool ClearAllWebStateBrowsingData() {
  __block bool callback_finished = false;
  [[WKWebsiteDataStore defaultDataStore]
      removeDataOfTypes:[WKWebsiteDataStore allWebsiteDataTypes]
          modifiedSince:[NSDate distantPast]
      completionHandler:^{
        web::BrowserState* browser_state =
            chrome_test_util::GetOriginalBrowserState();
        web::WKWebViewConfigurationProvider::FromBrowserState(browser_state)
            .Purge();
        callback_finished = true;
      }];
  return WaitUntilConditionOrTimeout(20, ^{
    return callback_finished;
  });
}

bool ClearCertificatePolicyCache(bool off_the_record) {
  ChromeBrowserState* browser_state = off_the_record
                                          ? GetCurrentIncognitoBrowserState()
                                          : GetOriginalBrowserState();
  auto cache = web::BrowserState::GetCertificatePolicyCache(browser_state);
  __block BOOL policies_cleared = NO;
  base::PostTask(FROM_HERE, {web::WebThread::IO}, base::BindOnce(^{
                   cache->ClearCertificatePolicies();
                   policies_cleared = YES;
                 }));
  return WaitUntilConditionOrTimeout(2, ^{
    return policies_cleared;
  });
}

int GetBrowsingHistoryEntryCount(NSError** error) {
  // Call the history service.
  ChromeBrowserState* browser_state =
      chrome_test_util::GetOriginalBrowserState();
  history::HistoryService* history_service =
      ios::HistoryServiceFactory::GetForBrowserState(
          browser_state, ServiceAccessType::EXPLICIT_ACCESS);

  __block bool history_service_callback_called = false;
  __block int count = -1;
  base::CancelableTaskTracker task_tracker;
  history_service->GetHistoryCount(
      base::Time::Min(), base::Time::Max(),
      base::BindOnce(^(history::HistoryCountResult result) {
        if (result.success) {
          count = result.count;
        }
        history_service_callback_called = true;
      }),
      &task_tracker);

  NSDate* deadline = [NSDate dateWithTimeIntervalSinceNow:4.0];
  while (!history_service_callback_called &&
         [[NSDate date] compare:deadline] != NSOrderedDescending) {
    base::test::ios::SpinRunLoopWithMaxDelay(
        base::TimeDelta::FromSecondsD(0.1));
  }

  NSString* error_message = nil;
  if (!history_service_callback_called) {
    error_message = @"History::GetHistoryCount callback never called, app will "
                     "probably crash later.";
  } else if (count == -1) {
    error_message = @"History::GetHistoryCount did not succeed.";
  }

  if (error_message != nil && error != nil) {
    NSDictionary* error_info = @{NSLocalizedDescriptionKey : error_message};
    *error = [NSError errorWithDomain:@"BrowsingDataTestDomain"
                                 code:0
                             userInfo:error_info];
    LOG(ERROR) << "Querying history service failed: " << error_message;
    return -1;
  }
  return count;
}

}  // namespace chrome_test_util
