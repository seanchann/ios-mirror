// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/menu/action_factory.h"

#import "base/metrics/histogram_functions.h"
#import "ios/chrome/browser/ui/commands/application_commands.h"
#import "ios/chrome/browser/ui/commands/command_dispatcher.h"
#import "ios/chrome/browser/ui/util/pasteboard_util.h"
#import "ios/chrome/browser/url_loading/url_loading_browser_agent.h"
#import "ios/chrome/browser/url_loading/url_loading_params.h"
#import "ios/chrome/grit/ios_strings.h"
#import "ui/base/l10n/l10n_util_mac.h"
#import "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

@interface ActionFactory ()

// Current browser instance.
@property(nonatomic, assign) Browser* browser;

// Histogram to record executed actions.
@property(nonatomic, assign) const char* histogram;

@end

@implementation ActionFactory

- (instancetype)initWithBrowser:(Browser*)browser
                       scenario:(MenuScenario)scenario {
  DCHECK(browser);

  if (self = [super init]) {
    _browser = browser;
    _histogram = GetActionsHistogramName(scenario);
  }
  return self;
}

- (UIAction*)actionWithTitle:(NSString*)title
                       image:(UIImage*)image
                        type:(MenuActionType)type
                       block:(ProceduralBlock)block {
  // Capture only the histogram name's pointer to be copied by the block.
  const char* histogram = self.histogram;
  return [UIAction actionWithTitle:title
                             image:image
                        identifier:nil
                           handler:^(UIAction* action) {
                             base::UmaHistogramEnumeration(histogram, type);
                             if (block) {
                               block();
                             }
                           }];
}

- (UIAction*)actionToCopyURL:(const GURL)URL {
  return [self actionWithTitle:l10n_util::GetNSString(IDS_IOS_COPY_ACTION_TITLE)
                         image:[UIImage systemImageNamed:@"doc.on.doc"]
                          type:MenuActionType::Copy
                         block:^{
                           StoreURLInPasteboard(URL);
                         }];
}

- (UIAction*)actionToDeleteWithBlock:(ProceduralBlock)block {
  UIAction* action =
      [self actionWithTitle:l10n_util::GetNSString(IDS_IOS_DELETE_ACTION_TITLE)
                      image:[UIImage systemImageNamed:@"trash"]
                       type:MenuActionType::Delete
                      block:block];
  action.attributes = UIMenuElementAttributesDestructive;
  return action;
}

- (UIAction*)actionToOpenInNewTabWithURL:(const GURL)URL
                              completion:(ProceduralBlock)completion {
  UrlLoadParams params = UrlLoadParams::InNewTab(URL);
  UrlLoadingBrowserAgent* loadingAgent =
      UrlLoadingBrowserAgent::FromBrowser(self.browser);
  return [self actionToOpenInNewTabWithBlock:^{
    loadingAgent->Load(params);
    if (completion) {
      completion();
    }
  }];
}

- (UIAction*)actionToOpenInNewTabWithBlock:(ProceduralBlock)block {
  return [self actionWithTitle:l10n_util::GetNSString(
                                   IDS_IOS_CONTENT_CONTEXT_OPENLINKNEWTAB)
                         image:[UIImage systemImageNamed:@"plus"]
                          type:MenuActionType::OpenInNewTab
                         block:block];
}

- (UIAction*)actionToOpenInNewIncognitoTabWithURL:(const GURL)URL
                                       completion:(ProceduralBlock)completion {
  UrlLoadParams params = UrlLoadParams::InNewTab(URL);
  params.in_incognito = YES;
  UrlLoadingBrowserAgent* loadingAgent =
      UrlLoadingBrowserAgent::FromBrowser(self.browser);
  return [self actionToOpenInNewIncognitoTabWithBlock:^{
    loadingAgent->Load(params);
    if (completion) {
      completion();
    }
  }];
}

- (UIAction*)actionToOpenInNewIncognitoTabWithBlock:(ProceduralBlock)block {
  return
      [self actionWithTitle:l10n_util::GetNSString(
                                IDS_IOS_CONTENT_CONTEXT_OPENLINKNEWINCOGNITOTAB)
                      image:nil
                       type:MenuActionType::OpenInNewIncognitoTab
                      block:block];
}

- (UIAction*)actionToOpenInNewWindowWithURL:(const GURL)URL
                             activityOrigin:(WindowActivityOrigin)activityOrigin
                                 completion:(ProceduralBlock)completion {
  id<ApplicationCommands> windowOpener = HandlerForProtocol(
      self.browser->GetCommandDispatcher(), ApplicationCommands);
  NSUserActivity* activity = ActivityToLoadURL(activityOrigin, URL);
  return [self actionWithTitle:l10n_util::GetNSString(
                                   IDS_IOS_CONTENT_CONTEXT_OPENINNEWWINDOW)
                         image:[UIImage systemImageNamed:@"plus.square"]
                          type:MenuActionType::OpenInNewWindow
                         block:^{
                           [windowOpener openNewWindowWithActivity:activity];
                           if (completion) {
                             completion();
                           }
                         }];
}

- (UIAction*)actionToRemoveWithBlock:(ProceduralBlock)block {
  UIAction* action =
      [self actionWithTitle:l10n_util::GetNSString(IDS_IOS_REMOVE_ACTION_TITLE)
                      image:[UIImage systemImageNamed:@"trash"]
                       type:MenuActionType::Remove
                      block:block];
  action.attributes = UIMenuElementAttributesDestructive;
  return action;
}

- (UIAction*)actionToEditWithBlock:(ProceduralBlock)block {
  return [self actionWithTitle:l10n_util::GetNSString(IDS_IOS_EDIT_ACTION_TITLE)
                         image:nil
                          type:MenuActionType::Edit
                         block:block];
}

@end
