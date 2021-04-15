// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/authentication/signin/consistency_promo_signin/consistency_default_account/consistency_default_account_view_controller.h"

#import "base/check.h"
#import "base/notreached.h"
#import "base/strings/sys_string_conversions.h"
#import "ios/chrome/browser/ui/authentication/views/identity_button_control.h"
#import "ios/chrome/common/ui/colors/semantic_color_names.h"
#import "ios/chrome/common/ui/util/button_util.h"
#import "ios/chrome/common/ui/util/pointer_interaction_util.h"
#import "ios/chrome/grit/ios_chromium_strings.h"
#import "ios/chrome/grit/ios_strings.h"
#import "ui/base/l10n/l10n_util.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

// Margins for |self.contentView| (top, bottom, leading and trailing).
constexpr CGFloat kContentMargin = 16.;
// Avatar height and width.
constexpr CGFloat kAvatarSize = 30.;
// Space between elements in |self.contentView|.
constexpr CGFloat kContentSpacing = 16.;
// Constants for IdentityButtonControl.
constexpr CGFloat kMinimumTopMargin = 10.;
constexpr CGFloat kMinimumBottomMargin = 8.;
constexpr CGFloat kTitleSubtitleMargin = 0.;

}

@interface ConsistencyDefaultAccountViewController ()

// View that contains all UI elements for the view controller. This view is
// the only subview of -[ConsistencyDefaultAccountViewController view].
@property(nonatomic, strong) UIStackView* contentView;
// Button to present the default identity.
@property(nonatomic, strong) IdentityButtonControl* identityButtonControl;
// Button to confirm the default identity and sign-in.
@property(nonatomic, strong) UIButton* continueAsButton;

@end

@implementation ConsistencyDefaultAccountViewController

