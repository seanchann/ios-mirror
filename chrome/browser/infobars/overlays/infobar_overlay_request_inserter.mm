// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/infobars/overlays/infobar_overlay_request_inserter.h"

#include "base/logging.h"
#import "ios/chrome/browser/infobars/overlays/infobar_overlay_request_cancel_handler.h"
#import "ios/chrome/browser/infobars/overlays/infobar_overlay_request_factory.h"
#import "ios/chrome/browser/overlays/public/common/infobars/infobar_overlay_request_config.h"
#include "ios/chrome/browser/overlays/public/overlay_modality.h"
#include "ios/chrome/browser/overlays/public/overlay_request.h"
#import "ios/chrome/browser/overlays/public/overlay_request_queue.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

InfobarOverlayRequestInserter::InfobarOverlayRequestInserter(
    web::WebState* web_state,
    std::unique_ptr<InfobarOverlayRequestFactory> factory)
    : web_state_(web_state), request_factory_(std::move(factory)) {
  DCHECK(web_state_);
  DCHECK(request_factory_);
  // Populate |queues_| with the request queues at the appropriate modalities.
  queues_[InfobarOverlayType::kBanner] = OverlayRequestQueue::FromWebState(
      web_state_, OverlayModality::kInfobarBanner);
  queues_[InfobarOverlayType::kDetailSheet] = OverlayRequestQueue::FromWebState(
      web_state_, OverlayModality::kInfobarModal);
  queues_[InfobarOverlayType::kModal] = OverlayRequestQueue::FromWebState(
      web_state_, OverlayModality::kInfobarModal);
}

InfobarOverlayRequestInserter::~InfobarOverlayRequestInserter() = default;

void InfobarOverlayRequestInserter::AddOverlayRequest(
    infobars::InfoBar* infobar,
    InfobarOverlayType type) const {
  InsertOverlayRequest(infobar, type, queues_.at(type)->size());
}

void InfobarOverlayRequestInserter::InsertOverlayRequest(
    infobars::InfoBar* infobar,
    InfobarOverlayType type,
    size_t index) const {
  // Create the request and its cancel handler.
  std::unique_ptr<OverlayRequest> request =
      request_factory_->CreateInfobarRequest(infobar, type);
  DCHECK(request.get());
  DCHECK_EQ(infobar,
            request->GetConfig<InfobarOverlayRequestConfig>()->infobar());
  OverlayRequestQueue* queue = queues_.at(type);
  std::unique_ptr<OverlayRequestCancelHandler> cancel_handler =
      std::make_unique<InfobarOverlayRequestCancelHandler>(request.get(), queue,
                                                           infobar);
  queue->InsertRequest(index, std::move(request), std::move(cancel_handler));
}
