// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/web/webui/mojo_facade.h"

#include <memory>

#include "base/bind.h"
#include "base/strings/string_number_conversions.h"
#include "base/strings/sys_string_conversions.h"
#import "base/test/ios/wait_util.h"
#include "ios/web/public/test/web_test.h"
#import "ios/web/public/web_state/js/crw_js_injection_evaluator.h"
#include "ios/web/public/web_state/web_state_interface_provider.h"
#include "ios/web/test/mojo_test.mojom.h"
#include "ios/web/web_state/web_state_impl.h"
#include "mojo/public/cpp/bindings/binding_set.h"
#import "testing/gtest_mac.h"
#import "third_party/ocmock/OCMock/OCMock.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace web {

namespace {

// Serializes the given |object| to JSON string.
std::string GetJson(id object) {
  NSData* json_as_data =
      [NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
  NSString* json_as_string =
      [[NSString alloc] initWithData:json_as_data
                            encoding:NSUTF8StringEncoding];
  return base::SysNSStringToUTF8(json_as_string);
}

// Deserializes the given |json| to an object.
id GetObject(const std::string& json) {
  NSData* json_as_data =
      [base::SysUTF8ToNSString(json) dataUsingEncoding:NSUTF8StringEncoding];
  return [NSJSONSerialization JSONObjectWithData:json_as_data
                                         options:0
                                           error:nil];
}

}  // namespace

// A test fixture to test MojoFacade class.
class MojoFacadeTest : public WebTest {
 protected:
  MojoFacadeTest() {
    interface_provider_ = std::make_unique<WebStateInterfaceProvider>();
    interface_provider_->registry()->AddInterface(base::Bind(
        &MojoFacadeTest::BindTestUIHandlerMojoRequest, base::Unretained(this)));
    evaluator_ =
        [OCMockObject mockForProtocol:@protocol(CRWJSInjectionEvaluator)];
    facade_ = std::make_unique<MojoFacade>(
        interface_provider_.get(),
        static_cast<id<CRWJSInjectionEvaluator>>(evaluator_));
  }

  OCMockObject* evaluator() { return evaluator_; }
  MojoFacade* facade() { return facade_.get(); }

  void CreateMessagePipe(uint32_t* handle0, uint32_t* handle1) {
    NSDictionary* create = @{
      @"name" : @"Mojo.createMessagePipe",
      @"args" : @{},
    };
    std::string response_as_string =
        facade()->HandleMojoMessage(GetJson(create));

    // Verify handles.
    ASSERT_FALSE(response_as_string.empty());
    NSDictionary* response_as_dict = GetObject(response_as_string);
    ASSERT_TRUE([response_as_dict isKindOfClass:[NSDictionary class]]);
    ASSERT_EQ(MOJO_RESULT_OK, [response_as_dict[@"result"] unsignedIntValue]);
    *handle0 = [response_as_dict[@"handle0"] unsignedIntValue];
    *handle1 = [response_as_dict[@"handle1"] unsignedIntValue];
  }

  void CloseHandle(uint32_t handle) {
    NSDictionary* close = @{
      @"name" : @"MojoHandle.close",
      @"args" : @{
        @"handle" : @(handle),
      },
    };
    std::string result = facade()->HandleMojoMessage(GetJson(close));
    EXPECT_TRUE(result.empty());
  }

 private:
  void BindTestUIHandlerMojoRequest(TestUIHandlerMojoRequest request) {}

