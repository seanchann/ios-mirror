// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/browser/history/history_service_factory.h"

#include <utility>

#include "base/memory/ptr_util.h"
#include "base/memory/singleton.h"
#include "components/history/core/browser/history_database_params.h"
#include "components/history/core/browser/history_service.h"
#include "components/history/core/browser/visit_delegate.h"
#include "components/history/ios/browser/history_database_helper.h"
#include "components/keyed_service/core/service_access_type.h"
#include "components/keyed_service/ios/browser_state_dependency_manager.h"
#include "components/prefs/pref_service.h"
#include "ios/chrome/browser/bookmarks/bookmark_model_factory.h"
#include "ios/chrome/browser/browser_state/browser_state_otr_helper.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#include "ios/chrome/browser/history/history_client_impl.h"
#include "ios/chrome/browser/pref_names.h"

namespace ios {

// static
history::HistoryService* HistoryServiceFactory::GetForBrowserState(
    ios::ChromeBrowserState* browser_state,
    ServiceAccessType access_type) {
  // If saving history is disabled, only allow explicit access.
  if (access_type != ServiceAccessType::EXPLICIT_ACCESS &&
      browser_state->GetPrefs()->GetBoolean(
          prefs::kSavingBrowserHistoryDisabled)) {
    return nullptr;
  }

  return static_cast<history::HistoryService*>(
      GetInstance()->GetServiceForBrowserState(browser_state, true));
}

// static
history::HistoryService* HistoryServiceFactory::GetForBrowserStateIfExists(
    ios::ChromeBrowserState* browser_state,
    ServiceAccessType access_type) {
  // If saving history is disabled, only allow explicit access.
  if (access_type != ServiceAccessType::EXPLICIT_ACCESS &&
      browser_state->GetPrefs()->GetBoolean(
          prefs::kSavingBrowserHistoryDisabled)) {
    return nullptr;
  }

  return static_cast<history::HistoryService*>(
      GetInstance()->GetServiceForBrowserState(browser_state, true));
}

// static
HistoryServiceFactory* HistoryServiceFactory::GetInstance() {
  return base::Singleton<HistoryServiceFactory>::get();
}

HistoryServiceFactory::HistoryServiceFactory()
    : BrowserStateKeyedServiceFactory(
          "HistoryService",
          BrowserStateDependencyManager::GetInstance()) {
  DependsOn(ios::BookmarkModelFactory::GetInstance());
}

HistoryServiceFactory::~HistoryServiceFactory() {
}

std::unique_ptr<KeyedService> HistoryServiceFactory::BuildServiceInstanceFor(
    web::BrowserState* context) const {
  ios::ChromeBrowserState* browser_state =
      ios::ChromeBrowserState::FromBrowserState(context);
  std::unique_ptr<history::HistoryService> history_service(
      new history::HistoryService(
          base::MakeUnique<HistoryClientImpl>(
              ios::BookmarkModelFactory::GetForBrowserState(browser_state)),
          nullptr));
  if (!history_service->Init(history::HistoryDatabaseParamsForPath(
          browser_state->GetStatePath()))) {
    return nullptr;
  }
  // TODO(crbug.com/703565): remove std::move() once Xcode 9.0+ is required.
  return std::move(history_service);
}

web::BrowserState* HistoryServiceFactory::GetBrowserStateToUse(
    web::BrowserState* context) const {
  return GetBrowserStateRedirectedInIncognito(context);
}

bool HistoryServiceFactory::ServiceIsNULLWhileTesting() const {
  return true;
}

}  // namespace ios
