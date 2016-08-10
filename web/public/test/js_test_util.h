// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_WEB_PUBLIC_TEST_JS_TEST_UTIL_H_
#define IOS_WEB_PUBLIC_TEST_JS_TEST_UTIL_H_

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@class CRWJSInjectionManager;
@class CRWJSInjectionReceiver;

namespace web {

// Evaluates JavaScript on the |manager| and returns the result as a string.
// DEPRECATED. TODO(crbug.com/595761): Remove this API.
NSString* EvaluateJavaScriptAsString(CRWJSInjectionManager* manager,
                                     NSString* script);

// Executes JavaScript on the |manager| and returns the result as an id.
id ExecuteJavaScript(CRWJSInjectionManager* manager, NSString* script);

// Evaluates JavaScript on the |receiver| and returns the result as a string.
// DEPRECATED. TODO(crbug.com/595761): Remove this API.
NSString* EvaluateJavaScriptAsString(CRWJSInjectionReceiver* receiver,
                                     NSString* script);

// Executes JavaScript on the |receiver| and returns the result as an id.
id ExecuteJavaScript(CRWJSInjectionReceiver* receiver, NSString* script);

// Evaluates JavaScript on |web_view| and returns the result as an id.
// DEPRECATED. TODO(crbug.com/595761): Remove this API, which has inconsistent
// name (evaluate instead of execute which is used in Chromium).
id EvaluateJavaScript(WKWebView* web_view, NSString* script);

// Executes JavaScript on |web_view| and returns the result as an id.
id ExecuteJavaScript(WKWebView* web_view, NSString* script);

}  // namespace web

#endif  // IOS_WEB_PUBLIC_TEST_JS_TEST_UTIL_H_
