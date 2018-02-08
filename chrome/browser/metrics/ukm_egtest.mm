// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <EarlGrey/EarlGrey.h>
#import <XCTest/XCTest.h>

#include "base/macros.h"
#include "components/metrics/metrics_service.h"
#include "components/metrics_services_manager/metrics_services_manager.h"
#include "components/strings/grit/components_strings.h"
#include "components/ukm/ukm_service.h"
#include "ios/chrome/browser/application_context.h"
#include "ios/chrome/browser/metrics/ios_chrome_metrics_service_accessor.h"
#import "ios/chrome/browser/ui/authentication/signin_earlgrey_utils.h"
#import "ios/chrome/browser/ui/authentication/signin_promo_view.h"
#import "ios/chrome/browser/ui/tab_switcher/tab_switcher_egtest_util.h"
#include "ios/chrome/browser/ui/ui_util.h"
#include "ios/chrome/grit/ios_strings.h"
#import "ios/chrome/test/app/chrome_test_util.h"
#import "ios/chrome/test/app/sync_test_util.h"
#import "ios/chrome/test/app/tab_test_util.h"
#import "ios/chrome/test/earl_grey/chrome_actions.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey_ui.h"
#import "ios/chrome/test/earl_grey/chrome_matchers.h"
#import "ios/chrome/test/earl_grey/chrome_test_case.h"
#import "ios/public/provider/chrome/browser/signin/fake_chrome_identity.h"
#import "ios/public/provider/chrome/browser/signin/fake_chrome_identity_service.h"
#import "ios/testing/wait_util.h"
#include "services/metrics/public/cpp/ukm_recorder.h"
#include "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using chrome_test_util::AccountsSyncButton;
using chrome_test_util::ButtonWithAccessibilityLabelId;
using chrome_test_util::GetIncognitoTabCount;
using chrome_test_util::IsIncognitoMode;
using chrome_test_util::IsSyncInitialized;
using chrome_test_util::NavigationBarDoneButton;
using chrome_test_util::SecondarySignInButton;
using chrome_test_util::SettingsAccountButton;
using chrome_test_util::SettingsAccountButton;
using chrome_test_util::SettingsMenuPrivacyButton;
using chrome_test_util::ClearBrowsingHistoryButton;
using chrome_test_util::NavigationBarDoneButton;
using chrome_test_util::SignOutAccountsButton;
using chrome_test_util::SyncSwitchCell;
using chrome_test_util::TabletTabSwitcherCloseButton;
using chrome_test_util::TabletTabSwitcherOpenTabsPanelButton;
using chrome_test_util::TurnSyncSwitchOn;
using chrome_test_util::ClearBrowsingDataCollectionView;
using chrome_test_util::NavigationBarDoneButton;

namespace metrics {

// Helper class that provides access to UKM internals.
class UkmEGTestHelper {
 public:
  UkmEGTestHelper() {}

  static bool ukm_enabled() {
    auto* service = ukm_service();
    return service ? service->recording_enabled_ : false;
  }

  static uint64_t client_id() {
    auto* service = ukm_service();
    return service ? service->client_id_ : 0;
  }

  static bool HasDummySource(ukm::SourceId source_id) {
    auto* service = ukm_service();
    return service ? !!service->sources().count(source_id) : false;
  }

  static void RecordDummySource(ukm::SourceId source_id) {
    auto* service = ukm_service();
    if (service)
      service->UpdateSourceURL(source_id, GURL("http://example.com"));
  }

 private:
  static ukm::UkmService* ukm_service() {
    return GetApplicationContext()
        ->GetMetricsServicesManager()
        ->GetUkmService();
  }

  DISALLOW_COPY_AND_ASSIGN(UkmEGTestHelper);
};

}  // namespace metrics

