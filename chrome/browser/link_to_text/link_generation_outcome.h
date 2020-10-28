// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_LINK_TO_TEXT_LINK_GENERATION_OUTCOME_H_
#define IOS_CHROME_BROWSER_LINK_TO_TEXT_LINK_GENERATION_OUTCOME_H_

// Enum representing the set of possible link generation outcomes from the
// text-fragments-polyfill library. To be kept in sync with the
// |GenerateFragmentStatus| enum in that library.
enum class LinkGenerationOutcome {
  kSuccess = 0,
  kInvalidSelection = 1,
  kAmbiguous = 2,
  kMaxValue = kAmbiguous
};

#endif  // IOS_CHROME_BROWSER_LINK_TO_TEXT_LINK_GENERATION_OUTCOME_H_