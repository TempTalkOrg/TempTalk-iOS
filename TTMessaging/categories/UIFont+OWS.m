//
//  Copyright (c) 2019 Open Whisper Systems. All rights reserved.
//

#import "UIFont+OWS.h"
#import <TTMessaging/TTMessaging-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation UIFont (OWS)

+ (UIFont *)ows_thinFontWithSize:(CGFloat)size
{
    return [UIFont systemFontOfSize:size weight:UIFontWeightThin];
}

+ (UIFont *)ows_lightFontWithSize:(CGFloat)size
{
    return [UIFont systemFontOfSize:size weight:UIFontWeightLight];
}

+ (UIFont *)ows_regularFontWithSize:(CGFloat)size
{
    UIFont *font = [UIFont systemFontOfSize:size weight:UIFontWeightRegular];
    return [font scaledWithShouldScale:YES];
}

+ (UIFont *)ows_semiboldFontWithSize:(CGFloat)size
{
    UIFont *font = [UIFont systemFontOfSize:size weight:UIFontWeightSemibold];
    return [font scaledWithShouldScale:YES];
}

+ (UIFont *)ows_monospacedDigitFontWithSize:(CGFloat)size
{
    return [self monospacedDigitSystemFontOfSize:size weight:UIFontWeightRegular];
}

#pragma mark - Icon Fonts

+ (UIFont *)ows_fontAwesomeFont:(CGFloat)size
{
    return [UIFont fontWithName:@"FontAwesome" size:size];
}

+ (UIFont *)ows_dripIconsFont:(CGFloat)size
{
    return [UIFont fontWithName:@"dripicons-v2" size:size];
}

+ (UIFont *)ows_elegantIconsFont:(CGFloat)size
{
    return [UIFont fontWithName:@"ElegantIcons" size:size];
}

#pragma mark - Dynamic Type

// 辅助方法：获取固定大小的字体（忽略系统 Dynamic Type）
+ (UIFont *)fixedSizeFontForTextStyle:(UIFontTextStyle)fontTextStyle
{
    static NSDictionary<UIFontTextStyle, NSNumber *> *basePointSizeMap = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableDictionary<UIFontTextStyle, NSNumber *> *map = [@{
            UIFontTextStyleTitle1 : @(28.0),      // 固定 28pt
            UIFontTextStyleTitle2 : @(22.0),      // 固定 22pt
            UIFontTextStyleTitle3 : @(20.0),      // 固定 20pt
            UIFontTextStyleHeadline : @(17.0),    // 固定 17pt (semibold)
            UIFontTextStyleBody : @(17.0),        // 固定 17pt
            UIFontTextStyleSubheadline : @(15.0), // 固定 15pt
            UIFontTextStyleFootnote : @(13.0),    // 固定 13pt
            UIFontTextStyleCaption1 : @(12.0),    // 固定 12pt
            UIFontTextStyleCaption2 : @(11.0),    // 固定 11pt
        } mutableCopy];
        if (@available(iOS 11.0, *)) {
            map[UIFontTextStyleLargeTitle] = @(34.0);  // 固定 34pt
        }
        basePointSizeMap = map;
    });

    NSNumber *_Nullable basePointSize = basePointSizeMap[fontTextStyle];
    if (!basePointSize) {
        OWSFailDebug(@"Missing base point size for style: %@", fontTextStyle);
        return [UIFont systemFontOfSize:17.0]; // Fallback
    }

    return [UIFont systemFontOfSize:basePointSize.floatValue];
}

+ (UIFont *)ows_dynamicTypeTitle1Font
{
    UIFont *font = [UIFont fixedSizeFontForTextStyle:UIFontTextStyleTitle1];
    return [font scaledWithShouldScale:YES];
}

+ (UIFont *)ows_dynamicTypeTitle2Font
{
    UIFont *font = [UIFont fixedSizeFontForTextStyle:UIFontTextStyleTitle2];
    return [font scaledWithShouldScale:YES];
}

+ (UIFont *)ows_dynamicTypeTitle3Font
{
    UIFont *font = [UIFont fixedSizeFontForTextStyle:UIFontTextStyleTitle3];
    return [font scaledWithShouldScale:YES];
}

+ (UIFont *)ows_dynamicTypeHeadlineFont
{
    UIFont *font = [UIFont fixedSizeFontForTextStyle:UIFontTextStyleHeadline];
    return [font scaledWithShouldScale:YES];
}

+ (UIFont *)ows_dynamicTypeBodyFont
{
    UIFont *font = [UIFont fixedSizeFontForTextStyle:UIFontTextStyleBody];
    return [font scaledWithShouldScale:YES];
}

+ (UIFont *)ows_dynamicTypeBody2Font
{
    return self.ows_dynamicTypeSubheadlineFont;
}