namespace {

bool g_metrics_enabled = false;

// Constant for timeout while waiting for asynchronous sync and UKM operations.
const NSTimeInterval kSyncUKMOperationsTimeout = 10.0;

void AssertSyncInitialized(bool is_initialized) {
  ConditionBlock condition = ^{
    return IsSyncInitialized() == is_initialized;
  };
  GREYAssert(testing::WaitUntilConditionOrTimeout(kSyncUKMOperationsTimeout,
                                                  condition),
             @"Failed to assert whether Sync was initialized or not.");
}

void AssertUKMEnabled(bool is_enabled) {
  ConditionBlock condition = ^{
    return metrics::UkmEGTestHelper::ukm_enabled() == is_enabled;
  };
  GREYAssert(testing::WaitUntilConditionOrTimeout(kSyncUKMOperationsTimeout,
                                                  condition),
             @"Failed to assert whether UKM was enabled or not.");
}

// Matcher for the Clear Browsing Data cell on the Privacy screen.
id<GREYMatcher> ClearBrowsingDataCell() {
  return ButtonWithAccessibilityLabelId(IDS_IOS_CLEAR_BROWSING_DATA_TITLE);
}
// Matcher for the clear browsing data button on the clear browsing data panel.
id<GREYMatcher> ClearBrowsingDataButton() {
  return ButtonWithAccessibilityLabelId(IDS_IOS_CLEAR_BUTTON);
}
// Matcher for the clear browsing data action sheet item.
id<GREYMatcher> ConfirmClearBrowsingDataButton() {
  return ButtonWithAccessibilityLabelId(IDS_IOS_CONFIRM_CLEAR_BUTTON);
}

void ClearBrowsingData() {
  [ChromeEarlGreyUI openSettingsMenu];
  [ChromeEarlGreyUI tapSettingsMenuButton:SettingsMenuPrivacyButton()];
  [ChromeEarlGreyUI tapPrivacyMenuButton:ClearBrowsingDataCell()];
  [ChromeEarlGreyUI tapClearBrowsingDataMenuButton:ClearBrowsingDataButton()];
  [[EarlGrey selectElementWithMatcher:ConfirmClearBrowsingDataButton()]
      performAction:grey_tap()];

  // Before returning, make sure that the top of the Clear Browsing Data
  // settings screen is visible to match the state at the start of the method.
  [[EarlGrey selectElementWithMatcher:ClearBrowsingDataCollectionView()]
      performAction:grey_scrollToContentEdge(kGREYContentEdgeTop)];
  [[EarlGrey selectElementWithMatcher:NavigationBarDoneButton()]
      performAction:grey_tap()];
}

void OpenNewIncognitoTab() {
  NSUInteger incognito_tab_count = GetIncognitoTabCount();
  chrome_test_util::OpenNewIncognitoTab();
  [ChromeEarlGrey waitForIncognitoTabCount:(incognito_tab_count + 1)];
  GREYAssert(IsIncognitoMode(), @"Failed to switch to incognito mode.");
}

void CloseCurrentIncognitoTab() {
  NSUInteger incognito_tab_count = GetIncognitoTabCount();
  chrome_test_util::CloseCurrentTab();
  [ChromeEarlGrey waitForIncognitoTabCount:(incognito_tab_count - 1)];
}

void CloseAllIncognitoTabs() {
  GREYAssert(chrome_test_util::CloseAllIncognitoTabs(), @"Tabs did not close");
  [ChromeEarlGrey waitForIncognitoTabCount:0];
  if (IsIPadIdiom()) {
    // Switch to the non-incognito panel and leave the tab switcher.
    [[EarlGrey selectElementWithMatcher:TabletTabSwitcherOpenTabsPanelButton()]
        performAction:grey_tap()];
    [[EarlGrey selectElementWithMatcher:TabletTabSwitcherCloseButton()]
        performAction:grey_tap()];
  }
  GREYAssert(!IsIncognitoMode(), @"Failed to switch to normal mode.");
}

void OpenNewRegularTab() {
  NSUInteger tab_count = chrome_test_util::GetMainTabCount();
  chrome_test_util::OpenNewTab();
  [ChromeEarlGrey waitForMainTabCount:(tab_count + 1)];
}

// Grant/revoke metrics consent and update MetricsServicesManager.
void UpdateMetricsConsent(bool new_state) {
  g_metrics_enabled = new_state;
  GetApplicationContext()->GetMetricsServicesManager()->UpdateUploadPermissions(
      true);
}

// Signs in to sync.
void SignIn() {
  ChromeIdentity* identity = [SigninEarlGreyUtils fakeIdentity1];
  ios::FakeChromeIdentityService::GetInstanceFromChromeProvider()->AddIdentity(
      identity);

  [ChromeEarlGreyUI openSettingsMenu];
  [ChromeEarlGreyUI tapSettingsMenuButton:SecondarySignInButton()];
  [ChromeEarlGreyUI signInToIdentityByEmail:identity.userEmail];
  [ChromeEarlGreyUI confirmSigninConfirmationDialog];
  [[EarlGrey selectElementWithMatcher:NavigationBarDoneButton()]
      performAction:grey_tap()];

  [SigninEarlGreyUtils assertSignedInWithIdentity:identity];
}

// Signs in to sync by tapping the sign-in promo view.
void SignInWithPromo() {
  [ChromeEarlGreyUI openSettingsMenu];
  [SigninEarlGreyUtils
      checkSigninPromoVisibleWithMode:SigninPromoViewModeWarmState];
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(
                                          kSigninPromoPrimaryButtonId)]
      performAction:grey_tap()];
  [ChromeEarlGreyUI confirmSigninConfirmationDialog];
  [[EarlGrey selectElementWithMatcher:NavigationBarDoneButton()]
      performAction:grey_tap()];

  [SigninEarlGreyUtils
      assertSignedInWithIdentity:[SigninEarlGreyUtils fakeIdentity1]];
}

