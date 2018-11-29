// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_CRASH_REPORT_MAIN_THREAD_FREEZE_DETECTOR_H_
#define IOS_CHROME_BROWSER_CRASH_REPORT_MAIN_THREAD_FREEZE_DETECTOR_H_

#import <Foundation/Foundation.h>

// Detects freezes of the main thread.
// This class that the main thread runloop is run at least every
// |TimeoutForMainThreadFreezeDetection|. If this is not the case, a
// NSUserDefault flag is raised and a crash report is generated capturing the
// stack of the main frame at that time.
// Only one report is generated for each foreground/background session.
// This class uses NSUserDefault as persistent storage as profile may not be
// available (both because initialization is too early and because main thread
// is often frozen at the point the class is used).
@interface MainThreadFreezeDetector : NSObject
// Returns the sharedInstance of the watchdog.
// Note that on first access, the instance is immediately started without
// checking the new preferences values. This is necessary to detect freezes
// during applicationDidFinishLaunching.
+ (instancetype)sharedInstance;
// The result of the previous session. If this is true, the last time the
// application was terminated, main thread was not responding.
@property(nonatomic, readonly) BOOL lastSessionEndedFrozen;
// Starts the watchdog of the main thread.
- (void)start;
// Stops the watchdog of the main thread.
- (void)stop;
// Enables or disables the main thread watchdog. This will also start or stop
// the monitoring of the main thread.
- (void)setEnabled:(BOOL)enabled;
@end

#endif  // IOS_CHROME_BROWSER_CRASH_REPORT_MAIN_THREAD_FREEZE_DETECTOR_H_
