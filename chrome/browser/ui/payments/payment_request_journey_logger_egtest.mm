// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "base/ios/ios_util.h"
#include "components/autofill/core/browser/autofill_profile.h"
#include "components/autofill/core/browser/autofill_test_utils.h"
#include "components/payments/core/journey_logger.h"
#include "components/strings/grit/components_strings.h"
#import "ios/chrome/browser/ui/payments/payment_request_egtest_base.h"
#import "ios/chrome/test/app/histogram_test_util.h"
#import "ios/chrome/test/earl_grey/chrome_earl_grey.h"
#import "ios/chrome/test/earl_grey/chrome_matchers.h"

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

namespace {
using payments::JourneyLogger;
}  // namespace

// Journey logger tests for Payment Request.
@interface PaymentRequestJourneyLoggerEGTest : PaymentRequestEGTestBase
@end

@implementation PaymentRequestJourneyLoggerEGTest {
  autofill::AutofillProfile _profile1;
  autofill::AutofillProfile _profile2;
  autofill::CreditCard _creditCard1;
}

#pragma mark - XCTestCase

// Set up called once before each test.
- (void)setUp {
  [super setUp];

  _profile1 = autofill::test::GetFullProfile();
  [self addAutofillProfile:_profile1];

  _profile2 = autofill::test::GetFullProfile2();
  [self addAutofillProfile:_profile2];

  _creditCard1 = autofill::test::GetCreditCard();
  _creditCard1.set_billing_address_id(_profile1.guid());
  [self addCreditCard:_creditCard1];
}

#pragma mark - Tests

// Tests that the selected instrument metric is correctly logged when the
// Payment Request is completed with a credit card.
- (void)testSelectedPaymentMethod {
  chrome_test_util::HistogramTester histogramTester;

  [self loadTestPage:"payment_request_no_shipping_test.html"];
  [ChromeEarlGrey tapWebViewElementWithID:@"buy"];
  [self payWithCreditCardUsingCVC:@"123"];

  // Make sure the correct events were logged.
  std::vector<chrome_test_util::Bucket> buckets =
      histogramTester.GetAllSamples("PaymentRequest.Events");
  GREYAssertEqual(1U, buckets.size(), @"Exactly one bucket");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_SHOWN, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_PAY_CLICKED, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_RECEIVED_INSTRUMENT_DETAILS, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SKIPPED_SHOW, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_COMPLETED, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_USER_ABORTED, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_OTHER_ABORTED, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_HAD_INITIAL_FORM_OF_PAYMENT, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_HAD_NECESSARY_COMPLETE_SUGGESTIONS,
      @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_SHIPPING, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_NAME,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_PHONE,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_EMAIL,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_CAN_MAKE_PAYMENT_FALSE,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_CAN_MAKE_PAYMENT_TRUE,
                  @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_BASIC_CARD, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_GOOGLE,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_OTHER,
                  @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_SELECTED_CREDIT_CARD,
                 @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_GOOGLE, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_OTHER, @"");
}

- (void)testOnlyBobpaySupported {
  if (!base::ios::IsRunningOnOrLater(10, 3, 0)) {
    EARL_GREY_TEST_SKIPPED(
        @"Disabled on iOS versions below 10.3 because DOMException is not "
        @"available.");
  }

  chrome_test_util::HistogramTester histogramTester;

  [self loadTestPage:"payment_request_bobpay_test.html"];
  [ChromeEarlGrey tapWebViewElementWithID:@"buy"];
  [self waitForWebViewContainingTexts:{"rejected"}];

  FailureBlock failureBlock = ^(NSString* error) {
    GREYFail(error);
  };
  histogramTester.ExpectBucketCount(
      "PaymentRequest.CheckoutFunnel.NoShow",
      JourneyLogger::NOT_SHOWN_REASON_NO_SUPPORTED_PAYMENT_METHOD, 1,
      failureBlock);

  // Make sure the correct events were logged.
  std::vector<chrome_test_util::Bucket> buckets =
      histogramTester.GetAllSamples("PaymentRequest.Events");
  GREYAssertEqual(1U, buckets.size(), @"Exactly one bucket");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SHOWN, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_PAY_CLICKED, @"");
  GREYAssertFalse(
      buckets[0].min & JourneyLogger::EVENT_RECEIVED_INSTRUMENT_DETAILS, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SKIPPED_SHOW, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_COMPLETED, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_USER_ABORTED, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_OTHER_ABORTED, @"");
  GREYAssertFalse(
      buckets[0].min & JourneyLogger::EVENT_HAD_INITIAL_FORM_OF_PAYMENT, @"");
  GREYAssertFalse(
      buckets[0].min & JourneyLogger::EVENT_HAD_NECESSARY_COMPLETE_SUGGESTIONS,
      @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_SHIPPING, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_NAME,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_PHONE,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_EMAIL,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_CAN_MAKE_PAYMENT_FALSE,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_CAN_MAKE_PAYMENT_TRUE,
                  @"");
  GREYAssertFalse(
      buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_BASIC_CARD, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_GOOGLE,
                  @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_OTHER,
                 @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_CREDIT_CARD,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_GOOGLE, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_OTHER, @"");
}