// Signs out of sync.
void SignOut() {
  [ChromeEarlGreyUI openSettingsMenu];
  [[EarlGrey selectElementWithMatcher:SettingsAccountButton()]
      performAction:grey_tap()];
  [ChromeEarlGreyUI tapAccountsMenuButton:SignOutAccountsButton()];
  [[EarlGrey selectElementWithMatcher:
                 ButtonWithAccessibilityLabelId(
                     IDS_IOS_DISCONNECT_DIALOG_CONTINUE_BUTTON_MOBILE)]
      performAction:grey_tap()];
  [[EarlGrey selectElementWithMatcher:NavigationBarDoneButton()]
      performAction:grey_tap()];

  [SigninEarlGreyUtils assertSignedOut];
}

}  // namespace

// UKM tests.
@interface UKMTestCase : ChromeTestCase

@end

@implementation UKMTestCase

+ (void)setUp {
  [super setUp];
  if (!base::FeatureList::IsEnabled(ukm::kUkmFeature)) {
    // ukm::kUkmFeature feature is not enabled. You need to pass
    // --enable-features=Ukm command line argument in order to run this test.
    DCHECK(false);
  }
}

- (void)setUp {
  [super setUp];

  AssertSyncInitialized(false);
  AssertUKMEnabled(false);

  // Enable sync.
  SignIn();
  AssertSyncInitialized(true);

  // Grant metrics consent and update MetricsServicesManager.
  GREYAssert(!g_metrics_enabled, @"Unpaired set/reset of user consent.");
  g_metrics_enabled = true;
  IOSChromeMetricsServiceAccessor::SetMetricsAndCrashReportingForTesting(
      &g_metrics_enabled);
  GetApplicationContext()->GetMetricsServicesManager()->UpdateUploadPermissions(
      true);
  AssertUKMEnabled(true);
}

