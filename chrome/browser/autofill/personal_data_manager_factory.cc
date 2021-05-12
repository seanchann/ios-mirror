// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/browser/autofill/personal_data_manager_factory.h"

#include <utility>

#include "base/no_destructor.h"
#include "components/autofill/core/browser/personal_data_manager.h"
#include "components/autofill/core/browser/strike_database.h"
#include "components/autofill/core/browser/webdata/autofill_webdata_service.h"
#include "components/keyed_service/core/service_access_type.h"
#include "components/keyed_service/ios/browser_state_dependency_manager.h"
#include "components/variations/service/variations_service.h"
#include "ios/chrome/browser/application_context.h"
#include "ios/chrome/browser/autofill/autofill_profile_validator_factory.h"
#include "ios/chrome/browser/autofill/strike_database_factory.h"
#include "ios/chrome/browser/browser_state/browser_state_otr_helper.h"
#include "ios/chrome/browser/browser_state/chrome_browser_state.h"
#include "ios/chrome/browser/history/history_service_factory.h"
#include "ios/chrome/browser/signin/identity_manager_factory.h"
#include "ios/chrome/browser/webdata_services/web_data_service_factory.h"

namespace autofill {

namespace {

// Return the latest country code from the chrome variation service.
// If the varaition service is not available, an empty string is returned.
const std::string GetCountryCodeFromVariations() {
  variations::VariationsService* variation_service =
      GetApplicationContext()->GetVariationsService();

  return variation_service
             ? base::ToUpperASCII(variation_service->GetLatestCountry())
             : std::string();
}
}  // namespace

// static
PersonalDataManager* PersonalDataManagerFactory::GetForBrowserState(
    ChromeBrowserState* browser_state) {
  return static_cast<PersonalDataManager*>(
      GetInstance()->GetServiceForBrowserState(browser_state, true));
}

// static
PersonalDataManagerFactory* PersonalDataManagerFactory::GetInstance() {
  static base::NoDestructor<PersonalDataManagerFactory> instance;
  return instance.get();
}

PersonalDataManagerFactory::PersonalDataManagerFactory()
    : BrowserStateKeyedServiceFactory(
          "PersonalDataManager",
          BrowserStateDependencyManager::GetInstance()) {
  DependsOn(IdentityManagerFactory::GetInstance());
  DependsOn(ios::HistoryServiceFactory::GetInstance());
  DependsOn(ios::WebDataServiceFactory::GetInstance());
}

PersonalDataManagerFactory::~PersonalDataManagerFactory() = default;

std::unique_ptr<KeyedService>
PersonalDataManagerFactory::BuildServiceInstanceFor(
    web::BrowserState* context) const {
  ChromeBrowserState* chrome_browser_state =
      ChromeBrowserState::FromBrowserState(context);
  std::unique_ptr<PersonalDataManager> service(
      new PersonalDataManager(GetApplicationContext()->GetApplicationLocale(),
                              GetCountryCodeFromVariations()));
  auto local_storage =
      ios::WebDataServiceFactory::GetAutofillWebDataForBrowserState(
          chrome_browser_state, ServiceAccessType::EXPLICIT_ACCESS);
  auto account_storage =
      ios::WebDataServiceFactory::GetAutofillWebDataForAccount(
          chrome_browser_state, ServiceAccessType::EXPLICIT_ACCESS);
  auto* history_service = ios::HistoryServiceFactory::GetForBrowserState(
      chrome_browser_state, ServiceAccessType::EXPLICIT_ACCESS);
  auto* strike_database =
      StrikeDatabaseFactory::GetForBrowserState(chrome_browser_state);

  service->Init(
      local_storage, account_storage, chrome_browser_state->GetPrefs(),
      GetApplicationContext()->GetLocalState(),
      IdentityManagerFactory::GetForBrowserState(chrome_browser_state),
      AutofillProfileValidatorFactory::GetInstance(), history_service,
      strike_database, chrome_browser_state->IsOffTheRecord());
  return service;
}

}  // namespace autofill
