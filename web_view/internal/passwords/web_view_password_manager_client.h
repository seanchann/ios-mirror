// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_WEB_VIEW_INTERNAL_PASSWORDS_WEB_VIEW_PASSWORD_MANAGER_CLIENT_H_
#define IOS_WEB_VIEW_INTERNAL_PASSWORDS_WEB_VIEW_PASSWORD_MANAGER_CLIENT_H_

#import <Foundation/Foundation.h>
#include <memory>

#include "base/macros.h"
#include "components/autofill/core/browser/logging/log_manager.h"
#include "components/password_manager/core/browser/password_feature_manager.h"
#include "components/password_manager/core/browser/password_form_manager_for_ui.h"
#include "components/password_manager/core/browser/password_manager.h"
#import "components/password_manager/core/browser/password_manager_client.h"
#include "components/password_manager/core/browser/password_manager_client_helper.h"
#include "components/password_manager/core/browser/password_manager_driver.h"
#include "components/password_manager/core/browser/password_manager_metrics_recorder.h"
#include "components/password_manager/core/browser/password_requirements_service.h"
#include "components/password_manager/core/browser/password_store.h"
#include "components/password_manager/core/browser/sync_credentials_filter.h"
#include "components/password_manager/ios/password_manager_client_bridge.h"
#include "components/prefs/pref_member.h"
#include "components/signin/public/identity_manager/identity_manager.h"
#include "components/sync/driver/sync_service.h"
#import "ios/web/public/web_state.h"
#include "ios/web_view/internal/passwords/web_view_password_feature_manager.h"
#include "ios/web_view/internal/web_view_browser_state.h"
#include "url/gurl.h"

namespace ios_web_view {
// An //ios/web_view implementation of password_manager::PasswordManagerClient.
class WebViewPasswordManagerClient
    : public password_manager::PasswordManagerClient {
 public:
  // Convenience factory method for creating a WebViewPasswordManagerClient.
  static std::unique_ptr<WebViewPasswordManagerClient> Create(
      web::WebState* web_state,
      WebViewBrowserState* browser_state);

  explicit WebViewPasswordManagerClient(
      web::WebState* web_state,
      syncer::SyncService* sync_service,
      PrefService* pref_service,
      signin::IdentityManager* identity_manager,
      std::unique_ptr<autofill::LogManager> log_manager,
      password_manager::PasswordStore* profile_store,
      password_manager::PasswordStore* account_store,
      password_manager::PasswordRequirementsService* requirements_service);

  ~WebViewPasswordManagerClient() override;

  // password_manager::PasswordManagerClient implementation.
  password_manager::SyncState GetPasswordSyncState() const override;
  bool PromptUserToSaveOrUpdatePassword(
      std::unique_ptr<password_manager::PasswordFormManagerForUI> form_to_save,
      bool update_password) override;
  void PromptUserToMovePasswordToAccount(
      std::unique_ptr<password_manager::PasswordFormManagerForUI> form_to_move)
      override;
  bool ShowOnboarding(
      std::unique_ptr<password_manager::PasswordFormManagerForUI> form_to_save)
      override;
  void ShowManualFallbackForSaving(
      std::unique_ptr<password_manager::PasswordFormManagerForUI> form_to_save,
      bool has_generated_password,
      bool is_update) override;
  void HideManualFallbackForSaving() override;
  void FocusedInputChanged(
      password_manager::PasswordManagerDriver* driver,
      autofill::mojom::FocusedFieldType focused_field_type) override;
  bool PromptUserToChooseCredentials(
      std::vector<std::unique_ptr<autofill::PasswordForm>> local_forms,
      const url::Origin& origin,
      CredentialsCallback callback) override;
  void AutomaticPasswordSave(
      std::unique_ptr<password_manager::PasswordFormManagerForUI>
          saved_form_manager) override;
  void PromptUserToEnableAutosignin() override;
  bool IsIncognito() const override;
  const password_manager::PasswordManager* GetPasswordManager() const override;
  const password_manager::PasswordFeatureManager* GetPasswordFeatureManager()
      const override;
  PrefService* GetPrefs() const override;
  password_manager::PasswordStore* GetProfilePasswordStore() const override;
  password_manager::PasswordStore* GetAccountPasswordStore() const override;
  void NotifyUserAutoSignin(
      std::vector<std::unique_ptr<autofill::PasswordForm>> local_forms,
      const url::Origin& origin) override;
  void NotifyUserCouldBeAutoSignedIn(
      std::unique_ptr<autofill::PasswordForm> form) override;
  void NotifySuccessfulLoginWithExistingPassword(
      std::unique_ptr<password_manager::PasswordFormManagerForUI>
          submitted_manager) override;
  void NotifyStorePasswordCalled() override;
  bool IsSavingAndFillingEnabled(const GURL& url) const override;
  bool IsCommittedMainFrameSecure() const override;
  const GURL& GetLastCommittedURL() const override;
  url::Origin GetLastCommittedOrigin() const override;
  const password_manager::CredentialsFilter* GetStoreResultFilter()
      const override;
  const autofill::LogManager* GetLogManager() const override;
  ukm::SourceId GetUkmSourceId() override;
  password_manager::PasswordManagerMetricsRecorder* GetMetricsRecorder()
      override;
  signin::IdentityManager* GetIdentityManager() override;
  scoped_refptr<network::SharedURLLoaderFactory> GetURLLoaderFactory() override;
  password_manager::PasswordRequirementsService*
  GetPasswordRequirementsService() override;
  void UpdateFormManagers() override;
  bool IsIsolationForPasswordSitesEnabled() const override;
  bool IsNewTabPage() const override;
  password_manager::FieldInfoManager* GetFieldInfoManager() const override;

  void set_bridge(id<PasswordManagerClientBridge> bridge) { bridge_ = bridge; }
  const syncer::SyncService* GetSyncService();

 private:
  __weak id<PasswordManagerClientBridge> bridge_;

  web::WebState* web_state_;
  syncer::SyncService* sync_service_;
  PrefService* pref_service_;
  signin::IdentityManager* identity_manager_;
  std::unique_ptr<autofill::LogManager> log_manager_;
  password_manager::PasswordStore* profile_store_;
  password_manager::PasswordStore* account_store_;
  WebViewPasswordFeatureManager password_feature_manager_;
  const password_manager::SyncCredentialsFilter credentials_filter_;
  password_manager::PasswordRequirementsService* requirements_service_;

  // The preference associated with
  // password_manager::prefs::kCredentialsEnableService.
  BooleanPrefMember saving_passwords_enabled_;

  // Helper for performing logic that is common between
  // ChromePasswordManagerClient and IOSChromePasswordManagerClient.
  password_manager::PasswordManagerClientHelper helper_;

  DISALLOW_COPY_AND_ASSIGN(WebViewPasswordManagerClient);
};
}  // namespace ios_web_view

#endif  // IOS_WEB_VIEW_INTERNAL_PASSWORDS_WEB_VIEW_PASSWORD_MANAGER_CLIENT_H_