- (void)testShowSameRequest {
  chrome_test_util::HistogramTester histogramTester;

  [self loadTestPage:"payment_request_multiple_show_test.html"];
  [ChromeEarlGrey tapWebViewElementWithID:@"buy"];
  [ChromeEarlGrey tapWebViewElementWithID:@"showAgain"];
  [self payWithCreditCardUsingCVC:@"123"];

  // Trying to show the same request twice is not considered a concurrent
  // request.
  GREYAssertTrue(
      histogramTester.GetAllSamples("PaymentRequest.CheckoutFunnel.NoShow")
          .empty(),
      @"");

  // Make sure the correct events were logged.
  std::vector<chrome_test_util::Bucket> buckets =
      histogramTester.GetAllSamples("PaymentRequest.Events");
  GREYAssertEqual(1U, buckets.size(), @"Exactly one bucket");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_SHOWN, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_PAY_CLICKED, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_RECEIVED_INSTRUMENT_DETAILS, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SKIPPED_SHOW, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_COMPLETED, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_USER_ABORTED, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_OTHER_ABORTED, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_HAD_INITIAL_FORM_OF_PAYMENT, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_HAD_NECESSARY_COMPLETE_SUGGESTIONS,
      @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_SHIPPING, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_NAME,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_PHONE,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_EMAIL,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_CAN_MAKE_PAYMENT_FALSE,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_CAN_MAKE_PAYMENT_TRUE,
                  @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_BASIC_CARD, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_GOOGLE,
                  @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_OTHER,
                 @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_SELECTED_CREDIT_CARD,
                 @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_GOOGLE, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_OTHER, @"");
}

// TODO(crbug.com/602666): add a test to verify that the correct metrics get
// recorded if the page tries to show() a second PaymentRequest, similar to
// PaymentRequestJourneyLoggerMultipleShowTest.StartNewRequest from
// payment_request_journey_logger_browsertest.cc.

// Tests that the correct number of suggestions shown for each section is logged
// when a Payment Request is completed.
- (void)testAllSectionStats_NumberOfSuggestionsShown_Completed {
  chrome_test_util::HistogramTester histogramTester;

  [self loadTestPage:
            "payment_request_contact_details_and_free_shipping_test.html"];
  [ChromeEarlGrey tapWebViewElementWithID:@"buy"];
  [self payWithCreditCardUsingCVC:@"123"];

  FailureBlock failureBlock = ^(NSString* error) {
    GREYFail(error);
  };

  // Expect the appropriate number of suggestions shown to be logged.
  histogramTester.ExpectUniqueSample(
      "PaymentRequest.NumberOfSuggestionsShown.PaymentMethod.Completed", 1, 1,
      failureBlock);
  histogramTester.ExpectUniqueSample(
      "PaymentRequest.NumberOfSuggestionsShown.ShippingAddress.Completed", 2, 1,
      failureBlock);
  histogramTester.ExpectUniqueSample(
      "PaymentRequest.NumberOfSuggestionsShown.ContactInfo.Completed", 2, 1,
      failureBlock);

  // Make sure the correct events were logged.
  std::vector<chrome_test_util::Bucket> buckets =
      histogramTester.GetAllSamples("PaymentRequest.Events");
  GREYAssertEqual(1U, buckets.size(), @"Exactly one bucket");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_SHOWN, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_PAY_CLICKED, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_RECEIVED_INSTRUMENT_DETAILS, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SKIPPED_SHOW, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_COMPLETED, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_USER_ABORTED, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_OTHER_ABORTED, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_HAD_INITIAL_FORM_OF_PAYMENT, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_HAD_NECESSARY_COMPLETE_SUGGESTIONS,
      @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_SHIPPING, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_NAME, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_PHONE,
                 @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_EMAIL,
                 @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_CAN_MAKE_PAYMENT_FALSE,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_CAN_MAKE_PAYMENT_TRUE,
                  @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_BASIC_CARD, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_GOOGLE,
                  @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_OTHER,
                 @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_SELECTED_CREDIT_CARD,
                 @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_GOOGLE, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_OTHER, @"");
}

