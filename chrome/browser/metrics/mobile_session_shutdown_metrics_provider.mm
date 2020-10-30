// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/browser/metrics/mobile_session_shutdown_metrics_provider.h"

#import <Foundation/Foundation.h>

#include "base/logging.h"
#include "base/metrics/histogram_macros.h"
#include "base/path_service.h"
#include "base/strings/sys_string_conversions.h"
#include "base/system/sys_info.h"
#include "base/task/post_task.h"
#include "base/version.h"
#include "components/metrics/metrics_pref_names.h"
#include "components/metrics/metrics_service.h"
#import "components/previous_session_info/previous_session_info.h"
#include "components/version_info/version_info.h"
#include "ios/chrome/browser/application_context.h"
#import "ios/chrome/browser/crash_report/breadcrumbs/breadcrumb_persistent_storage_manager.h"
#include "ios/chrome/browser/crash_report/breadcrumbs/features.h"
#include "ios/chrome/browser/crash_report/breakpad_helper.h"
#include "ios/chrome/browser/crash_report/features.h"
#include "ios/chrome/browser/crash_report/main_thread_freeze_detector.h"
#include "ios/chrome/browser/crash_report/synthetic_crash_report_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

using previous_session_info_constants::DeviceBatteryState;
using previous_session_info_constants::DeviceThermalState;

namespace {

// Amount of storage, in kilobytes, considered to be critical enough to
// negatively effect device operation.
const int kCriticallyLowDeviceStorage = 1024 * 5;

// An enum representing the difference between two version numbers.
// These values are persisted to logs. Entries should not be renumbered and
// numeric values should never be reused.
enum class VersionComparison {
  kSameVersion = 0,
  kMinorVersionChange = 1,
  kMajorVersionChange = 2,
  kMaxValue = kMajorVersionChange,
};

// Values of the UMA Stability.iOS.UTE.MobileSessionOOMShutdownHint histogram.
// These values are persisted to logs. Entries should not be renumbered and
// numeric values should never be reused.
enum class MobileSessionOomShutdownHint {
  // There is no additional information for this UTE/XTE.
  NoInformation = 0,
  // Session restoration was in progress before this UTE.
  SessionRestorationUte = 1,
  // Session restoration was in progress before this XTE.
  SessionRestorationXte = 2,
  kMaxValue = SessionRestorationXte
};

// Values of the Stability.iOS.UTE.MobileSessionAppWillTerminateReceived
// histogram. These values are persisted to logs. Entries should not be
// renumbered and numeric values should never be reused.
enum class MobileSessionAppWillTerminateReceived {
  // ApplicationWillTerminate notification was not received for this XTE.
  WasNotReceivedForXte = 0,
  // ApplicationWillTerminate notification was not received for this UTE.
  WasNotReceivedForUte = 1,
  // ApplicationWillTerminate notification was received for this XTE.
  WasReceivedForXte = 2,
  // ApplicationWillTerminate notification was received for this UTE.
  WasReceivedForUte = 3,
  kMaxValue = WasReceivedForUte
};

// Values of the Stability.iOS.UTE.MobileSessionAppState histogram.
// These values are persisted to logs. Entries should not be renumbered and
// numeric values should never be reused.
enum class MobileSessionAppState {
  // This should not happen and presence of this value likely indicates a bug
  // in Chrome or UIKit code.
  UnknownUte = 0,

  // This should not happen and presence of this value likely indicates a bug
  // in Chrome or UIKit code.
  UnknownXte = 1,

  // App state was UIApplicationStateActive during UTE.
  ActiveUte = 2,

  // App state was UIApplicationStateActive during XTE.
  ActiveXte = 3,

  // App state was UIApplicationStateInactive during UTE.
  InactiveUte = 4,

  // App state was UIApplicationStateInactive during XTE.
  InactiveXte = 5,

  // App state was UIApplicationStateBackground during UTE.
  BackgroundUte = 6,