- (void)tearDown {
  AssertSyncInitialized(true);
  AssertUKMEnabled(true);

  // Revoke metrics consent and update MetricsServicesManager.
  GREYAssert(g_metrics_enabled, @"Unpaired set/reset of user consent.");
  g_metrics_enabled = false;
  GetApplicationContext()->GetMetricsServicesManager()->UpdateUploadPermissions(
      true);
  IOSChromeMetricsServiceAccessor::SetMetricsAndCrashReportingForTesting(
      nullptr);
  AssertUKMEnabled(false);

  // Disable sync.
  SignOut();
  AssertSyncInitialized(false);
  chrome_test_util::ClearSyncServerData();

  [super tearDown];
}

// The tests in this file should correspond with the ones in
// //chrome/browser/metrics/ukm_browsertest.cc

// Make sure that UKM is disabled while an incognito tab is open.
// TODO(crbug.com/806784): Re-enable this test on devices.
#if TARGET_OS_SIMULATOR
#define MAYBE_testRegularPlusIncognito testRegularPlusIncognito
#else
#define MAYBE_testRegularPlusIncognito FLAKY_testRegularPlusIncognito
#endif
- (void)MAYBE_testRegularPlusIncognito {
  uint64_t original_client_id = metrics::UkmEGTestHelper::client_id();

  OpenNewIncognitoTab();
  AssertUKMEnabled(false);

  // Opening another regular tab mustn't enable UKM.
  OpenNewRegularTab();
  AssertUKMEnabled(false);

  // Opening and closing an incognito tab mustn't enable UKM.
  OpenNewIncognitoTab();
  AssertUKMEnabled(false);
  CloseCurrentIncognitoTab();
  AssertUKMEnabled(false);

  CloseAllIncognitoTabs();
  AssertUKMEnabled(true);

  // Client ID should not have been reset.
  GREYAssert(original_client_id == metrics::UkmEGTestHelper::client_id(),
             @"Client ID was reset.");
}

// Make sure opening a real tab after Incognito doesn't enable UKM.
// TODO(crbug.com/806784): Re-enable this test on devices.
#if TARGET_OS_SIMULATOR
#define MAYBE_testIncognitoPlusRegular testIncognitoPlusRegular
#else
#define MAYBE_testIncognitoPlusRegular FLAKY_testIncognitoPlusRegular
#endif
- (void)MAYBE_testIncognitoPlusRegular {
  uint64_t original_client_id = metrics::UkmEGTestHelper::client_id();
  chrome_test_util::CloseAllTabs();
  [ChromeEarlGrey waitForMainTabCount:(0)];

  OpenNewIncognitoTab();
  AssertUKMEnabled(false);

  // Opening another regular tab mustn't enable UKM.
  OpenNewRegularTab();
  AssertUKMEnabled(false);

  GREYAssert(chrome_test_util::CloseAllIncognitoTabs(), @"Tabs did not close");
  [ChromeEarlGrey waitForIncognitoTabCount:0];
  AssertUKMEnabled(true);

  // Client ID should not have been reset.
  GREYAssert(original_client_id == metrics::UkmEGTestHelper::client_id(),
             @"Client ID was reset.");
}

// testOpenNonSync not needed, since there can't be multiple profiles.

// Make sure that UKM is disabled when metrics consent is revoked.
// TODO(crbug.com/806784): Re-enable this test on devices.
#if TARGET_OS_SIMULATOR
#define MAYBE_testMetricsConsent testMetricsConsent
#else
#define MAYBE_testMetricsConsent FLAKY_testMetricsConsent
#endif
- (void)MAYBE_testMetricsConsent {
  uint64_t original_client_id = metrics::UkmEGTestHelper::client_id();

  UpdateMetricsConsent(false);

  AssertUKMEnabled(false);

  UpdateMetricsConsent(true);

  AssertUKMEnabled(true);
  // Client ID should have been reset.
  GREYAssert(original_client_id != metrics::UkmEGTestHelper::client_id(),
             @"Client ID was not reset.");
}