// Tests that the correct number of suggestions shown for each section is logged
// when a Payment Request is aborted by the user.
- (void)testAllSectionStats_NumberOfSuggestionsShown_UserAborted {
  chrome_test_util::HistogramTester histogramTester;

  [self loadTestPage:
            "payment_request_contact_details_and_free_shipping_test.html"];
  [ChromeEarlGrey tapWebViewElementWithID:@"buy"];
  [[EarlGrey
      selectElementWithMatcher:chrome_test_util::ButtonWithAccessibilityLabelId(
                                   IDS_CANCEL)] performAction:grey_tap()];

  FailureBlock failureBlock = ^(NSString* error) {
    GREYFail(error);
  };

  // Expect the appropriate number of suggestions shown to be logged.
  histogramTester.ExpectUniqueSample(
      "PaymentRequest.NumberOfSuggestionsShown.PaymentMethod.UserAborted", 1, 1,
      failureBlock);
  histogramTester.ExpectUniqueSample(
      "PaymentRequest.NumberOfSuggestionsShown.ShippingAddress.UserAborted", 2,
      1, failureBlock);
  histogramTester.ExpectUniqueSample(
      "PaymentRequest.NumberOfSuggestionsShown.ContactInfo.UserAborted", 2, 1,
      failureBlock);

  // Make sure the correct events were logged.
  std::vector<chrome_test_util::Bucket> buckets =
      histogramTester.GetAllSamples("PaymentRequest.Events");
  GREYAssertEqual(1U, buckets.size(), @"Exactly one bucket");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_SHOWN, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_PAY_CLICKED, @"");
  GREYAssertFalse(
      buckets[0].min & JourneyLogger::EVENT_RECEIVED_INSTRUMENT_DETAILS, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SKIPPED_SHOW, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_COMPLETED, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_USER_ABORTED, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_OTHER_ABORTED, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_HAD_INITIAL_FORM_OF_PAYMENT, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_HAD_NECESSARY_COMPLETE_SUGGESTIONS,
      @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_SHIPPING, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_NAME, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_PHONE,
                 @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_EMAIL,
                 @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_CAN_MAKE_PAYMENT_FALSE,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_CAN_MAKE_PAYMENT_TRUE,
                  @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_BASIC_CARD, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_GOOGLE,
                  @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_OTHER,
                 @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_CREDIT_CARD,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_GOOGLE, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_OTHER, @"");
}

