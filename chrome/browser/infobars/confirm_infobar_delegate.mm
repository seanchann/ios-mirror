// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "components/infobars/core/confirm_infobar_delegate.h"

#include "base/mac/scoped_nsobject.h"
#include "base/memory/scoped_ptr.h"
#include "ios/chrome/browser/infobars/confirm_infobar_controller.h"
#include "ios/chrome/browser/infobars/infobar.h"

// This function is defined in the component, but implemented in the embedder.
// static
scoped_ptr<infobars::InfoBar> ConfirmInfoBarDelegate::CreateInfoBar(
    scoped_ptr<ConfirmInfoBarDelegate> delegate) {
  scoped_ptr<InfoBarIOS> infobar(new InfoBarIOS(delegate.Pass()));
  base::scoped_nsobject<ConfirmInfoBarController> controller(
      [[ConfirmInfoBarController alloc] initWithDelegate:infobar.get()]);
  infobar->SetController(controller);
  return infobar.Pass();
}
