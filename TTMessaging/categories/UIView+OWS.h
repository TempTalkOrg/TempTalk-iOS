//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import <PureLayout/PureLayout.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// A set of helper methods for doing layout with PureLayout.
@interface UIView (OWS)

// Pins the width of this view to the width of its superview, with uniform margins.
- (NSArray<NSLayoutConstraint *> *)autoPinWidthToSuperviewWithMargin:(CGFloat)margin;
- (NSArray<NSLayoutConstraint *> *)autoPinWidthToSuperview;
// Pins the height of this view to the height of its superview, with uniform margins.
- (NSArray<NSLayoutConstraint *> *)autoPinHeightToSuperviewWithMargin:(CGFloat)margin;
- (NSArray<NSLayoutConstraint *> *)autoPinHeightToSuperview;

- (NSArray<NSLayoutConstraint *> *)ows_autoPinToSuperviewEdges;
- (NSArray<NSLayoutConstraint *> *)ows_autoPinToSuperviewMargins;

- (NSLayoutConstraint *)autoHCenterInSuperview;
- (NSLayoutConstraint *)autoVCenterInSuperview;

- (void)autoPinWidthToWidthOfView:(UIView *)view;
- (void)autoPinHeightToHeightOfView:(UIView *)view;

- (NSLayoutConstraint *)autoPinToSquareAspectRatio;
- (NSLayoutConstraint *)autoPinToAspectRatio:(CGFloat)ratio;

#pragma mark - Content Hugging and Compression Resistance

- (void)setContentHuggingLow;
- (void)setContentHuggingMedium;
- (void)setContentHuggingHigh;
- (void)setContentHuggingHorizontalLow;
- (void)setContentHuggingHorizontalMedium;
- (void)setContentHuggingHorizontalHigh;
- (void)setContentHuggingVerticalLow;
- (void)setContentHuggingVerticalMedium;
- (void)setContentHuggingVerticalHigh;


- (void)setCompressionResistanceLow;
- (void)setCompressionResistanceMedium;
- (void)setCompressionResistanceHigh;
- (void)setCompressionResistanceHorizontalLow;
- (void)setCompressionResistanceHorizontalMedium;
- (void)setCompressionResistanceHorizontalHigh;
- (void)setCompressionResistanceVerticalLow;
- (void)setCompressionResistanceVerticalMedium;
- (void)setCompressionResistanceVerticalHigh;


#pragma mark - Manual Layout

- (CGFloat)left;
- (CGFloat)right;
- (CGFloat)top;
- (CGFloat)bottom;
- (CGFloat)width;
- (CGFloat)height;

- (void)centerOnSuperview;

#pragma mark - RTL

// For correct right-to-left layout behavior, use "leading" and "trailing",
// not "left" and "right".
//
// These methods use layoutMarginsGuide anchors, which behave differently than
// the PureLayout alternatives you indicated. Honoring layoutMargins is
// particularly important in cell layouts, where it lets us align with the
// complicated built-in behavior of table and collection view cells' default
// contents.
//
// NOTE: the margin values are inverted in RTL layouts.

- (NSArray<NSLayoutConstraint *> *)autoPinLeadingAndTrailingToSuperviewMargin;
- (NSLayoutConstraint *)autoPinLeadingToSuperviewMargin;
- (NSLayoutConstraint *)autoPinLeadingToSuperviewMarginWithInset:(CGFloat)margin;
- (NSLayoutConstraint *)autoPinTrailingToSuperviewMargin;
- (NSLayoutConstraint *)autoPinTrailingToSuperviewMarginWithInset:(CGFloat)margin;

- (NSLayoutConstraint *)autoPinTopToSuperviewMargin;
- (NSLayoutConstraint *)autoPinTopToSuperviewMarginWithInset:(CGFloat)margin;
- (NSLayoutConstraint *)autoPinBottomToSuperviewMargin;
- (NSLayoutConstraint *)autoPinBottomToSuperviewMarginWithInset:(CGFloat)margin;

- (NSLayoutConstraint *)autoPinLeadingToTrailingEdgeOfView:(UIView *)view;
- (NSLayoutConstraint *)autoPinLeadingToTrailingEdgeOfView:(UIView *)view offset:(CGFloat)margin;
- (NSLayoutConstraint *)autoPinTrailingToLeadingEdgeOfView:(UIView *)view;
- (NSLayoutConstraint *)autoPinTrailingToLeadingEdgeOfView:(UIView *)view offset:(CGFloat)margin;
- (NSLayoutConstraint *)autoPinLeadingToEdgeOfView:(UIView *)view;
- (NSLayoutConstraint *)autoPinLeadingToEdgeOfView:(UIView *)view offset:(CGFloat)margin;
- (NSLayoutConstraint *)autoPinTrailingToEdgeOfView:(UIView *)view;
- (NSLayoutConstraint *)autoPinTrailingToEdgeOfView:(UIView *)view offset:(CGFloat)margin;
// Return Right on LTR and Left on RTL.
- (NSTextAlignment)textAlignmentUnnatural;
// Leading and trailing anchors honor layout margins.
// When using a UIView as a "div" to structure layout, we don't want it to have margins.
- (void)setHLayoutMargins:(CGFloat)value;

- (NSArray<NSLayoutConstraint *> *)autoPinToEdgesOfView:(UIView *)view;

#pragma mark - Containers

+ (UIView *)containerView;

+ (UIView *)verticalStackWithSubviews:(NSArray<UIView *> *)subviews spacing:(int)spacing;

#pragma mark - Debugging

- (void)addBorderWithColor:(UIColor *)color;
- (void)addRedBorder;

// Add red border to self, and all subviews recursively.
- (void)addRedBorderRecursively;

#ifdef DEBUG
- (void)logFrame;
- (void)logFrameWithLabel:(NSString *)label;
- (void)logFrameLater;
- (void)logFrameLaterWithLabel:(NSString *)label;
- (void)logHierarchyUpwardLaterWithLabel:(NSString *)label;
#endif

@end

#pragma mark -

@interface UIScrollView (OWS)

// Returns YES if contentInsetAdjustmentBehavior is disabled.
- (BOOL)applyScrollViewInsetsFix;

@end

#pragma mark -

@interface UIStackView (OWS)

- (void)addBackgroundViewWithBackgroundColor:(UIColor *)backgroundColor;

@end

NS_ASSUME_NONNULL_END
