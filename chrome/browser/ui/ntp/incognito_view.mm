// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "ios/chrome/browser/ui/ntp/incognito_view.h"

#include "components/google/core/browser/google_util.h"
#include "components/strings/grit/components_strings.h"
#include "ios/chrome/browser/application_context.h"
#include "ios/chrome/browser/ui/rtl_geometry.h"
#include "ios/chrome/browser/ui/ui_util.h"
#import "ios/chrome/browser/ui/uikit_ui_util.h"
#import "ios/chrome/browser/ui/url_loader.h"
#import "ios/chrome/browser/ui/util/constraints_ui_util.h"
#import "ios/chrome/common/string_util.h"
#import "ios/third_party/material_components_ios/src/components/Buttons/src/MaterialButtons.h"
#import "ios/third_party/material_components_ios/src/components/Palettes/src/MaterialPalettes.h"
#import "ios/third_party/material_components_ios/src/components/Typography/src/MaterialTypography.h"
#import "ios/web/public/navigation_manager.h"
#include "ios/web/public/referrer.h"
#import "net/base/mac/url_conversions.h"
#include "ui/base/l10n/l10n_util.h"
#include "url/gurl.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {

const CGFloat kStackViewHorizontalMargin = 20.0;
const CGFloat kStackViewHorizontalMarginLegacy = 24.0;
const CGFloat kStackViewMaxWidth = 416.0;
const CGFloat kStackViewDefaultSpacing = 20.0;
const CGFloat kStackViewDefaultSpacingLegacy = 32.0;
const CGFloat kStackViewImageSpacing = 22.0;
const CGFloat kStackViewImageSpacingLegacy = 24.0;
const CGFloat kLayoutGuideVerticalMargin = 8.0;
const CGFloat kLayoutGuideMinHeight = 12.0;

const int kLinkColor = 0x3A8FFF;
const int kLinkColorLegacy = 0x03A9F4;

// The URL for the the Learn More page shown on incognito new tab.
// Taken from ntp_resource_cache.cc.
const char kLearnMoreIncognitoUrl[] =
    "https://www.google.com/support/chrome/bin/answer.py?answer=95464";

GURL GetUrlWithLang(const GURL& url) {
  std::string locale = GetApplicationContext()->GetApplicationLocale();
  return google_util::AppendGoogleLocaleParam(url, locale);
}

