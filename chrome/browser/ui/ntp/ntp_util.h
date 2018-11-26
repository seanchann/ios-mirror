// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_NTP_NTP_UTIL_H_
#define IOS_CHROME_BROWSER_UI_NTP_NTP_UTIL_H_

#import "ios/web/public/web_state/web_state.h"

// Returns whether the |url| is currently a NewTabPage url.
bool IsURLNewTabPage(const GURL& url);

// Returns whether the |web_state| visible URL is currently a NewTabPage url.
bool IsVisibleURLNewTabPage(web::WebState* web_state);

#endif  // IOS_CHROME_BROWSER_UI_NTP_NTP_UTIL_H_