  // App state was UIApplicationStateBackground during XTE.
  BackgroundXte = 7,
  kMaxValue = BackgroundXte
};

// Returns value to log for Stability.iOS.UTE.MobileSessionOOMShutdownHint
// histogram.
MobileSessionOomShutdownHint GetMobileSessionOomShutdownHint(
    bool has_possible_explanation) {
  if ([PreviousSessionInfo sharedInstance].terminatedDuringSessionRestoration) {
    return has_possible_explanation
               ? MobileSessionOomShutdownHint::SessionRestorationXte
               : MobileSessionOomShutdownHint::SessionRestorationUte;
  }
  return MobileSessionOomShutdownHint::NoInformation;
}

// Returns value to log for Stability.iOS.UTE.MobileSessionAppState
// histogram.
MobileSessionAppState GetMobileSessionAppState(bool has_possible_explanation) {
  if (!PreviousSessionInfo.sharedInstance.applicationState) {
    return has_possible_explanation ? MobileSessionAppState::UnknownXte
                                    : MobileSessionAppState::UnknownUte;
  }

  switch (*PreviousSessionInfo.sharedInstance.applicationState) {
    case UIApplicationStateActive:
      return has_possible_explanation ? MobileSessionAppState::ActiveXte
                                      : MobileSessionAppState::ActiveUte;
    case UIApplicationStateInactive:
      return has_possible_explanation ? MobileSessionAppState::InactiveXte
                                      : MobileSessionAppState::InactiveUte;
    case UIApplicationStateBackground:
      return has_possible_explanation ? MobileSessionAppState::BackgroundXte
                                      : MobileSessionAppState::BackgroundUte;
  }
  NOTREACHED();
}

// Returns value to record for
// Stability.iOS.UTE.MobileSessionAppWillTerminateReceived histogram.
MobileSessionAppWillTerminateReceived GetMobileSessionAppWillTerminateReceived(
    bool has_possible_explanation) {
  if (!PreviousSessionInfo.sharedInstance.applicationWillTerminateWasReceived) {
    return has_possible_explanation
               ? MobileSessionAppWillTerminateReceived::WasNotReceivedForXte
               : MobileSessionAppWillTerminateReceived::WasNotReceivedForUte;
  }

  return has_possible_explanation
             ? MobileSessionAppWillTerminateReceived::WasReceivedForXte
             : MobileSessionAppWillTerminateReceived::WasReceivedForUte;
}

// Logs |type| in the shutdown type histogram.
void LogShutdownType(MobileSessionShutdownType type) {
  UMA_STABILITY_HISTOGRAM_ENUMERATION("Stability.MobileSessionShutdownType",
                                      type, MOBILE_SESSION_SHUTDOWN_TYPE_COUNT);
}

// Logs the time which the application was in the background between
// |session_end_time| and now.
void LogApplicationBackgroundedTime(NSDate* session_end_time) {
  NSTimeInterval background_time =
      [[NSDate date] timeIntervalSinceDate:session_end_time];
  UMA_STABILITY_HISTOGRAM_LONG_TIMES(
      "Stability.iOS.UTE.TimeBetweenUTEAndNextLaunch",
      base::TimeDelta::FromSeconds(background_time));
}

// Logs the device |battery_level| as a UTE stability metric.
void LogBatteryCharge(float battery_level) {
  int battery_charge = static_cast<int>(battery_level * 100);
  UMA_STABILITY_HISTOGRAM_PERCENTAGE("Stability.iOS.UTE.BatteryCharge",
                                     battery_charge);
}

// Logs the device's |available_storage| as a UTE stability metric.
void LogAvailableStorage(NSInteger available_storage) {
  UMA_STABILITY_HISTOGRAM_CUSTOM_COUNTS("Stability.iOS.UTE.AvailableStorage",
                                        available_storage, 1, 200000, 100);
}

// Logs the OS version change between |os_version| and the current os version.
// Records whether the version is the same, if a minor version change occurred,
// or if a major version change occurred.
void LogOSVersionChange(std::string os_version) {
  base::Version previous_os_version = base::Version(os_version);
  base::Version current_os_version =
      base::Version(base::SysInfo::OperatingSystemVersion());

  VersionComparison difference = VersionComparison::kSameVersion;
  if (previous_os_version.CompareTo(current_os_version) != 0) {
    const std::vector<uint32_t> previous_os_version_components =
        previous_os_version.components();
    const std::vector<uint32_t> current_os_version_components =
        current_os_version.components();
    if (previous_os_version_components.size() > 0 &&
        current_os_version_components.size() > 0 &&
        previous_os_version_components[0] != current_os_version_components[0]) {
      difference = VersionComparison::kMajorVersionChange;
    } else {
      difference = VersionComparison::kMinorVersionChange;
    }
  }

  UMA_STABILITY_HISTOGRAM_ENUMERATION("Stability.iOS.UTE.OSVersion", difference,
                                      VersionComparison::kMaxValue);
}

// Logs wether or not low power mode is enabled.
void LogLowPowerMode(bool low_power_mode_enabled) {
  UMA_STABILITY_HISTOGRAM_BOOLEAN("Stability.iOS.UTE.LowPowerModeEnabled",
                                  low_power_mode_enabled);
}

// Logs the thermal state of the device.
void LogDeviceThermalState(DeviceThermalState thermal_state) {
  UMA_STABILITY_HISTOGRAM_ENUMERATION("Stability.iOS.UTE.DeviceThermalState",
                                      thermal_state,
                                      DeviceThermalState::kMaxValue);
}

// Creates Synthetic Crash Report for Unexplained Termination Event to be
// uploaded by Breakpad.
void CreateSyntheticCrashReportWithBreadcrumbs(
    std::vector<std::string> breadcrumbs) {
  base::FilePath cache_dir_path;
  base::PathService::Get(base::DIR_CACHE, &cache_dir_path);
  NSDictionary* info_dict = NSBundle.mainBundle.infoDictionary;

  base::ThreadPool::PostTask(
      FROM_HERE, {base::MayBlock()},
      base::BindOnce(
          &CreateSyntheticCrashReportForUte,
          cache_dir_path.Append(FILE_PATH_LITERAL("Breakpad")),
          base::SysNSStringToUTF8(info_dict[@"BreakpadProductDisplay"]),
          // Separate product makes throttling on the server easier.
          base::SysNSStringToUTF8([NSString
              stringWithFormat:@"%@_UTE", info_dict[@"BreakpadProduct"]]),
          base::SysNSStringToUTF8(info_dict[@"BreakpadVersion"]),
          base::SysNSStringToUTF8(info_dict[@"BreakpadURL"]), breadcrumbs));
}

}  // namespace

