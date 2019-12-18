// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "ios/chrome/browser/overlays/overlay_callback_manager_impl.h"

#include "base/bind.h"
#include "ios/chrome/browser/overlays/public/overlay_response.h"
#include "ios/chrome/browser/overlays/test/fake_overlay_user_data.h"
#include "testing/platform_test.h"

namespace {
// Fake dispatch response info types.
class FirstResponseInfo : public OverlayUserData<FirstResponseInfo> {
 private:
  OVERLAY_USER_DATA_SETUP(FirstResponseInfo);
};
OVERLAY_USER_DATA_SETUP_IMPL(FirstResponseInfo);
class SecondResponseInfo : public OverlayUserData<SecondResponseInfo> {
 private:
  OVERLAY_USER_DATA_SETUP(SecondResponseInfo);
};
OVERLAY_USER_DATA_SETUP_IMPL(SecondResponseInfo);
}  // namespace

using OverlayCallbackManagerImplTest = PlatformTest;

// Tests that OverlayCallbackManagerImpl can add and execute completion
// callbacks.
TEST_F(OverlayCallbackManagerImplTest, CompletionCallbacks) {
  OverlayCallbackManagerImpl manager;
  void* kResponseData = &kResponseData;
  // Add two completion callbacks that increment |callback_execution_count|.
  __block size_t callback_execution_count = 0;
  void (^callback_block)(OverlayResponse* response) =
      ^(OverlayResponse* response) {
        if (!response)
          return;
        if (response->GetInfo<FakeOverlayUserData>()->value() != kResponseData)
          return;
        ++callback_execution_count;
      };
  manager.AddCompletionCallback(
      base::BindOnce(base::RetainBlock(callback_block)));
  manager.AddCompletionCallback(
      base::BindOnce(base::RetainBlock(callback_block)));

  // Add a response to the queue with a fake info using kResponseData.
  manager.SetCompletionResponse(
      OverlayResponse::CreateWithInfo<FakeOverlayUserData>(kResponseData));
  OverlayResponse* response = manager.GetCompletionResponse();
  ASSERT_TRUE(response);
  EXPECT_EQ(kResponseData, response->GetInfo<FakeOverlayUserData>()->value());

  // Execute the callbacks and verify that both are called once.
  ASSERT_EQ(0U, callback_execution_count);
  manager.ExecuteCompletionCallbacks();
  EXPECT_EQ(2U, callback_execution_count);
}

// Tests that OverlayCallbackManagerImpl can add and execute dispatch
// callbacks, and that the callbacks are only executed for dispatched responses
// of the appropriate type.
TEST_F(OverlayCallbackManagerImplTest, DispatchCallbacks) {
  OverlayCallbackManagerImpl manager;
  // Add two dispatch callbacks for each fake response info type.
  __block size_t first_execution_count = 0;
  void (^first_callback_block)(OverlayResponse* response) =
      ^(OverlayResponse* response) {
        ++first_execution_count;
      };
  __block size_t second_execution_count = 0;
  void (^second_callback_block)(OverlayResponse* response) =
      ^(OverlayResponse* response) {
        ++second_execution_count;
      };
  manager.AddDispatchCallback<FirstResponseInfo>(
      base::BindRepeating(base::RetainBlock(first_callback_block)));
  manager.AddDispatchCallback<SecondResponseInfo>(
      base::BindRepeating(base::RetainBlock(second_callback_block)));
  ASSERT_EQ(0U, first_execution_count);
  ASSERT_EQ(0U, second_execution_count);

  // Send two response with the first response info.
  manager.DispatchResponse(
      OverlayResponse::CreateWithInfo<FirstResponseInfo>());
  manager.DispatchResponse(
      OverlayResponse::CreateWithInfo<FirstResponseInfo>());

  EXPECT_EQ(2U, first_execution_count);
  EXPECT_EQ(0U, second_execution_count);

  // Send two response with the second response info.
  manager.DispatchResponse(
      OverlayResponse::CreateWithInfo<SecondResponseInfo>());
  manager.DispatchResponse(
      OverlayResponse::CreateWithInfo<SecondResponseInfo>());

  EXPECT_EQ(2U, first_execution_count);
  EXPECT_EQ(2U, second_execution_count);
}
