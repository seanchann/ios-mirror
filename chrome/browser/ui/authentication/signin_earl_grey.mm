// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/authentication/signin_earl_grey.h"

#import "base/test/ios/wait_util.h"
#import "ios/chrome/browser/ui/authentication/signin_earl_grey_app_interface.h"
#import "ios/public/provider/chrome/browser/signin/fake_chrome_identity.h"
#import "ios/testing/earl_grey/earl_grey_test.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@implementation SigninEarlGreyImpl

- (FakeChromeIdentity*)fakeIdentity1 {
  return [SigninEarlGreyAppInterface fakeIdentity1];
}

- (FakeChromeIdentity*)fakeIdentity2 {
  return [SigninEarlGreyAppInterface fakeIdentity2];
}

- (FakeChromeIdentity*)fakeManagedIdentity {
  return [SigninEarlGreyAppInterface fakeManagedIdentity];
}

- (void)addFakeIdentity:(FakeChromeIdentity*)fakeIdentity {
  [SigninEarlGreyAppInterface addFakeIdentity:fakeIdentity];
}

- (void)forgetFakeIdentity:(FakeChromeIdentity*)fakeIdentity {
  [SigninEarlGreyAppInterface forgetFakeIdentity:fakeIdentity];
}

- (void)checkSignedInWithFakeIdentity:(FakeChromeIdentity*)fakeIdentity {
  BOOL fakeIdentityIsNonNil = fakeIdentity != nil;
  EG_TEST_HELPER_ASSERT_TRUE(fakeIdentityIsNonNil, @"Need to give an identity");

  // Required to avoid any problem since the following test is not dependant
  // to UI, and the previous action has to be totally finished before going
  // through the assert.
  GREYAssert(base::test::ios::WaitUntilConditionOrTimeout(
                 base::test::ios::kWaitForActionTimeout,
                 ^bool {
                   NSString* primaryAccountGaiaID =
                       [SigninEarlGreyAppInterface primaryAccountGaiaID];
                   return primaryAccountGaiaID.length > 0;
                 }),
             @"Sign in did not complete.");
  GREYWaitForAppToIdle(@"App failed to idle");

  NSString* primaryAccountGaiaID =
      [SigninEarlGreyAppInterface primaryAccountGaiaID];

  NSString* errorStr = [NSString
      stringWithFormat:@"Unexpected Gaia ID of the signed in user [expected = "
                       @"\"%@\", actual = \"%@\"]",
                       fakeIdentity.gaiaID, primaryAccountGaiaID];
  EG_TEST_HELPER_ASSERT_TRUE(
      [fakeIdentity.gaiaID isEqualToString:primaryAccountGaiaID], errorStr);
}

- (void)checkSignedOut {
  // Required to avoid any problem since the following test is not dependant to
  // UI, and the previous action has to be totally finished before going through
  // the assert.
  GREYWaitForAppToIdle(@"App failed to idle");

  EG_TEST_HELPER_ASSERT_TRUE([SigninEarlGreyAppInterface isSignedOut],
                             @"Unexpected signed in user");
}

- (void)waitForMatcher:(id<GREYMatcher>)matcher {
  ConditionBlock condition = ^{
    NSError* error = nil;
    [[EarlGrey selectElementWithMatcher:matcher] assertWithMatcher:grey_notNil()
                                                             error:&error];
    return error == nil;
  };
  GREYAssert(base::test::ios::WaitUntilConditionOrTimeout(
                 base::test::ios::kWaitForUIElementTimeout, condition),
             @"Waiting for matcher %@ failed.", matcher);
}

@end