// Make sure that providing metrics consent doesn't enable UKM w/o sync.
// TODO(crbug.com/806784): Re-enable this test on devices.
#if TARGET_OS_SIMULATOR
#define MAYBE_testConsentAddedButNoSync testConsentAddedButNoSync
#else
#define MAYBE_testConsentAddedButNoSync FLAKY_testConsentAddedButNoSync
#endif
- (void)MAYBE_testConsentAddedButNoSync {
  SignOut();
  UpdateMetricsConsent(false);
  AssertUKMEnabled(false);

  UpdateMetricsConsent(true);
  AssertUKMEnabled(false);

  SignInWithPromo();
  AssertUKMEnabled(true);
}

// Make sure that UKM is disabled when sync is disabled.
// TODO(crbug.com/806784): Re-enable this test on devices.
#if TARGET_OS_SIMULATOR
#define MAYBE_testSingleDisableSync testSingleDisableSync
#else
#define MAYBE_testSingleDisableSync FLAKY_testSingleDisableSync
#endif
- (void)MAYBE_testSingleDisableSync {
  uint64_t original_client_id = metrics::UkmEGTestHelper::client_id();

  [ChromeEarlGreyUI openSettingsMenu];
  // Open accounts settings, then sync settings.
  [[EarlGrey selectElementWithMatcher:SettingsAccountButton()]
      performAction:grey_tap()];
  [[EarlGrey selectElementWithMatcher:AccountsSyncButton()]
      performAction:grey_tap()];
  // Toggle "Sync Everything" then "History" switches off.
  [[EarlGrey selectElementWithMatcher:SyncSwitchCell(
                                          l10n_util::GetNSString(
                                              IDS_IOS_SYNC_EVERYTHING_TITLE),
                                          YES)]
      performAction:TurnSyncSwitchOn(NO)];
  [[EarlGrey
      selectElementWithMatcher:SyncSwitchCell(l10n_util::GetNSString(
                                                  IDS_SYNC_DATATYPE_TYPED_URLS),
                                              YES)]
      performAction:TurnSyncSwitchOn(NO)];

  AssertUKMEnabled(false);

  // Toggle "History" then "Sync Everything" switches on.
  [[EarlGrey
      selectElementWithMatcher:SyncSwitchCell(l10n_util::GetNSString(
                                                  IDS_SYNC_DATATYPE_TYPED_URLS),
                                              NO)]
      performAction:TurnSyncSwitchOn(YES)];
  [[EarlGrey selectElementWithMatcher:SyncSwitchCell(
                                          l10n_util::GetNSString(
                                              IDS_IOS_SYNC_EVERYTHING_TITLE),
                                          NO)]
      performAction:TurnSyncSwitchOn(YES)];

  AssertUKMEnabled(true);
  // Client ID should have been reset.
  GREYAssert(original_client_id != metrics::UkmEGTestHelper::client_id(),
             @"Client ID was not reset.");

  [[EarlGrey selectElementWithMatcher:NavigationBarDoneButton()]
      performAction:grey_tap()];
}

// testMultiDisableSync not needed, since there can't be multiple profiles.