// Tests that the correct number of suggestions shown for each section is logged
// when a Payment Request is completed.
- (void)testNoShippingSectionStats_NumberOfSuggestionsShown_Completed {
  chrome_test_util::HistogramTester histogramTester;

  [self loadTestPage:"payment_request_contact_details_test.html"];
  [ChromeEarlGrey tapWebViewElementWithID:@"buy"];
  [self payWithCreditCardUsingCVC:@"123"];

  FailureBlock failureBlock = ^(NSString* error) {
    GREYFail(error);
  };

  // Expect the appropriate number of suggestions shown to be logged.
  histogramTester.ExpectUniqueSample(
      "PaymentRequest.NumberOfSuggestionsShown.PaymentMethod.Completed", 1, 1,
      failureBlock);
  histogramTester.ExpectUniqueSample(
      "PaymentRequest.NumberOfSuggestionsShown.ContactInfo.Completed", 2, 1,
      failureBlock);

  // There should be no log for shipping address since it was not requested.
  histogramTester.ExpectTotalCount(
      "PaymentRequest.NumberOfSuggestionsShown.ShippingAddress.Completed", 0,
      failureBlock);

  // Make sure the correct events were logged.
  std::vector<chrome_test_util::Bucket> buckets =
      histogramTester.GetAllSamples("PaymentRequest.Events");
  GREYAssertEqual(1U, buckets.size(), @"Exactly one bucket");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_SHOWN, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_PAY_CLICKED, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_RECEIVED_INSTRUMENT_DETAILS, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SKIPPED_SHOW, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_COMPLETED, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_USER_ABORTED, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_OTHER_ABORTED, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_HAD_INITIAL_FORM_OF_PAYMENT, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_HAD_NECESSARY_COMPLETE_SUGGESTIONS,
      @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_SHIPPING, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_NAME, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_PHONE,
                 @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_EMAIL,
                 @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_CAN_MAKE_PAYMENT_FALSE,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_CAN_MAKE_PAYMENT_TRUE,
                  @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_BASIC_CARD, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_GOOGLE,
                  @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_OTHER,
                 @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_SELECTED_CREDIT_CARD,
                 @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_GOOGLE, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_OTHER, @"");
}

// Tests that the correct number of suggestions shown for each section is logged
// when a Payment Request is aborted by the user.
- (void)testNoShippingSectionStats_NumberOfSuggestionsShown_UserAborted {
  chrome_test_util::HistogramTester histogramTester;

  [self loadTestPage:"payment_request_contact_details_test.html"];
  [ChromeEarlGrey tapWebViewElementWithID:@"buy"];
  [[EarlGrey
      selectElementWithMatcher:chrome_test_util::ButtonWithAccessibilityLabelId(
                                   IDS_CANCEL)] performAction:grey_tap()];

  FailureBlock failureBlock = ^(NSString* error) {
    GREYFail(error);
  };

  // Expect the appropriate number of suggestions shown to be logged.
  histogramTester.ExpectUniqueSample(
      "PaymentRequest.NumberOfSuggestionsShown.PaymentMethod.UserAborted", 1, 1,
      failureBlock);
  histogramTester.ExpectUniqueSample(
      "PaymentRequest.NumberOfSuggestionsShown.ContactInfo.UserAborted", 2, 1,
      failureBlock);

  // There should be no log for shipping address since it was not requested.
  histogramTester.ExpectTotalCount(
      "PaymentRequest.NumberOfSuggestionsShown.ShippingAddress.UserAborted", 0,
      failureBlock);

  // Make sure the correct events were logged.
  std::vector<chrome_test_util::Bucket> buckets =
      histogramTester.GetAllSamples("PaymentRequest.Events");
  GREYAssertEqual(1U, buckets.size(), @"Exactly one bucket");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_SHOWN, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_PAY_CLICKED, @"");
  GREYAssertFalse(
      buckets[0].min & JourneyLogger::EVENT_RECEIVED_INSTRUMENT_DETAILS, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SKIPPED_SHOW, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_COMPLETED, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_USER_ABORTED, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_OTHER_ABORTED, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_HAD_INITIAL_FORM_OF_PAYMENT, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_HAD_NECESSARY_COMPLETE_SUGGESTIONS,
      @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_SHIPPING, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_NAME, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_PHONE,
                 @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_EMAIL,
                 @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_CAN_MAKE_PAYMENT_FALSE,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_CAN_MAKE_PAYMENT_TRUE,
                  @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_BASIC_CARD, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_GOOGLE,
                  @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_OTHER,
                 @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_CREDIT_CARD,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_GOOGLE, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_OTHER, @"");
}