// Returns a font, scaled to the current dynamic type settings, that is suitable
// for the title of the incognito page.
UIFont* TitleFont() {
  // On iOS 11, use UIFontMetrics to return a scalable font.
  if (@available(iOS 11.0, *)) {
    return [[UIFontMetrics defaultMetrics]
        scaledFontForFont:[UIFont boldSystemFontOfSize:26.0]];
  }

  UIFontDescriptor* baseDescriptor = [UIFontDescriptor
      preferredFontDescriptorWithTextStyle:UIFontTextStyleTitle1];
  UIFontDescriptor* styleDescriptor = [baseDescriptor
      fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
  // Use a |size| of 0.0 to use the default size for the descriptor.
  return [UIFont fontWithDescriptor:styleDescriptor size:0.0];
}

// Returns a font, scaled to the current dynamic type settings, that is suitable
// for the body text of the incognito page.
UIFont* BodyFont() {
  return [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
}

// Returns a font, scaled to the current dynamic type settings, that is suitable
// for bolded text in the body of the incognito page.
UIFont* BoldBodyFont() {
  UIFontDescriptor* baseDescriptor = [UIFontDescriptor
      preferredFontDescriptorWithTextStyle:UIFontTextStyleSubheadline];
  UIFontDescriptor* styleDescriptor = [baseDescriptor
      fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
  // Use a |size| of 0.0 to use the default size for the descriptor.
  return [UIFont fontWithDescriptor:styleDescriptor size:0.0];
}

// Takes an HTML string containing a bulleted list and formats it to display
// properly in a UILabel.  Removes the "<ul>" tag and replaces "<li>" with a
// bullet unicode character.
NSAttributedString* FormatHTMLListForUILabel(NSString* listString) {
  listString =
      [listString stringByReplacingOccurrencesOfString:@"<ul>" withString:@""];
  listString =
      [listString stringByReplacingOccurrencesOfString:@"</ul>" withString:@""];
  listString = [listString stringByReplacingOccurrencesOfString:@"<li>"
                                                     withString:@"\u2022\t"];
  listString = [listString
      stringByTrimmingCharactersInSet:[NSCharacterSet
                                          whitespaceAndNewlineCharacterSet]];

  NSRange emphasisRange;
  listString =
      ParseStringWithTag(listString, &emphasisRange, @"<em>", @"</em>");
  NSMutableAttributedString* attributedText =
      [[NSMutableAttributedString alloc] initWithString:listString];
  [attributedText addAttribute:NSFontAttributeName
                         value:BodyFont()
                         range:NSMakeRange(0, attributedText.length)];
  if (emphasisRange.location != NSNotFound) {
    [attributedText addAttribute:NSFontAttributeName
                           value:BoldBodyFont()
                           range:emphasisRange];
  }
  return attributedText;
}

}  // namespace

@implementation IncognitoView {
  __weak id<UrlLoader> _loader;
  UIView* _containerView;
  UIStackView* _stackView;
  UILabel* _notSavedLabel;
  UILabel* _visibleDataLabel;

  // Layout Guide whose height is the height of the bottom unsafe area.
  UILayoutGuide* _bottomUnsafeAreaGuide;
  UILayoutGuide* _bottomUnsafeAreaGuideInSuperview;

  // Constraint ensuring that |containerView| is at least as high as the
  // superview of the IncognitoNTPView, i.e. the Incognito panel.
  // This ensures that if the Incognito panel is higher than a compact
  // |containerView|, the |containerView|'s |topGuide| and |bottomGuide| are
  // forced to expand, centering the views in between them.
  NSArray<NSLayoutConstraint*>* _superViewConstraints;
}

- (instancetype)initWithFrame:(CGRect)frame urlLoader:(id<UrlLoader>)loader {
  self = [super initWithFrame:frame];
  if (self) {
    _loader = loader;

    self.alwaysBounceVertical = YES;
    if (@available(iOS 11.0, *)) {
      // The bottom safe area is taken care of with the bottomUnsafeArea guides.
      self.contentInsetAdjustmentBehavior =
          UIScrollViewContentInsetAdjustmentNever;
    }

    // Container to hold and vertically position the stack view.
    _containerView = [[UIView alloc] initWithFrame:frame];
    [_containerView setTranslatesAutoresizingMaskIntoConstraints:NO];

    // The following stackview constants depend on the state of the UIRefresh
    // experiment.
    BOOL refreshEnabled = IsUIRefreshPhase1Enabled();
    const CGFloat stackViewHorizontalMargin =
        refreshEnabled ? kStackViewHorizontalMargin
                       : kStackViewHorizontalMarginLegacy;
    const CGFloat stackViewDefaultSpacing =
        refreshEnabled ? kStackViewDefaultSpacing
                       : kStackViewDefaultSpacingLegacy;
    const CGFloat stackViewImageSpacing =
        refreshEnabled ? kStackViewImageSpacing : kStackViewImageSpacingLegacy;

    // Stackview in which all the subviews (image, labels, button) are added.
    _stackView = [[UIStackView alloc] init];
    [_stackView setTranslatesAutoresizingMaskIntoConstraints:NO];
    _stackView.axis = UILayoutConstraintAxisVertical;
    _stackView.spacing = stackViewDefaultSpacing;
    _stackView.distribution = UIStackViewDistributionFill;
    _stackView.alignment = UIStackViewAlignmentCenter;
    [_containerView addSubview:_stackView];

    // Incognito image.
    NSString* incognitoImageName =
        refreshEnabled ? @"incognito_icon" : @"incognito_legacy_icon";
    UIImageView* incognitoImage = [[UIImageView alloc]
        initWithImage:[UIImage imageNamed:incognitoImageName]];
    [_stackView addArrangedSubview:incognitoImage];
    if (@available(iOS 11.0, *)) {
      [_stackView setCustomSpacing:stackViewImageSpacing
                         afterView:incognitoImage];
    }

    if (refreshEnabled) {
      [self addUIRefreshTextSections];
    } else {
      [self addLegacyTextSections];
    }

    // |topGuide| and |bottomGuide| exist to vertically position the stackview
    // inside the container scrollview.
    UILayoutGuide* topGuide = [[UILayoutGuide alloc] init];
    UILayoutGuide* bottomGuide = [[UILayoutGuide alloc] init];
    _bottomUnsafeAreaGuide = [[UILayoutGuide alloc] init];
    [_containerView addLayoutGuide:topGuide];
    [_containerView addLayoutGuide:bottomGuide];
    [_containerView addLayoutGuide:_bottomUnsafeAreaGuide];

    [self addSubview:_containerView];

    [NSLayoutConstraint activateConstraints:@[
      // Position the stackview between the two guides.
      [topGuide.topAnchor constraintEqualToAnchor:_containerView.topAnchor],
      [_stackView.topAnchor constraintEqualToAnchor:topGuide.bottomAnchor
                                           constant:kLayoutGuideVerticalMargin],
      [bottomGuide.topAnchor
          constraintEqualToAnchor:_stackView.bottomAnchor
                         constant:kLayoutGuideVerticalMargin],
      [_containerView.bottomAnchor
          constraintEqualToAnchor:bottomGuide.bottomAnchor],

      // Center the stackview horizontally with a minimum margin.
      [_stackView.leadingAnchor
          constraintGreaterThanOrEqualToAnchor:_containerView.leadingAnchor
                                      constant:stackViewHorizontalMargin],
      [_stackView.trailingAnchor
          constraintLessThanOrEqualToAnchor:_containerView.trailingAnchor
                                   constant:-stackViewHorizontalMargin],
      [_stackView.centerXAnchor
          constraintEqualToAnchor:_containerView.centerXAnchor],

      // Constraint the _bottomUnsafeAreaGuide to the stack view and the
      // container view. Its height is set in the -didMoveToSuperview to take
      // into account the unsafe area.
      [_bottomUnsafeAreaGuide.topAnchor
          constraintEqualToAnchor:_stackView.bottomAnchor
                         constant:2 * kLayoutGuideMinHeight +
                                  kLayoutGuideVerticalMargin],
      [_bottomUnsafeAreaGuide.bottomAnchor
          constraintEqualToAnchor:_containerView.bottomAnchor],

      // Ensure that the stackview width is constrained.
      [_stackView.widthAnchor
          constraintLessThanOrEqualToConstant:kStackViewMaxWidth],

      // Set a minimum top margin and make the bottom guide twice as tall as the
      // top guide.
      [topGuide.heightAnchor
          constraintGreaterThanOrEqualToConstant:kLayoutGuideMinHeight],
      [bottomGuide.heightAnchor constraintEqualToAnchor:topGuide.heightAnchor
                                             multiplier:2.0],
    ]];

    // Constraints comunicating the size of the contentView to the scrollview.
    // See UIScrollView autolayout information at
    // https://developer.apple.com/library/ios/releasenotes/General/RN-iOSSDK-6_0/index.html
    NSDictionary* viewsDictionary = @{@"containerView" : _containerView};
    NSArray* constraints = @[
      @"V:|-0-[containerView]-0-|",
      @"H:|-0-[containerView]-0-|",
    ];
    ApplyVisualConstraints(constraints, viewsDictionary);
  }
  return self;
}

#pragma mark - UIView overrides

- (void)didMoveToSuperview {
  [super didMoveToSuperview];
  if (!self.superview)
    return;

  id<LayoutGuideProvider> safeAreaGuide =
      SafeAreaLayoutGuideForView(self.superview);
  _bottomUnsafeAreaGuideInSuperview = [[UILayoutGuide alloc] init];
  [self.superview addLayoutGuide:_bottomUnsafeAreaGuideInSuperview];

  _superViewConstraints = @[
    [safeAreaGuide.bottomAnchor
        constraintEqualToAnchor:_bottomUnsafeAreaGuideInSuperview.topAnchor],
    [self.superview.bottomAnchor
        constraintEqualToAnchor:_bottomUnsafeAreaGuideInSuperview.bottomAnchor],
    [_bottomUnsafeAreaGuide.heightAnchor
        constraintGreaterThanOrEqualToAnchor:_bottomUnsafeAreaGuideInSuperview
                                                 .heightAnchor],
    [_containerView.widthAnchor
        constraintEqualToAnchor:self.superview.widthAnchor],
    [_containerView.heightAnchor
        constraintGreaterThanOrEqualToAnchor:self.superview.heightAnchor],
  ];

  [NSLayoutConstraint activateConstraints:_superViewConstraints];
}

- (void)willMoveToSuperview:(UIView*)newSuperview {
  [NSLayoutConstraint deactivateConstraints:_superViewConstraints];
  [self.superview removeLayoutGuide:_bottomUnsafeAreaGuideInSuperview];
  [super willMoveToSuperview:newSuperview];
}

#pragma mark - Private

// Triggers a navigation to the help page.
- (void)learnMoreButtonPressed {
  web::NavigationManager::WebLoadParams params(
      GetUrlWithLang(GURL(kLearnMoreIncognitoUrl)));
  [_loader loadURLWithParams:params];
}

// Adds views containing the text of the incognito page to |_stackView|.
- (void)addUIRefreshTextSections {
  UIColor* titleTextColor = [UIColor whiteColor];
  UIColor* bodyTextColor = [UIColor colorWithWhite:1.0 alpha:0.7];
  UIColor* linkTextColor = UIColorFromRGB(kLinkColor);

  // Title.
  UILabel* titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
  titleLabel.font = TitleFont();
  titleLabel.textColor = titleTextColor;
  titleLabel.numberOfLines = 0;
  titleLabel.textAlignment = NSTextAlignmentCenter;
  titleLabel.text = l10n_util::GetNSString(IDS_NEW_TAB_OTR_TITLE);
  titleLabel.adjustsFontForContentSizeCategory = YES;
  [_stackView addArrangedSubview:titleLabel];

  // The Subtitle and Learn More link have no vertical spacing between them,
  // so they are embedded in a separate stack view.
  UILabel* subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
  subtitleLabel.font = BodyFont();
  subtitleLabel.textColor = bodyTextColor;
  subtitleLabel.numberOfLines = 0;
  subtitleLabel.text = l10n_util::GetNSString(IDS_NEW_TAB_OTR_SUBTITLE);
  subtitleLabel.adjustsFontForContentSizeCategory = YES;

  UIButton* learnMoreButton = [UIButton buttonWithType:UIButtonTypeCustom];
  [learnMoreButton
      setTitle:l10n_util::GetNSString(IDS_NEW_TAB_OTR_LEARN_MORE_LINK)
      forState:UIControlStateNormal];
  [learnMoreButton setTitleColor:linkTextColor forState:UIControlStateNormal];
  learnMoreButton.titleLabel.font = BodyFont();
  learnMoreButton.titleLabel.adjustsFontForContentSizeCategory = YES;
  [learnMoreButton addTarget:self
                      action:@selector(learnMoreButtonPressed)
            forControlEvents:UIControlEventTouchUpInside];

  UIStackView* subtitleStackView = [[UIStackView alloc]
      initWithArrangedSubviews:@[ subtitleLabel, learnMoreButton ]];
  subtitleStackView.axis = UILayoutConstraintAxisVertical;
  subtitleStackView.spacing = 0;
  subtitleStackView.distribution = UIStackViewDistributionFill;
  subtitleStackView.alignment = UIStackViewAlignmentLeading;
  [_stackView addArrangedSubview:subtitleStackView];

  // Text explaining what data that is not saved. This label uses an attributed
  // string, so it must be manually adjusted when Dynamic Type settings are
  // changed.
  NSAttributedString* notSavedText = FormatHTMLListForUILabel(
      l10n_util::GetNSString(IDS_NEW_TAB_OTR_NOT_SAVED));
  _notSavedLabel = [[UILabel alloc] initWithFrame:CGRectZero];
  _notSavedLabel.numberOfLines = 0;
  _notSavedLabel.adjustsFontForContentSizeCategory = NO;
  _notSavedLabel.attributedText = notSavedText;
  _notSavedLabel.textColor = bodyTextColor;
  [_stackView addArrangedSubview:_notSavedLabel];

  // Text explaining what data might still be visible. This label uses an
  // attributed string, so it must be manually adjusted when Dynamic Type
  // settings are changed.
  NSAttributedString* visibleDataText =
      FormatHTMLListForUILabel(l10n_util::GetNSString(IDS_NEW_TAB_OTR_VISIBLE));
  _visibleDataLabel = [[UILabel alloc] initWithFrame:CGRectZero];
  _visibleDataLabel.numberOfLines = 0;
  _visibleDataLabel.adjustsFontForContentSizeCategory = NO;
  _visibleDataLabel.attributedText = visibleDataText;
  _visibleDataLabel.textColor = bodyTextColor;
  [_stackView addArrangedSubview:_visibleDataLabel];

  // |_notSavedLabel| and |visibleDataLabel| should have the same width as
  // |subtitleStackView|, even if they can be constrained narrower.
  [NSLayoutConstraint activateConstraints:@[
    [_notSavedLabel.widthAnchor
        constraintEqualToAnchor:subtitleStackView.widthAnchor],
    [_visibleDataLabel.widthAnchor
        constraintEqualToAnchor:subtitleStackView.widthAnchor],
  ]];
}

#pragma mark - Legacy UI

// Returns an autoreleased label that is styled for the legacy UI.
- (UILabel*)legacyLabelWithMessageID:(int)messageID
                                font:(UIFont*)font
                               alpha:(CGFloat)alpha {
  NSString* string = l10n_util::GetNSString(messageID);
  NSMutableAttributedString* attributedString =
      [[NSMutableAttributedString alloc] initWithString:string];
  NSMutableParagraphStyle* paragraphStyle =
      [[NSMutableParagraphStyle alloc] init];
  [paragraphStyle setLineSpacing:4];
  [paragraphStyle setAlignment:NSTextAlignmentJustified];
  [attributedString addAttribute:NSParagraphStyleAttributeName
                           value:paragraphStyle
                           range:NSMakeRange(0, string.length)];
  UILabel* label = [[UILabel alloc] initWithFrame:CGRectZero];
  [label setTranslatesAutoresizingMaskIntoConstraints:NO];
  [label setNumberOfLines:0];
  [label setFont:font];
  [label setAttributedText:attributedString];
  [label setTextColor:[UIColor colorWithWhite:1.0 alpha:alpha]];
  return label;
}

// Adds views containing the text of the incognito page to |_stackView|.
- (void)addLegacyTextSections {
  // Title.
  UIFont* titleFont = [[MDCTypography fontLoader] lightFontOfSize:24];
  UILabel* incognitoTabHeading =
      [self legacyLabelWithMessageID:IDS_NEW_TAB_OTR_HEADING
                                font:titleFont
                               alpha:0.8];
  [_stackView addArrangedSubview:incognitoTabHeading];

  // Description paragraph.
  UIFont* regularFont = [[MDCTypography fontLoader] regularFontOfSize:14];
  UILabel* incognitoTabDescription =
      [self legacyLabelWithMessageID:IDS_NEW_TAB_OTR_DESCRIPTION
                                font:regularFont
                               alpha:0.7];
  [_stackView addArrangedSubview:incognitoTabDescription];

  // Warning paragraph.
  UILabel* incognitoTabWarning =
      [self legacyLabelWithMessageID:IDS_NEW_TAB_OTR_MESSAGE_WARNING
                                font:regularFont
                               alpha:0.7];
  [_stackView addArrangedSubview:incognitoTabWarning];

  // Learn more button.
  MDCButton* learnMore = [[MDCFlatButton alloc] init];
  [learnMore setBackgroundColor:[UIColor clearColor]
                       forState:UIControlStateNormal];
  UIColor* inkColor =
      [[[MDCPalette greyPalette] tint300] colorWithAlphaComponent:0.25];
  [learnMore setInkColor:inkColor];
  [learnMore setTranslatesAutoresizingMaskIntoConstraints:NO];
  [learnMore setTitle:l10n_util::GetNSString(IDS_NEW_TAB_OTR_LEARN_MORE_LINK)
             forState:UIControlStateNormal];
  [learnMore setTitleColor:UIColorFromRGB(kLinkColorLegacy)
                  forState:UIControlStateNormal];
  UIFont* buttonFont = [[MDCTypography fontLoader] boldFontOfSize:14];
  [[learnMore titleLabel] setFont:buttonFont];
  [learnMore addTarget:self
                action:@selector(learnMoreButtonPressed)
      forControlEvents:UIControlEventTouchUpInside];
  [_stackView addArrangedSubview:learnMore];
}

@end
