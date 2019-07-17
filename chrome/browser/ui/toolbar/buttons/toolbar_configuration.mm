// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/toolbar/buttons/toolbar_configuration.h"

#include "base/logging.h"
#import "ios/chrome/browser/ui/content_suggestions/ntp_home_constant.h"
#import "ios/chrome/browser/ui/toolbar/public/toolbar_constants.h"
#include "ios/chrome/browser/ui/util/ui_util.h"
#import "ios/chrome/browser/ui/util/uikit_ui_util.h"
#import "ios/chrome/common/colors/semantic_color_names.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@implementation ToolbarConfiguration

@synthesize style = _style;

- (instancetype)initWithStyle:(ToolbarStyle)style {
  self = [super init];
  if (self) {
    _style = style;
  }
  return self;
}

- (UIColor*)NTPBackgroundColor {
  switch (self.style) {
    case NORMAL:
      return ntp_home::kNTPBackgroundColor();
    case INCOGNITO:
      return [UIColor colorWithWhite:kNTPBackgroundColorBrightnessIncognito
                               alpha:1.0];
  }
}

- (UIColor*)backgroundColor {
  switch (self.style) {
    case NORMAL:
      return [UIColor colorNamed:kBackgroundColor];
    case INCOGNITO:
      return UIColorFromRGB(kIncognitoToolbarBackgroundColor);
    }
}

- (UIColor*)buttonsTintColor {
  switch (self.style) {
    case NORMAL:
      return [UIColor colorNamed:@"tab_toolbar_button_color"];
    case INCOGNITO:
      return [UIColor whiteColor];
  }
}

- (UIColor*)buttonsTintColorHighlighted {
  switch (self.style) {
    case NORMAL:
      return [UIColor colorNamed:@"tab_toolbar_button_color_highlighted"];
      break;
    case INCOGNITO:
      return [UIColor
          colorWithWhite:1
                   alpha:kIncognitoToolbarButtonTintColorAlphaHighlighted];
      break;
  }
}

- (UIColor*)buttonsSpotlightColor {
  switch (self.style) {
    case NORMAL:
      return [UIColor colorNamed:@"tab_toolbar_button_halo_color"];
      break;
    case INCOGNITO:
      return [UIColor colorWithWhite:1 alpha:kToolbarSpotlightAlpha];
      break;
  }
}

- (UIColor*)dimmedButtonsSpotlightColor {
  switch (self.style) {
    case NORMAL:
      return [UIColor colorNamed:@"tab_toolbar_button_halo_color"];
      break;
    case INCOGNITO:
      return [UIColor colorWithWhite:1 alpha:kDimmedToolbarSpotlightAlpha];
      break;
  }
}

- (UIColor*)locationBarBackgroundColorWithVisibility:(CGFloat)visibilityFactor {
  switch (self.style) {
    case NORMAL:
      return [UIColor colorWithWhite:0
                               alpha:kAdaptiveLocationBarBackgroundAlpha *
                                     visibilityFactor];
    case INCOGNITO:
      return
          [UIColor colorWithWhite:1
                            alpha:kAdaptiveLocationBarBackgroundAlphaIncognito *
                                  visibilityFactor];
  }
}

@end