// Tests that the correct number of suggestions shown for each section is logged
// when a Payment Request is completed.
- (void)testNoContactDetailSectionStats_NumberOfSuggestionsShown_Completed {
  chrome_test_util::HistogramTester histogramTester;

  [self loadTestPage:"payment_request_free_shipping_test.html"];
  [ChromeEarlGrey tapWebViewElementWithID:@"buy"];
  [self payWithCreditCardUsingCVC:@"123"];

  FailureBlock failureBlock = ^(NSString* error) {
    GREYFail(error);
  };

  // Expect the appropriate number of suggestions shown to be logged.
  histogramTester.ExpectUniqueSample(
      "PaymentRequest.NumberOfSuggestionsShown.PaymentMethod.Completed", 1, 1,
      failureBlock);
  histogramTester.ExpectUniqueSample(
      "PaymentRequest.NumberOfSuggestionsShown.ShippingAddress.Completed", 2, 1,
      failureBlock);

  // There should be no log for contact info since it was not requested.
  histogramTester.ExpectTotalCount(
      "PaymentRequest.NumberOfSuggestionsShown.ContactInfo.Completed", 0,
      failureBlock);

  // Make sure the correct events were logged.
  std::vector<chrome_test_util::Bucket> buckets =
      histogramTester.GetAllSamples("PaymentRequest.Events");
  GREYAssertEqual(1U, buckets.size(), @"Exactly one bucket");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_SHOWN, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_PAY_CLICKED, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_RECEIVED_INSTRUMENT_DETAILS, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SKIPPED_SHOW, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_COMPLETED, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_USER_ABORTED, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_OTHER_ABORTED, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_HAD_INITIAL_FORM_OF_PAYMENT, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_HAD_NECESSARY_COMPLETE_SUGGESTIONS,
      @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_SHIPPING, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_NAME,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_PHONE,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_EMAIL,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_CAN_MAKE_PAYMENT_FALSE,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_CAN_MAKE_PAYMENT_TRUE,
                  @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_BASIC_CARD, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_GOOGLE,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_OTHER,
                  @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_SELECTED_CREDIT_CARD,
                 @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_GOOGLE, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_OTHER, @"");
}

// Tests that the correct number of suggestions shown for each section is logged
// when a Payment Request is aborted by the user.
- (void)testNoContactDetailSectionStats_NumberOfSuggestionsShown_UserAborted {
  chrome_test_util::HistogramTester histogramTester;

  [self loadTestPage:"payment_request_free_shipping_test.html"];
  [ChromeEarlGrey tapWebViewElementWithID:@"buy"];
  [[EarlGrey
      selectElementWithMatcher:chrome_test_util::ButtonWithAccessibilityLabelId(
                                   IDS_CANCEL)] performAction:grey_tap()];

  FailureBlock failureBlock = ^(NSString* error) {
    GREYFail(error);
  };

  // Expect the appropriate number of suggestions shown to be logged.
  histogramTester.ExpectUniqueSample(
      "PaymentRequest.NumberOfSuggestionsShown.PaymentMethod.UserAborted", 1, 1,
      failureBlock);
  histogramTester.ExpectUniqueSample(
      "PaymentRequest.NumberOfSuggestionsShown.ShippingAddress.UserAborted", 2,
      1, failureBlock);

  // There should be no log for contact info since it was not requested.
  histogramTester.ExpectTotalCount(
      "PaymentRequest.NumberOfSuggestionsShown.ContactInfo.UserAborted", 0,
      failureBlock);

  // Make sure the correct events were logged.
  std::vector<chrome_test_util::Bucket> buckets =
      histogramTester.GetAllSamples("PaymentRequest.Events");
  GREYAssertEqual(1U, buckets.size(), @"Exactly one bucket");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_SHOWN, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_PAY_CLICKED, @"");
  GREYAssertFalse(
      buckets[0].min & JourneyLogger::EVENT_RECEIVED_INSTRUMENT_DETAILS, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SKIPPED_SHOW, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_COMPLETED, @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_USER_ABORTED, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_OTHER_ABORTED, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_HAD_INITIAL_FORM_OF_PAYMENT, @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_HAD_NECESSARY_COMPLETE_SUGGESTIONS,
      @"");
  GREYAssertTrue(buckets[0].min & JourneyLogger::EVENT_REQUEST_SHIPPING, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_NAME,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_PHONE,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_PAYER_EMAIL,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_CAN_MAKE_PAYMENT_FALSE,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_CAN_MAKE_PAYMENT_TRUE,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_CAN_MAKE_PAYMENT_FALSE,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_CAN_MAKE_PAYMENT_TRUE,
                  @"");
  GREYAssertTrue(
      buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_BASIC_CARD, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_GOOGLE,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_REQUEST_METHOD_OTHER,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_CREDIT_CARD,
                  @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_GOOGLE, @"");
  GREYAssertFalse(buckets[0].min & JourneyLogger::EVENT_SELECTED_OTHER, @"");
}

@end