const float kCriticallyLowBatteryLevel = 0.01;

MobileSessionShutdownMetricsProvider::MobileSessionShutdownMetricsProvider(
    metrics::MetricsService* metrics_service)
    : metrics_service_(metrics_service) {
  DCHECK(metrics_service_);
}

MobileSessionShutdownMetricsProvider::~MobileSessionShutdownMetricsProvider() {}

bool MobileSessionShutdownMetricsProvider::HasPreviousSessionData() {
  return true;
}

void MobileSessionShutdownMetricsProvider::ProvidePreviousSessionData(
    metrics::ChromeUserMetricsExtension* uma_proto) {
  MobileSessionShutdownType shutdown_type = GetLastShutdownType();
  LogShutdownType(shutdown_type);

  // If app was upgraded since the last session, even if the previous session
  // ended in an unclean shutdown (crash, may or may not be UTE), this should
  // *not* be logged into one of the Foreground* or Background* states of
  // MobileSessionShutdownType. The crash is really from the pre-upgraded
  // version of app. Logging it now will incorrectly inflate the current
  // version's crash count with a crash that happened in a previous version of
  // the app.
  //
  // Not counting first run after upgrade does *not* bias the distribution of
  // the 4 Foreground* termination states because the reason of a crash would
  // not be affected by an imminent upgrade of Chrome app. Thus, the ratio of
  // Foreground shutdowns w/ crash log vs. w/o crash log is expected to be the
  // same regardless of whether First Launch after Upgrade is considered or not.
  if (shutdown_type == FIRST_LAUNCH_AFTER_UPGRADE) {
    return;
  }

  // Do not log UTE metrics if the application terminated cleanly.
  if (shutdown_type == SHUTDOWN_IN_BACKGROUND) {
    return;
  }

  PreviousSessionInfo* session_info = [PreviousSessionInfo sharedInstance];
  // Log metrics to improve categorization of crashes.
  LogApplicationBackgroundedTime(session_info.sessionEndTime);

  if (shutdown_type == SHUTDOWN_IN_FOREGROUND_NO_CRASH_LOG_NO_MEMORY_WARNING ||
      shutdown_type ==
          SHUTDOWN_IN_FOREGROUND_NO_CRASH_LOG_WITH_MEMORY_WARNING) {
    // Log UTE metrics only if the crash was classified as a UTE.

    if (session_info.deviceBatteryState == DeviceBatteryState::kUnplugged) {
      LogBatteryCharge(session_info.deviceBatteryLevel);
    }
    if (session_info.availableDeviceStorage >= 0) {
      LogAvailableStorage(session_info.availableDeviceStorage);
    }
    if (session_info.OSVersion) {
      LogOSVersionChange(base::SysNSStringToUTF8(session_info.OSVersion));
    }
    LogLowPowerMode(session_info.deviceWasInLowPowerMode);
    LogDeviceThermalState(session_info.deviceThermalState);

    UMA_STABILITY_HISTOGRAM_BOOLEAN(
        "Stability.iOS.UTE.OSRestartedAfterPreviousSession",
        session_info.OSRestartedAfterPreviousSession);

    bool possible_explanation =
        // Log any of the following cases as a possible explanation for the
        // crash:
        // - device restarted when Chrome was in the foreground (OS was updated,
        // battery died, or iPhone X or newer was powered off)
        (session_info.OSRestartedAfterPreviousSession) ||
        // - storage was critically low
        (session_info.availableDeviceStorage >= 0 &&
         session_info.availableDeviceStorage <= kCriticallyLowDeviceStorage) ||
        // - device in abnormal thermal state
        session_info.deviceThermalState == DeviceThermalState::kCritical ||
        session_info.deviceThermalState == DeviceThermalState::kSerious;
    UMA_STABILITY_HISTOGRAM_BOOLEAN("Stability.iOS.UTE.HasPossibleExplanation",
                                    possible_explanation);

    UMA_STABILITY_HISTOGRAM_ENUMERATION(
        "Stability.iOS.UTE.MobileSessionOOMShutdownHint",
        GetMobileSessionOomShutdownHint(possible_explanation),
        MobileSessionOomShutdownHint::kMaxValue);

    UMA_STABILITY_HISTOGRAM_ENUMERATION(
        "Stability.iOS.UTE.MobileSessionAppState",
        GetMobileSessionAppState(possible_explanation),
        MobileSessionAppState::kMaxValue);

    UMA_STABILITY_HISTOGRAM_ENUMERATION(
        "Stability.iOS.UTE.MobileSessionAppWillTerminateWasReceived",
        GetMobileSessionAppWillTerminateReceived(possible_explanation),
        MobileSessionAppWillTerminateReceived::kMaxValue);

    if (!possible_explanation && EnableSyntheticCrashReportsForUte() &&
        GetApplicationContext()->GetLocalState()->GetBoolean(
            metrics::prefs::kMetricsReportingEnabled)) {
      // UTEs are so common that there will be a little or no value from
      // generating crash reports for XTEs.

      GetApplicationContext()
          ->GetBreadcrumbPersistentStorageManager()
          ->GetStoredEvents(
              base::BindOnce(CreateSyntheticCrashReportWithBreadcrumbs));
    }
  }
  [session_info resetSessionRestorationFlag];
}

