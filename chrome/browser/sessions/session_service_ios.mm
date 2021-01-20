// Copyright 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/sessions/session_service_ios.h"

#import <UIKit/UIKit.h>

#include "base/bind.h"
#include "base/callback_helpers.h"
#include "base/files/file_path.h"
#include "base/format_macros.h"
#include "base/location.h"
#include "base/logging.h"
#import "base/mac/foundation_util.h"
#include "base/memory/ref_counted.h"
#include "base/metrics/histogram_functions.h"
#include "base/metrics/histogram_macros.h"
#include "base/sequenced_task_runner.h"
#include "base/strings/sys_string_conversions.h"
#include "base/task/post_task.h"
#include "base/task/thread_pool.h"
#include "base/threading/scoped_blocking_call.h"
#include "base/time/time.h"
#import "ios/chrome/browser/sessions/session_ios.h"
#import "ios/chrome/browser/sessions/session_ios_factory.h"
#import "ios/chrome/browser/sessions/session_window_ios.h"
#import "ios/web/public/session/crw_navigation_item_storage.h"
#import "ios/web/public/session/crw_session_certificate_policy_cache_storage.h"
#import "ios/web/public/session/crw_session_storage.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

// When C++ exceptions are disabled, the C++ library defines |try| and
// |catch| so as to allow exception-expecting C++ code to build properly when
// language support for exceptions is not present.  These macros interfere
// with the use of |@try| and |@catch| in Objective-C files such as this one.
// Undefine these macros here, after everything has been #included, since
// there will be no C++ uses and only Objective-C uses from this point on.
#undef try
#undef catch

namespace {
const NSTimeInterval kSaveDelay = 2.5;     // Value taken from Desktop Chrome.
NSString* const kRootObjectKey = @"root";  // Key for the root object.
NSString* const kSessionDirectory =
    @"Sessions";  // The directory name inside BrowserState directory which
                  // contain all sessions directories.
NSString* const kSessionFileName =
    @"session.plist";  // The session file name on disk.
}

@implementation NSKeyedUnarchiver (CrLegacySessionCompatibility)

// When adding a new compatibility alias here, create a new crbug to track its
// removal and mark it with a release at least one year after the introduction
// of the alias.
- (void)cr_registerCompatibilityAliases {
}

@end

@implementation SessionServiceIOS {
  // The SequencedTaskRunner on which File IO operations are performed.
  scoped_refptr<base::SequencedTaskRunner> _taskRunner;

  // Maps session path to the pending session factories for the delayed save
  // behaviour. SessionIOSFactory pointers are weak.
  NSMapTable<NSString*, SessionIOSFactory*>* _pendingSessions;
}

#pragma mark - NSObject overrides

- (instancetype)init {
  scoped_refptr<base::SequencedTaskRunner> taskRunner =
      base::ThreadPool::CreateSequencedTaskRunner(
          {base::MayBlock(), base::TaskPriority::BEST_EFFORT,
           base::TaskShutdownBehavior::BLOCK_SHUTDOWN});
  return [self initWithTaskRunner:taskRunner];
}

#pragma mark - Public interface

+ (SessionServiceIOS*)sharedService {
  static SessionServiceIOS* singleton = nil;
  if (!singleton) {
    singleton = [[[self class] alloc] init];
  }
  return singleton;
}

- (instancetype)initWithTaskRunner:
    (const scoped_refptr<base::SequencedTaskRunner>&)taskRunner {
  DCHECK(taskRunner);
  self = [super init];
  if (self) {
    _pendingSessions = [NSMapTable strongToWeakObjectsMapTable];
    _taskRunner = taskRunner;
  }
  return self;
}

- (void)saveSession:(__weak SessionIOSFactory*)factory
          directory:(NSString*)directory
        immediately:(BOOL)immediately {
  NSString* sessionPath = [[self class] sessionPathForDirectory:directory];
  BOOL hadPendingSession = [_pendingSessions objectForKey:sessionPath] != nil;
  [_pendingSessions setObject:factory forKey:sessionPath];
  if (immediately) {
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    [self performSaveToPathInBackground:sessionPath];
  } else if (!hadPendingSession) {
    // If there wasn't previously a delayed save pending for |sessionPath|,
    // enqueue one now.
    [self performSelector:@selector(performSaveToPathInBackground:)
               withObject:sessionPath
               afterDelay:kSaveDelay];
  }
}