  std::unique_ptr<WebStateInterfaceProvider> interface_provider_;
  OCMockObject* evaluator_;
  std::unique_ptr<MojoFacade> facade_;
};

// Tests binding an interface.
TEST_F(MojoFacadeTest, BindInterface) {
  uint32_t handle0 = 0;
  uint32_t handle1 = 0;
  CreateMessagePipe(&handle0, &handle1);

  // Pass handle0 as interface request.
  NSDictionary* connect = @{
    @"name" : @"Mojo.bindInterface",
    @"args" : @{
      @"interfaceName" : @".TestUIHandlerMojo",
      @"requestHandle" : @(handle0),
    },
  };

  std::string handle_as_string = facade()->HandleMojoMessage(GetJson(connect));
  EXPECT_TRUE(handle_as_string.empty());

  CloseHandle(handle1);
}

// Tests creating a message pipe.
TEST_F(MojoFacadeTest, CreateMessagePipe) {
  uint32_t handle0, handle1;
  CreateMessagePipe(&handle0, &handle1);

  CloseHandle(handle0);
  CloseHandle(handle1);
}

// Tests watching the pipe.
TEST_F(MojoFacadeTest, Watch) {
  uint32_t handle0, handle1;
  CreateMessagePipe(&handle0, &handle1);

  // Start watching one end of the pipe.
  int callback_id = 99;
  NSDictionary* watch = @{
    @"name" : @"MojoHandle.watch",
    @"args" : @{
      @"handle" : @(handle0),
      @"signals" : @(MOJO_HANDLE_SIGNAL_READABLE),
      @"callbackId" : @(callback_id),
    },
  };
  std::string watch_id_as_string = facade()->HandleMojoMessage(GetJson(watch));
  EXPECT_FALSE(watch_id_as_string.empty());
  int watch_id = 0;
  EXPECT_TRUE(base::StringToInt(watch_id_as_string, &watch_id));

  // Start waiting for the watch callback.
  __block bool callback_received = false;
  NSString* expected_script =
      [NSString stringWithFormat:
                    @"Mojo.internal.watchCallbacksHolder.callCallback(%d, %d)",
                    callback_id, MOJO_RESULT_OK];
  [[[evaluator() expect] andDo:^(NSInvocation*) {
    callback_received = true;

    // Cancel the watch immediately to ensure there are no additional
    // notifications.
    NSDictionary* cancel_watch = @{
      @"name" : @"MojoWatcher.cancel",
      @"args" : @{
        @"watchId" : @(watch_id),
      },
    };
    std::string result_as_string =
        facade()->HandleMojoMessage(GetJson(cancel_watch));
    EXPECT_TRUE(result_as_string.empty());
  }] executeJavaScript:expected_script completionHandler:nil];

  // Write to the other end of the pipe.
  NSDictionary* write = @{
    @"name" : @"MojoHandle.writeMessage",
    @"args" :
        @{@"handle" : @(handle1), @"handles" : @[], @"buffer" : @{@"0" : @0}},
  };
  std::string result_as_string = facade()->HandleMojoMessage(GetJson(write));
  EXPECT_FALSE(result_as_string.empty());
  int result = 0;
  EXPECT_TRUE(base::StringToInt(result_as_string, &result));
  EXPECT_EQ(MOJO_RESULT_OK, static_cast<MojoResult>(result));

  base::test::ios::WaitUntilCondition(
      ^{
        return callback_received;
      },
      true, base::TimeDelta());

  CloseHandle(handle0);
  CloseHandle(handle1);
}

// Tests reading the message from the pipe.
TEST_F(MojoFacadeTest, ReadWrite) {
  uint32_t handle0, handle1;
  CreateMessagePipe(&handle0, &handle1);

  // Write to the other end of the pipe.
  NSDictionary* write = @{
    @"name" : @"MojoHandle.writeMessage",
    @"args" : @{
      @"handle" : @(handle1),
      @"handles" : @[],
      @"buffer" : @{@"0" : @9, @"1" : @2, @"2" : @2008}
    },
  };
  std::string result_as_string = facade()->HandleMojoMessage(GetJson(write));
  EXPECT_FALSE(result_as_string.empty());
  int result = 0;
  EXPECT_TRUE(base::StringToInt(result_as_string, &result));
  EXPECT_EQ(MOJO_RESULT_OK, static_cast<MojoResult>(result));

  // Read the message from the pipe.
  NSDictionary* read = @{
    @"name" : @"MojoHandle.readMessage",
    @"args" : @{
      @"handle" : @(handle0),
    },
  };
  NSDictionary* message = GetObject(facade()->HandleMojoMessage(GetJson(read)));
  EXPECT_TRUE([message isKindOfClass:[NSDictionary class]]);
  EXPECT_TRUE(message);
  NSArray* expected_message = @[ @9, @2, @216 ];  // 2008 does not fit 8-bit.
  EXPECT_NSEQ(expected_message, message[@"buffer"]);
  EXPECT_FALSE([message[@"handles"] count]);
  EXPECT_EQ(MOJO_RESULT_OK, [message[@"result"] unsignedIntValue]);

  CloseHandle(handle0);
  CloseHandle(handle1);
}

}  // namespace web