MobileSessionShutdownType
MobileSessionShutdownMetricsProvider::GetLastShutdownType() {
  if (IsFirstLaunchAfterUpgrade()) {
    return FIRST_LAUNCH_AFTER_UPGRADE;
  }

  // If the last app lifetime did not end with a crash, then log it as a normal
  // shutdown while in the background.
  if (metrics_service_->WasLastShutdownClean()) {
    return SHUTDOWN_IN_BACKGROUND;
  }

  if (HasCrashLogs()) {
    // The cause of the crash is known.
    if (ReceivedMemoryWarningBeforeLastShutdown()) {
      return SHUTDOWN_IN_FOREGROUND_WITH_CRASH_LOG_WITH_MEMORY_WARNING;
    }
    return SHUTDOWN_IN_FOREGROUND_WITH_CRASH_LOG_NO_MEMORY_WARNING;
  }

  // The cause of the crash is not known. Check the common causes in order of
  // severity and likeliness to have caused the crash.
  if (LastSessionEndedFrozen()) {
    return SHUTDOWN_IN_FOREGROUND_WITH_MAIN_THREAD_FROZEN;
  }
  if (ReceivedMemoryWarningBeforeLastShutdown()) {
    return SHUTDOWN_IN_FOREGROUND_NO_CRASH_LOG_WITH_MEMORY_WARNING;
  }
  // There is no known cause.
  return SHUTDOWN_IN_FOREGROUND_NO_CRASH_LOG_NO_MEMORY_WARNING;
}

bool MobileSessionShutdownMetricsProvider::IsFirstLaunchAfterUpgrade() {
  return [[PreviousSessionInfo sharedInstance] isFirstSessionAfterUpgrade];
}

bool MobileSessionShutdownMetricsProvider::HasCrashLogs() {
  return breakpad_helper::HasReportToUpload();
}

bool MobileSessionShutdownMetricsProvider::LastSessionEndedFrozen() {
  return [MainThreadFreezeDetector sharedInstance].lastSessionEndedFrozen;
}

bool MobileSessionShutdownMetricsProvider::
    ReceivedMemoryWarningBeforeLastShutdown() {
  return [[PreviousSessionInfo sharedInstance]
      didSeeMemoryWarningShortlyBeforeTerminating];
}
