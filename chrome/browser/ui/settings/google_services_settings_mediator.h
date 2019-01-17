// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_BROWSER_UI_SETTINGS_GOOGLE_SERVICES_SETTINGS_MEDIATOR_H_
#define IOS_CHROME_BROWSER_UI_SETTINGS_GOOGLE_SERVICES_SETTINGS_MEDIATOR_H_

#import <UIKit/UIKit.h>

#import "ios/chrome/browser/ui/settings/google_services_settings_consumer.h"
#import "ios/chrome/browser/ui/settings/google_services_settings_service_delegate.h"
#import "ios/chrome/browser/ui/settings/google_services_settings_view_controller.h"
#import "ios/chrome/browser/ui/settings/google_services_settings_view_controller_model_delegate.h"

class AuthenticationService;
@protocol GoogleServicesSettingsCommandHandler;
@class GoogleServicesSettingsViewController;
class PrefService;
class SyncSetupService;

namespace browser_sync {
class ProfileSyncService;
}  // namespace browser_sync
namespace identity {
class IdentityManager;
}  // namespace identity

// Mediator for the Google services settings.
@interface GoogleServicesSettingsMediator
    : NSObject <GoogleServicesSettingsServiceDelegate,
                GoogleServicesSettingsViewControllerModelDelegate>

// View controller.
@property(nonatomic, weak) id<GoogleServicesSettingsConsumer> consumer;
// Authentication service.
@property(nonatomic, assign) AuthenticationService* authService;
// Command handler.
@property(nonatomic, weak) id<GoogleServicesSettingsCommandHandler>
    commandHandler;
// Sync service.
@property(nonatomic, assign) browser_sync::ProfileSyncService* syncService;
// Identity manager;
@property(nonatomic, assign) identity::IdentityManager* identityManager;

// Designated initializer. All the paramters should not be null.
// |userPrefService|: preference service from the browser state.
// |localPrefService|: preference service from the application context.
// |syncSetupService|: allows configuring sync.
- (instancetype)initWithUserPrefService:(PrefService*)userPrefService
                       localPrefService:(PrefService*)localPrefService
                       syncSetupService:(SyncSetupService*)syncSetupService
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end

#endif  // IOS_CHROME_BROWSER_UI_SETTINGS_GOOGLE_SERVICES_SETTINGS_MEDIATOR_H_
