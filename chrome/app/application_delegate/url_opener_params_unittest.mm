// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/app/application_delegate/url_opener_params.h"

#import <Foundation/Foundation.h>

#include "testing/gtest_mac.h"
#include "testing/platform_test.h"
#import "third_party/ocmock/OCMock/OCMock.h"
#include "third_party/ocmock/gtest_support.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

typedef PlatformTest URLOpenerParamsTest;

// Simple test for initWithUIOpenURLContext:.
TEST_F(URLOpenerParamsTest, initWithUIOpenURLContext) {
  if (@available(iOS 13, *)) {
    NSURL* url = [NSURL URLWithString:@"https://url.test"];
    NSString* source = @"source";
    id open_url_context = [OCMockObject mockForClass:[UIOpenURLContext class]];
    id open_url_context_options =
        [OCMockObject mockForClass:[UISceneOpenURLOptions class]];
    OCMStub([open_url_context_options sourceApplication]).andReturn(source);
    OCMStub([open_url_context URL]).andReturn(url);
    [(UIOpenURLContext*)[[open_url_context stub]
        andReturn:open_url_context_options] options];

    URLOpenerParams* params =
        [[URLOpenerParams alloc] initWithUIOpenURLContext:open_url_context];

    EXPECT_NSEQ(url, params.URL);
    EXPECT_NSEQ(source, params.sourceApplication);
  }
}

// Simple test for initWithOpenURL:options:.
TEST_F(URLOpenerParamsTest, initWithOpenURLOptions) {
  NSURL* url = [NSURL URLWithString:@"https://url.test"];
  NSString* source = @"source";
  NSDictionary* options =
      @{UIApplicationOpenURLOptionsSourceApplicationKey : source};
  URLOpenerParams* params = [[URLOpenerParams alloc] initWithOpenURL:url
                                                             options:options];
  EXPECT_NSEQ(url, params.URL);
  EXPECT_NSEQ(source, params.sourceApplication);
}

// Simple test for initWithLaunchOptions:.
TEST_F(URLOpenerParamsTest, initWithLaunchOptions) {
  NSURL* url = [NSURL URLWithString:@"https://url.test"];
  NSString* source = @"source";
  NSDictionary* options = @{
    UIApplicationLaunchOptionsURLKey : url,
    UIApplicationLaunchOptionsSourceApplicationKey : source
  };
  URLOpenerParams* params =
      [[URLOpenerParams alloc] initWithLaunchOptions:options];
  EXPECT_NSEQ(url, params.URL);
  EXPECT_NSEQ(source, params.sourceApplication);
}

// Simple test for toLaunchOptions.
TEST_F(URLOpenerParamsTest, toLaunchOptions) {
  NSURL* url = [NSURL URLWithString:@"https://url.test"];
  NSString* source = @"source";
  URLOpenerParams* params = [[URLOpenerParams alloc] initWithURL:url
                                               sourceApplication:source];
  NSDictionary* launchOptions = [params toLaunchOptions];
  EXPECT_NSEQ(url, launchOptions[UIApplicationLaunchOptionsURLKey]);
  EXPECT_NSEQ(source,
              launchOptions[UIApplicationLaunchOptionsSourceApplicationKey]);
}
