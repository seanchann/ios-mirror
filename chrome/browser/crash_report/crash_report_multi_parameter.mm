// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/crash_report/crash_report_multi_parameter.h"

#include <memory>

#include "base/check.h"
#include "base/json/json_writer.h"
#include "base/notreached.h"
#include "base/strings/sys_string_conversions.h"
#include "base/values.h"
#import "components/previous_session_info/previous_session_info.h"
#import "ios/chrome/browser/crash_report/crash_helper.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
// Maximum size of a breakpad parameter. The length of the dictionary serialized
// into JSON cannot exceed this length. See declaration in (BreakPad.h) for
// details.
const int kMaximumBreakpadValueSize = 255;
}

@implementation CrashReportMultiParameter {
  crash_reporter::CrashKeyString<256>* _key;
  std::unique_ptr<base::DictionaryValue> _dictionary;
}

- (instancetype)initWithKey:(crash_reporter::CrashKeyString<256>&)key {
  if ((self = [super init])) {
    _dictionary.reset(new base::DictionaryValue());
    _key = &key;
  }
  return self;
}

- (void)removeValue:(NSString*)key {
  _dictionary->Remove(base::SysNSStringToUTF8(key).c_str(), nullptr);
  [self updateCrashReport];
}

- (void)setValue:(NSString*)key withValue:(int)value {
  _dictionary->SetInteger(base::SysNSStringToUTF8(key).c_str(), value);
  [self updateCrashReport];
}

- (void)incrementValue:(NSString*)key {
  int value;
  std::string utf8_string = base::SysNSStringToUTF8(key);
  if (_dictionary->GetInteger(utf8_string.c_str(), &value)) {
    _dictionary->SetInteger(utf8_string.c_str(), value + 1);
  } else {
    _dictionary->SetInteger(utf8_string.c_str(), 1);
  }
  [self updateCrashReport];
}

- (void)decrementValue:(NSString*)key {
  int value;
  std::string utf8_string = base::SysNSStringToUTF8(key);
  if (_dictionary->GetInteger(utf8_string.c_str(), &value)) {
    if (value <= 1) {
      _dictionary->Remove(utf8_string.c_str(), nullptr);
    } else {
      _dictionary->SetInteger(utf8_string.c_str(), value - 1);
    }
    [self updateCrashReport];
  }
}

- (void)updateCrashReport {
  std::string stateAsJson;
  base::JSONWriter::Write(*_dictionary.get(), &stateAsJson);
  if (stateAsJson.length() > kMaximumBreakpadValueSize) {
    NOTREACHED();
    return;
  }
  _key->Set(stateAsJson);
}

@end
