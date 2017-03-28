// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_WEB_VIEW_PUBLIC_CWV_WEB_VIEW_CONFIGURATION_H_
#define IOS_WEB_VIEW_PUBLIC_CWV_WEB_VIEW_CONFIGURATION_H_

#import <Foundation/Foundation.h>

// TODO(crbug.com/704946): Make framework style include work everywhere and
// remove this #if.
#if defined(CWV_IMPLEMENTATION)
#include "ios/web_view/public/cwv_export.h"
#else
#include <ChromeWebView/cwv_export.h>
#endif

@class CWVUserContentController;
@class CWVWebsiteDataStore;

// Configuration used for creation of a CWVWebView.
CWV_EXPORT
@interface CWVWebViewConfiguration : NSObject<NSCopying>

// Configuration with persistent data store which stores all data on disk.
+ (instancetype)defaultConfiguration;

// Configuration with ephemeral data store that neven stores data on disk.
+ (instancetype)incognitoConfiguration;

- (instancetype)init NS_UNAVAILABLE;

// The user content controller to associate with web views created using this
// configuration.
@property(nonatomic, readonly) CWVUserContentController* userContentController;

// YES if it is a configuration with persistent data store which stores all data
// on disk.
@property(nonatomic, readonly, getter=isPersistent) BOOL persistent;

@end

#endif  // IOS_WEB_VIEW_PUBLIC_CWV_WEB_VIEW_CONFIGURATION_H_