#pragma mark - UIViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  // Set the navigation title in the left bar button item to have left
  // alignment.
  UILabel* titleLabel = [[UILabel alloc] init];
  titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
  titleLabel.text =
      l10n_util::GetNSString(IDS_IOS_CONSISTENCY_PROMO_DEFAULT_ACCOUNT_TITLE);
  titleLabel.textAlignment = NSTextAlignmentLeft;
  UIBarButtonItem* leftItem =
      [[UIBarButtonItem alloc] initWithCustomView:titleLabel];
  self.navigationItem.leftBarButtonItem = leftItem;
  // Set the skip button in the right bar button item.
  UIBarButtonItem* anotherButton = [[UIBarButtonItem alloc]
      initWithTitle:l10n_util::GetNSString(IDS_IOS_CONSISTENCY_PROMO_SKIP)
              style:UIBarButtonItemStylePlain
             target:self
             action:@selector(skipButtonAction:)];
  self.navigationItem.rightBarButtonItem = anotherButton;
  // Replace the controller view by the scroll view.
  UIScrollView* scrollView = [[UIScrollView alloc] init];
  self.view = scrollView;
  // Create content view.
  self.contentView = [[UIStackView alloc] init];
  self.contentView.axis = UILayoutConstraintAxisVertical;
  self.contentView.distribution = UIStackViewDistributionEqualSpacing;
  self.contentView.alignment = UIStackViewAlignmentCenter;
  self.contentView.spacing = kContentSpacing;
  self.contentView.translatesAutoresizingMaskIntoConstraints = NO;
  [scrollView addSubview:self.contentView];
  UILayoutGuide* contentLayoutGuide = scrollView.contentLayoutGuide;
  UILayoutGuide* frameLayoutGuide = scrollView.safeAreaLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [contentLayoutGuide.topAnchor
        constraintEqualToAnchor:self.contentView.topAnchor
                       constant:-kContentMargin],
    [contentLayoutGuide.bottomAnchor
        constraintEqualToAnchor:self.contentView.bottomAnchor
                       constant:kContentMargin],
    [frameLayoutGuide.leadingAnchor
        constraintEqualToAnchor:self.contentView.leadingAnchor
                       constant:-kContentMargin],
    [frameLayoutGuide.trailingAnchor
        constraintEqualToAnchor:self.contentView.trailingAnchor
                       constant:kContentMargin],
  ]];
  // Add the label.
  UILabel* label = [[UILabel alloc] init];
  label.text =
      l10n_util::GetNSString(IDS_IOS_CONSISTENCY_PROMO_DEFAULT_ACCOUNT_LABEL);
  label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
  label.numberOfLines = 0;
  [self.contentView addArrangedSubview:label];
  [label.widthAnchor constraintEqualToAnchor:self.contentView.widthAnchor]
      .active = YES;
  // Add IdentityButtonControl for the default identity.
  self.identityButtonControl =
      [[IdentityButtonControl alloc] initWithFrame:CGRectZero];
  self.identityButtonControl.arrowDirection = IdentityButtonControlArrowRight;
  self.identityButtonControl.avatarSize = kAvatarSize;
  self.identityButtonControl.minimumTopMargin = kMinimumTopMargin;
  self.identityButtonControl.minimumBottomMargin = kMinimumBottomMargin;
  self.identityButtonControl.titleSubtitleMargin = kTitleSubtitleMargin;
  self.identityButtonControl.titleFont =
      [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
  self.identityButtonControl.subtitleFont =
      [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
  [self.identityButtonControl addTarget:self
                                 action:@selector(identityButtonControlAction:
                                                                     forEvent:)
                       forControlEvents:UIControlEventTouchUpInside];
  [self.contentView addArrangedSubview:self.identityButtonControl];
  [NSLayoutConstraint activateConstraints:@[
    [self.identityButtonControl.widthAnchor
        constraintEqualToAnchor:self.contentView.widthAnchor
                       constant:0]
  ]];
  // Add primary button.
  self.continueAsButton =
      PrimaryActionButton(/* pointer_interaction_enabled */ YES);
  self.continueAsButton.translatesAutoresizingMaskIntoConstraints = NO;
  [self.continueAsButton addTarget:self
                            action:@selector(signInWithDefaultIdentityAction:)
                  forControlEvents:UIControlEventTouchUpInside];
  [self.contentView addArrangedSubview:self.continueAsButton];
  [NSLayoutConstraint activateConstraints:@[
    [self.continueAsButton.widthAnchor
        constraintEqualToAnchor:self.contentView.widthAnchor
                       constant:0]
  ]];
  // Adjust the identity button control rounded corners to the same value than
  // the "continue as" button.
  self.identityButtonControl.layer.cornerRadius =
      self.continueAsButton.layer.cornerRadius;
}

#pragma mark - UI actions

- (void)skipButtonAction:(id)sender {
  [self.actionDelegate consistencyDefaultAccountViewControllerSkip:self];
}

- (void)identityButtonControlAction:(id)sender forEvent:(UIEvent*)event {
  [self.actionDelegate
      consistencyDefaultAccountViewControllerOpenIdentityChooser:self];
}

- (void)signInWithDefaultIdentityAction:(id)sender {
  [self.actionDelegate
      consistencyDefaultAccountViewControllerContinueWithSelectedIdentity:self];
}

#pragma mark - ChildBottomSheetViewController

- (CGFloat)layoutFittingHeightForWidth:(CGFloat)width {
  CGFloat contentViewWidth = width - self.view.safeAreaInsets.left -
                             self.view.safeAreaInsets.right -
                             kContentMargin * 2;
  CGSize size = CGSizeMake(contentViewWidth, 0);
  size = [self.contentView
        systemLayoutSizeFittingSize:size
      withHorizontalFittingPriority:UILayoutPriorityRequired
            verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
  // Safe area insets needs to be based on the window since the |self.view|
  // might not be part of the window hierarchy when the animation is configured.
  return size.height +
         self.navigationController.navigationBar.frame.size.height +
         self.navigationController.view.window.safeAreaInsets.bottom +
         kContentMargin * 2;
}

#pragma mark - ConsistencyDefaultAccountConsumer

- (void)updateWithFullName:(NSString*)fullName
                 givenName:(NSString*)givenName
                     email:(NSString*)email {
  if (!self.viewLoaded) {
    // Load the view.
    [self view];
  }
  NSString* buttonTitle = l10n_util::GetNSStringF(
      IDS_IOS_SIGNIN_PROMO_CONTINUE_AS, base::SysNSStringToUTF16(givenName));
  [self.continueAsButton setTitle:buttonTitle forState:UIControlStateNormal];
  [self.identityButtonControl setIdentityName:fullName email:email];
}

- (void)updateUserAvatar:(UIImage*)avatar {
  if (!self.viewLoaded) {
    // Load the view.
    [self view];
  }
  [self.identityButtonControl setIdentityAvatar:avatar];
}

@end