+ (UIFont *)ows_dynamicTypeSubheadlineFont
{
    UIFont *font = [UIFont fixedSizeFontForTextStyle:UIFontTextStyleSubheadline];
    return [font scaledWithShouldScale:YES];
}

+ (UIFont *)ows_dynamicTypeFootnoteFont
{
    UIFont *font = [UIFont fixedSizeFontForTextStyle:UIFontTextStyleFootnote];
    return [font scaledWithShouldScale:YES];
}

+ (UIFont *)ows_dynamicTypeCaption1Font
{
    UIFont *font = [UIFont fixedSizeFontForTextStyle:UIFontTextStyleCaption1];
    return [font scaledWithShouldScale:YES];
}

+ (UIFont *)ows_dynamicTypeCaption2Font
{
    UIFont *font = [UIFont fixedSizeFontForTextStyle:UIFontTextStyleCaption2];
    return [font scaledWithShouldScale:YES];
}

#pragma mark - Dynamic Type Clamped

+ (UIFont *)preferredFontForTextStyleClamped:(UIFontTextStyle)fontTextStyle
{
    // 使用固定的基础字体大小，忽略系统的辅助功能设置
    // App 内的字体大小完全由 TextSizeManager 控制
    UIFont *baseFont = [UIFont fixedSizeFontForTextStyle:fontTextStyle];

    // 应用 App 内的自定义缩放（1.4x for large font mode）
    UIFont *scaledFont = [baseFont scaledWithShouldScale:YES];

    return scaledFont;
}

+ (UIFont *)ows_dynamicTypeLargeTitle1ClampedFont
{
    if (@available(iOS 11.0, *)) {
        return [UIFont preferredFontForTextStyleClamped:UIFontTextStyleLargeTitle];
    } else {
        return [UIFont preferredFontForTextStyleClamped:UIFontTextStyleTitle1];
    }
}

+ (UIFont *)ows_dynamicTypeTitle1ClampedFont
{
    return [UIFont preferredFontForTextStyleClamped:UIFontTextStyleTitle1];
}

+ (UIFont *)ows_dynamicTypeTitle2ClampedFont
{
    return [UIFont preferredFontForTextStyleClamped:UIFontTextStyleTitle2];
}

+ (UIFont *)ows_dynamicTypeTitle3ClampedFont
{
    return [UIFont preferredFontForTextStyleClamped:UIFontTextStyleTitle3];
}

+ (UIFont *)ows_dynamicTypeHeadlineClampedFont
{
    return [UIFont preferredFontForTextStyleClamped:UIFontTextStyleHeadline];
}

+ (UIFont *)ows_dynamicTypeBodyClampedFont
{
    return [UIFont preferredFontForTextStyleClamped:UIFontTextStyleBody];
}

+ (UIFont *)ows_dynamicTypeSubheadlineClampedFont
{
    return [UIFont preferredFontForTextStyleClamped:UIFontTextStyleSubheadline];
}

+ (UIFont *)ows_dynamicTypeFootnoteClampedFont
{
    return [UIFont preferredFontForTextStyleClamped:UIFontTextStyleFootnote];
}

+ (UIFont *)ows_dynamicTypeCaption1ClampedFont
{
    return [UIFont preferredFontForTextStyleClamped:UIFontTextStyleCaption1];
}

+ (UIFont *)ows_dynamicTypeCaption2ClampedFont
{
    return [UIFont preferredFontForTextStyleClamped:UIFontTextStyleCaption2];
}

#pragma mark - Styles

- (UIFont *)ows_italic
{
    return [self styleWithSymbolicTraits:UIFontDescriptorTraitItalic];
}

- (UIFont *)styleWithSymbolicTraits:(UIFontDescriptorSymbolicTraits)symbolicTraits
{
    UIFontDescriptor *fontDescriptor = [self.fontDescriptor fontDescriptorWithSymbolicTraits:symbolicTraits];
    UIFont *font = [UIFont fontWithDescriptor:fontDescriptor size:0];
    OWSAssertDebug(font);
    return font ?: self;
}

- (UIFont *)ows_semibold
{
    // The recommended approach of deriving "semibold" weight fonts for dynamic
    // type fonts is:
    //
    // [UIFontDescriptor fontDescriptorByAddingAttributes:...]
    //
    // But this doesn't seem to work in practice on iOS 11 using UIFontWeightSemibold.
    
    UIFont *derivedFont = [UIFont systemFontOfSize:self.pointSize weight:UIFontWeightSemibold];
    return derivedFont;
}

- (UIFont *)ows_monospaced
{
    return [self.class ows_monospacedDigitFontWithSize:self.pointSize];
}


@end

NS_ASSUME_NONNULL_END

