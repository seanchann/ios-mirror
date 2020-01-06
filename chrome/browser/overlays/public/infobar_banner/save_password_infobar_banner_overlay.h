// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_OVERLAYS_PUBLIC_INFOBAR_BANNER_SAVE_PASSWORD_INFOBAR_BANNER_OVERLAY_H_
#define IOS_CHROME_BROWSER_OVERLAYS_PUBLIC_INFOBAR_BANNER_SAVE_PASSWORD_INFOBAR_BANNER_OVERLAY_H_

#include "ios/chrome/browser/overlays/public/overlay_request_config.h"
#include "ios/chrome/browser/overlays/public/overlay_user_data.h"

namespace infobars {
class InfoBar;
}
class IOSChromeSavePasswordInfoBarDelegate;

// Configuration object for OverlayRequests for the banner UI for an InfoBar
// with a IOSChromeSavePasswordInfoBarDelegate.
class SavePasswordInfobarBannerOverlayRequestConfig
    : public OverlayRequestConfig<
          SavePasswordInfobarBannerOverlayRequestConfig> {
 public:
  ~SavePasswordInfobarBannerOverlayRequestConfig() override;

  // The infobar delegate's message text.
  NSString* message() const { return message_; }
  // The username for which passwords are being saved.
  NSString* username() const { return username_; }
  // The text to show on the banner's confirm button.
  NSString* button_text() const { return button_text_; }
  // The name of the banner's icon image.
  NSString* icon_image_name() const { return icon_image_name_; }
  // The length of the password being saved.
  size_t password_length() const { return password_length_; }

 private:
  OVERLAY_USER_DATA_SETUP(SavePasswordInfobarBannerOverlayRequestConfig);
  explicit SavePasswordInfobarBannerOverlayRequestConfig(
      infobars::InfoBar* infobar);

  // OverlayUserData:
  void CreateAuxilliaryData(base::SupportsUserData* user_data) override;

  // The InfoBar causing this banner.
  infobars::InfoBar* infobar_ = nullptr;
  // Configuration data extracted from |infobar_|'s save passwords delegate.
  NSString* message_ = nil;
  NSString* username_ = nil;
  NSString* button_text_ = nil;
  NSString* icon_image_name_ = nil;
  size_t password_length_ = 0;
};

#endif  // IOS_CHROME_BROWSER_OVERLAYS_PUBLIC_INFOBAR_BANNER_SAVE_PASSWORD_INFOBAR_BANNER_OVERLAY_H_
