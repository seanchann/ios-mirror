// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_SIGNIN_IDENTITY_MANAGER_FACTORY_OBSERVER_H_
#define IOS_CHROME_BROWSER_SIGNIN_IDENTITY_MANAGER_FACTORY_OBSERVER_H_

#include "base/macros.h"

namespace identity {
class IdentityManager;
}

// Observer for IdentityManagerFactory.
class IdentityManagerFactoryObserver {
 public:
  IdentityManagerFactoryObserver() {}
  virtual ~IdentityManagerFactoryObserver() {}

  // Called when an IdentityManager instance is created.
  virtual void IdentityManagerCreated(identity::IdentityManager* manager) {}

  // Called when a IdentityManager instance is being shut down. Observers
  // of |manager| should remove themselves at this point.
  virtual void IdentityManagerShutdown(identity::IdentityManager* manager) {}

 private:
  DISALLOW_COPY_AND_ASSIGN(IdentityManagerFactoryObserver);
};

#endif  // IOS_CHROME_BROWSER_SIGNIN_IDENTITY_MANAGER_FACTORY_OBSERVER_H_
