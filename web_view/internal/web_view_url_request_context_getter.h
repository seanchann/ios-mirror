// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_WEB_VIEW_INTERNAL_WEB_VIEW_URL_REQUEST_CONTEXT_GETTER_H_
#define IOS_WEB_VIEW_INTERNAL_WEB_VIEW_URL_REQUEST_CONTEXT_GETTER_H_

#include <memory>

#include "base/compiler_specific.h"
#include "base/files/file_path.h"
#include "base/memory/ref_counted.h"
#include "base/single_thread_task_runner.h"
#include "net/url_request/url_request_context_getter.h"

namespace net {
class NetworkDelegate;
class NetLog;
class ProxyConfigService;
class TransportSecurityPersister;
class URLRequestContext;
class URLRequestContextStorage;
}

namespace ios_web_view {

// WebView implementation of URLRequestContextGetter.
class WebViewURLRequestContextGetter : public net::URLRequestContextGetter {
 public:
  WebViewURLRequestContextGetter(
      const base::FilePath& base_path,
      const scoped_refptr<base::SingleThreadTaskRunner>& network_task_runner);

  // net::URLRequestContextGetter implementation.
  net::URLRequestContext* GetURLRequestContext() override;
  scoped_refptr<base::SingleThreadTaskRunner> GetNetworkTaskRunner()
      const override;

 protected:
  ~WebViewURLRequestContextGetter() override;

 private:
  base::FilePath base_path_;
  scoped_refptr<base::SingleThreadTaskRunner> network_task_runner_;
  std::unique_ptr<net::ProxyConfigService> proxy_config_service_;
  std::unique_ptr<net::NetworkDelegate> network_delegate_;
  std::unique_ptr<net::URLRequestContextStorage> storage_;
  std::unique_ptr<net::URLRequestContext> url_request_context_;
  std::unique_ptr<net::NetLog> net_log_;
  std::unique_ptr<net::TransportSecurityPersister>
      transport_security_persister_;

  DISALLOW_COPY_AND_ASSIGN(WebViewURLRequestContextGetter);
};

}  // namespace ios_web_view

#endif  // IOS_WEB_VIEW_INTERNAL_WEB_VIEW_URL_REQUEST_CONTEXT_GETTER_H_