- (SessionIOS*)loadSessionFromDirectory:(NSString*)directory {
  NSString* sessionPath = [[self class] sessionPathForDirectory:directory];
  base::TimeTicks start_time = base::TimeTicks::Now();
  SessionIOS* session = [self loadSessionFromPath:sessionPath];
  UmaHistogramTimes("Session.WebStates.ReadFromFileTime",
                    base::TimeTicks::Now() - start_time);
  return session;
}

- (SessionIOS*)loadSessionFromPath:(NSString*)sessionPath {
  NSObject<NSCoding>* rootObject = nil;
  @try {
    NSData* data = [NSData dataWithContentsOfFile:sessionPath];
    if (!data)
      return nil;

    NSError* error = nil;
    NSKeyedUnarchiver* unarchiver =
        [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
    if (!unarchiver || error) {
      DLOG(WARNING) << "Error creating unarchiver, session file: "
                    << base::SysNSStringToUTF8(sessionPath) << ": "
                    << base::SysNSStringToUTF8([error description]);
      return nil;
    }

    unarchiver.requiresSecureCoding = NO;

    // Register compatibility aliases to support legacy saved sessions.
    [unarchiver cr_registerCompatibilityAliases];
    rootObject = [unarchiver decodeObjectForKey:kRootObjectKey];
  } @catch (NSException* exception) {
    NOTREACHED() << "Error loading session file: "
                 << base::SysNSStringToUTF8(sessionPath) << ": "
                 << base::SysNSStringToUTF8([exception reason]);
  }

  if (!rootObject)
    return nil;

  // Support for legacy saved session that contained a single SessionWindowIOS
  // object as the root object (pre-M-59).
  if ([rootObject isKindOfClass:[SessionWindowIOS class]]) {
    return [[SessionIOS alloc] initWithWindows:@[
      base::mac::ObjCCastStrict<SessionWindowIOS>(rootObject)
    ]];
  }

  return base::mac::ObjCCastStrict<SessionIOS>(rootObject);
}

- (void)deleteAllSessionFilesInBrowserStateDirectory:(NSString*)directory
                                          completion:
                                              (base::OnceClosure)callback {
  NSMutableArray<NSString*>* sessionFilesPaths = [[NSMutableArray alloc] init];
  NSString* sessionsDirectoryPath =
      [directory stringByAppendingPathComponent:kSessionDirectory];
  NSArray<NSString*>* allSessionIDs = [[NSFileManager defaultManager]
      contentsOfDirectoryAtPath:sessionsDirectoryPath
                          error:nil];
  for (NSString* sessionID in allSessionIDs) {
    NSString* sessionPath =
        [SessionServiceIOS sessionPathForSessionID:sessionID
                                         directory:directory];
    [sessionFilesPaths addObject:sessionPath];
  }

  // If there were no session ids, then scenes are not supported fall back to
  // the original location
  if (sessionFilesPaths.count == 0)
    [sessionFilesPaths
        addObject:[[self class] sessionPathForDirectory:directory]];

  [self deletePaths:sessionFilesPaths completion:std::move(callback)];
}

- (void)deleteSessions:(NSArray<NSString*>*)sessionIDs
    fromBrowserStateDirectory:(NSString*)directory {
  NSString* sessionsDirectoryPath =
      [directory stringByAppendingPathComponent:kSessionDirectory];
  NSMutableArray<NSString*>* paths =
      [NSMutableArray arrayWithCapacity:sessionIDs.count];
  for (NSString* sessionID : sessionIDs) {
    [paths addObject:[sessionsDirectoryPath
                         stringByAppendingPathComponent:sessionID]];
  }
  [self deletePaths:paths completion:base::DoNothing()];
}

+ (NSString*)sessionPathForDirectory:(NSString*)directory {
  return [directory stringByAppendingPathComponent:kSessionFileName];
}

+ (NSString*)sessionPathForSessionID:(NSString*)sessionID
                           directory:(NSString*)directory {
  if (!sessionID.length)
    return [[self class] sessionPathForDirectory:directory];
  return [NSString pathWithComponents:@[
    directory, kSessionDirectory, sessionID, kSessionFileName
  ]];
}

#pragma mark - Private methods

// Delete files/folders of the given |paths|.
- (void)deletePaths:(NSArray<NSString*>*)paths
         completion:(base::OnceClosure)callback {
  _taskRunner->PostTaskAndReply(
      FROM_HERE, base::BindOnce(^{
        base::ScopedBlockingCall scoped_blocking_call(
            FROM_HERE, base::BlockingType::MAY_BLOCK);
        NSFileManager* fileManager = [NSFileManager defaultManager];
        for (NSString* path : paths) {
          if (![fileManager fileExistsAtPath:path])
            continue;

          NSError* error = nil;
          if (![fileManager removeItemAtPath:path error:&error] || error) {
            CHECK(false) << "Unable to delete path: "
                         << base::SysNSStringToUTF8(path) << ": "
                         << base::SysNSStringToUTF8([error description]);
          }
        }
      }),
      std::move(callback));
}

// Do the work of saving on a background thread.
- (void)performSaveToPathInBackground:(NSString*)sessionPath {
  DCHECK(sessionPath);

  // Serialize to NSData on the main thread to avoid accessing potentially
  // non-threadsafe objects on a background thread.
  SessionIOSFactory* factory = [_pendingSessions objectForKey:sessionPath];
  [_pendingSessions removeObjectForKey:sessionPath];
  SessionIOS* session = [factory sessionForSaving];
  // Because the factory may be called asynchronously after the underlying
  // web state list is destroyed, the session may be nil; if so, do nothing.
  if (!session)
    return;

  @try {
    NSError* error = nil;
    size_t previous_cert_policy_bytes = web::GetCertPolicyBytesEncoded();
    NSData* sessionData = [NSKeyedArchiver archivedDataWithRootObject:session
                                                requiringSecureCoding:NO
                                                                error:&error];
    if (!sessionData || error) {
      DLOG(WARNING) << "Error serializing session for path: "
                    << base::SysNSStringToUTF8(sessionPath) << ": "
                    << base::SysNSStringToUTF8([error description]);
      return;
    }

    base::UmaHistogramCounts100000(
        "Session.WebStates.AllSerializedCertPolicyCachesSize",
        web::GetCertPolicyBytesEncoded() - previous_cert_policy_bytes / 1024);

    base::UmaHistogramCounts100000("Session.WebStates.SerializedSize",
                                   sessionData.length / 1024);

    _taskRunner->PostTask(FROM_HERE, base::BindOnce(^{
                            [self performSaveSessionData:sessionData
                                             sessionPath:sessionPath];
                          }));
  } @catch (NSException* exception) {
    NOTREACHED() << "Error serializing session for path: "
                 << base::SysNSStringToUTF8(sessionPath) << ": "
                 << base::SysNSStringToUTF8([exception description]);
    return;
  }
}

@end

@implementation SessionServiceIOS (SubClassing)

- (void)performSaveSessionData:(NSData*)sessionData
                   sessionPath:(NSString*)sessionPath {
  base::ScopedBlockingCall scoped_blocking_call(
            FROM_HERE, base::BlockingType::MAY_BLOCK);

  NSFileManager* fileManager = [NSFileManager defaultManager];
  NSString* directory = [sessionPath stringByDeletingLastPathComponent];

  NSError* error = nil;
  BOOL isDirectory = NO;
  if (![fileManager fileExistsAtPath:directory isDirectory:&isDirectory]) {
    isDirectory = YES;
    if (![fileManager createDirectoryAtPath:directory
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:&error]) {
      NOTREACHED() << "Error creating destination directory: "
                   << base::SysNSStringToUTF8(directory) << ": "
                   << base::SysNSStringToUTF8([error description]);
      return;
    }
  }

  if (!isDirectory) {
    NOTREACHED() << "Error creating destination directory: "
                 << base::SysNSStringToUTF8(directory) << ": "
                 << "file exists and is not a directory.";
    return;
  }

  NSDataWritingOptions options =
      NSDataWritingAtomic | NSDataWritingFileProtectionComplete;

  base::TimeTicks start_time = base::TimeTicks::Now();
  if (![sessionData writeToFile:sessionPath options:options error:&error]) {
    NOTREACHED() << "Error writing session file: "
                 << base::SysNSStringToUTF8(sessionPath) << ": "
                 << base::SysNSStringToUTF8([error description]);
    return;
  }
  UmaHistogramTimes("Session.WebStates.WriteToFileTime",
                    base::TimeTicks::Now() - start_time);
}

@end
