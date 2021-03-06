// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/authentication/signin/signin_completion_info.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@implementation SigninCompletionInfo {
  GURL _completionURL;
}

+ (instancetype)signinCompletionInfoWithIdentity:(ChromeIdentity*)identity {
  return [[SigninCompletionInfo alloc]
            initWithIdentity:identity
      signinCompletionAction:SigninCompletionActionNone];
}

- (instancetype)initWithIdentity:(ChromeIdentity*)identity
          signinCompletionAction:
              (SigninCompletionAction)signinCompletionAction {
  self = [super init];
  if (self) {
    _identity = identity;
    _signinCompletionAction = signinCompletionAction;
  }
  return self;
}

- (const GURL&)completionURL {
  return _completionURL;
}

- (void)setCompletionURL:(const GURL&)completionURL {
  if (_completionURL == completionURL)
    return;
  DCHECK(completionURL.is_valid());
  DCHECK(_signinCompletionAction == SigninCompletionActionOpenCompletionURL);
  _completionURL = completionURL;
}

@end