// Make sure that UKM is disabled when a secondary passphrase is used.
// TODO(crbug.com/806784): Re-enable this test on devices.
#if TARGET_OS_SIMULATOR
#define MAYBE_testSecondaryPassphrase testSecondaryPassphrase
#else
#define MAYBE_testSecondaryPassphrase FLAKY_testSecondaryPassphrase
#endif
- (void)MAYBE_testSecondaryPassphrase {
  uint64_t original_client_id = metrics::UkmEGTestHelper::client_id();

  [ChromeEarlGreyUI openSettingsMenu];
  // Open accounts settings, then sync settings.
  [[EarlGrey selectElementWithMatcher:SettingsAccountButton()]
      performAction:grey_tap()];
  [[EarlGrey selectElementWithMatcher:AccountsSyncButton()]
      performAction:grey_tap()];
  // Open sync encryption menu.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(@"kSettingsSyncId")]
      performAction:grey_scrollToContentEdge(kGREYContentEdgeBottom)];
  [[EarlGrey selectElementWithMatcher:grey_accessibilityLabel(
                                          l10n_util::GetNSStringWithFixup(
                                              IDS_IOS_SYNC_ENCRYPTION_TITLE))]
      performAction:grey_tap()];
  // Select passphrase encryption.
  [[EarlGrey selectElementWithMatcher:ButtonWithAccessibilityLabelId(
                                          IDS_SYNC_FULL_ENCRYPTION_DATA)]
      performAction:grey_tap()];
  // Type and confirm passphrase, then submit.
  [[EarlGrey selectElementWithMatcher:grey_accessibilityValue(@"Passphrase")]
      performAction:grey_typeText(@"mypassphrase")];
  [[EarlGrey
      selectElementWithMatcher:grey_accessibilityValue(@"Confirm passphrase")]
      performAction:grey_typeText(@"mypassphrase")];
  [[EarlGrey selectElementWithMatcher:ButtonWithAccessibilityLabelId(
                                          IDS_IOS_SYNC_DECRYPT_BUTTON)]
      performAction:grey_tap()];

  AssertUKMEnabled(false);
  // Client ID should have been reset.
  GREYAssert(original_client_id != metrics::UkmEGTestHelper::client_id(),
             @"Client ID was not reset.");

  [[EarlGrey selectElementWithMatcher:NavigationBarDoneButton()]
      performAction:grey_tap()];

  // Reset sync back to original state.
  SignOut();
  chrome_test_util::ClearSyncServerData();
  SignInWithPromo();
  AssertUKMEnabled(true);
}

// Make sure that UKM is disabled when sync is not enabled.
// TODO(crbug.com/806784): Re-enable this test on devices.
#if TARGET_OS_SIMULATOR
#define MAYBE_testSingleSyncSignout testSingleSyncSignout
#else
#define MAYBE_testSingleSyncSignout FLAKY_testSingleSyncSignout
#endif
- (void)MAYBE_testSingleSyncSignout {
  uint64_t original_client_id = metrics::UkmEGTestHelper::client_id();

  SignOut();

  AssertUKMEnabled(false);
  // Client ID should have been reset by signout.
  GREYAssert(original_client_id != metrics::UkmEGTestHelper::client_id(),
             @"Client ID was not reset.");

  original_client_id = metrics::UkmEGTestHelper::client_id();
  SignInWithPromo();

  AssertUKMEnabled(true);
  // Client ID should not have been reset.
  GREYAssert(original_client_id == metrics::UkmEGTestHelper::client_id(),
             @"Client ID was reset.");
}

// testMultiSyncSignout not needed, since there can't be multiple profiles.

// testMetricsReporting not needed, since iOS doesn't use sampling.

// TODO(crbug.com/806784): Re-enable this test on devices.
#if TARGET_OS_SIMULATOR
#define MAYBE_testHistoryDelete testHistoryDelete
#else
#define MAYBE_testHistoryDelete FLAKY_testHistoryDelete
#endif
- (void)MAYBE_testHistoryDelete {
  uint64_t original_client_id = metrics::UkmEGTestHelper::client_id();

  const ukm::SourceId kDummySourceId = 0x54321;
  metrics::UkmEGTestHelper::RecordDummySource(kDummySourceId);
  GREYAssert(metrics::UkmEGTestHelper::HasDummySource(kDummySourceId),
             @"Dummy source failed to record.");

  ClearBrowsingData();

  // Other sources may already have been recorded since the data was cleared,
  // but the dummy source should be gone.
  GREYAssert(!metrics::UkmEGTestHelper::HasDummySource(kDummySourceId),
             @"Dummy source was not purged.");
  GREYAssert(original_client_id == metrics::UkmEGTestHelper::client_id(),
             @"Client ID was reset.");
  AssertUKMEnabled(true);
}

@end
