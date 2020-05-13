// Copyright 2020 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef IOS_CHROME_COMMON_UI_UTIL_POINTER_INTERACTION_UTIL_H_
#define IOS_CHROME_COMMON_UI_UTIL_POINTER_INTERACTION_UTIL_H_

#import <UIKit/UIKit.h>

#if defined(__IPHONE_13_4)
// Returns a pointer style provider that has the default hover effect and a
// circle pointer shape.
UIButtonPointerStyleProvider CreateDefaultEffectCirclePointerStyleProvider()
    API_AVAILABLE(ios(13.4));

// Returns a pointer style provider that has the lift hover effect and a circle
// pointer shape.
UIButtonPointerStyleProvider CreateLiftEffectCirclePointerStyleProvider()
    API_AVAILABLE(ios(13.4));

// Returns a pointer style provider that is best for opaque buttons, such as the
// primary action buttons which have a blue background and white text.
// By default, UIKit creates inconsistent hover effects for buttons with opaque
// backgrounds depending on the size of the button. Wide buttons get a weird
// mousing highlight effect on just the label. This function should be used for
// all opaque buttons to ensure that various sizes have consistent effects. This
// effect has a slight background color tint, with no shadow nor scale nor
// pointer shape change.
UIButtonPointerStyleProvider CreateOpaqueButtonPointerStyleProvider()
    API_AVAILABLE(ios(13.4));

// Returns a pointer style provider that is best for transparent buttons, such
// as secondary action buttons which have a transparent background and blue
// text. By default, UIKit chooses the best size of the highlight pointer shape.
// Small buttons get a highlight pointer shape of the whole button. Wide buttons
// get a highlight pointer of just the label. To fix this, a custom pointer
// shape is set with the size of the button. This function should be used for
// wide transparent buttons, especially if the size of the button is set larger
// than the intrinsic size of the text label. It is not needed for very small
// buttons.
UIButtonPointerStyleProvider CreateTransparentButtonPointerStyleProvider()
    API_AVAILABLE(ios(13.4));

// Returns either an opaque or transparent button pointer style based on the
// button's background color at runtime. This function is useful for generic
// components with a button that may be styled differently in different use
// cases.
UIButtonPointerStyleProvider
CreateOpaqueOrTransparentButtonPointerStyleProvider() API_AVAILABLE(ios(13.4));
#endif  // defined(__IPHONE_13_4)

#endif  // IOS_CHROME_COMMON_UI_UTIL_POINTER_INTERACTION_UTIL_H_
