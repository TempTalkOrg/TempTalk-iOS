//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import SignalCoreKit
import UIKit

public extension UIFont {

    // MARK: - Icon Font

    class func awesomeFont(ofSize size: CGFloat) -> UIFont {
        return UIFont(name: "FontAwesome", size: size)!
    }

    // MARK: -

    class func regularFont(ofSize size: CGFloat) -> UIFont {
        return .systemFont(ofSize: size, weight: .regular)
    }

    class func semiboldFont(ofSize size: CGFloat) -> UIFont {
        return .systemFont(ofSize: size, weight: .semibold)
    }

    class func monospacedDigitFont(ofSize size: CGFloat) -> UIFont {
        return .monospacedDigitSystemFont(ofSize: size, weight: .regular)
    }

    // MARK: - Dynamic Type

    /// 获取固定大小的字体（忽略系统 Dynamic Type）
    private class func fixedSizeFont(forTextStyle textStyle: UIFont.TextStyle) -> UIFont {
        let baseSize: CGFloat
        switch textStyle {
        case .largeTitle:
            baseSize = 34.0
        case .title1:
            baseSize = 28.0
        case .title2:
            baseSize = 22.0
        case .title3:
            baseSize = 20.0
        case .headline:
            baseSize = 17.0
        case .body:
            baseSize = 17.0
        case .callout:
            baseSize = 16.0
        case .subheadline:
            baseSize = 15.0
        case .footnote:
            baseSize = 13.0
        case .caption1:
            baseSize = 12.0
        case .caption2:
            baseSize = 11.0
        default:
            baseSize = 17.0
        }
        return UIFont.systemFont(ofSize: baseSize)
    }

    class var dynamicTypeTitle1: UIFont {
        fixedSizeFont(forTextStyle: .title1).scaled()
    }

    class var dynamicTypeTitle2: UIFont {
        fixedSizeFont(forTextStyle: .title2).scaled()
    }

    class var dynamicTypeTitle3: UIFont {
        fixedSizeFont(forTextStyle: .title3).scaled()
    }

    class var dynamicTypeHeadline: UIFont {
        fixedSizeFont(forTextStyle: .headline).scaled()
    }

    class var dynamicTypeBody: UIFont {
        fixedSizeFont(forTextStyle: .body).scaled()
    }

    class var dynamicTypeBody2: UIFont {
        fixedSizeFont(forTextStyle: .subheadline).scaled()
    }

    class var dynamicTypeCallout: UIFont {
        fixedSizeFont(forTextStyle: .callout).scaled()
    }

    class var dynamicTypeSubheadline: UIFont {
        fixedSizeFont(forTextStyle: .subheadline).scaled()
    }

    class var dynamicTypeFootnote: UIFont {
        fixedSizeFont(forTextStyle: .footnote).scaled()
    }

    class var dynamicTypeCaption1: UIFont {
        fixedSizeFont(forTextStyle: .caption1).scaled()
    }

    class var dynamicTypeCaption2: UIFont {
        fixedSizeFont(forTextStyle: .caption2).scaled()
    }

    // MARK: - Dynamic Type Clamped

    private class func preferredFontClamped(forTextStyle textStyle: UIFont.TextStyle) -> UIFont {
        // 使用固定大小的字体，忽略系统 Dynamic Type
        let baseFont = fixedSizeFont(forTextStyle: textStyle)
        let scaledFont = baseFont.scaled()
        return scaledFont
    }

    class var dynamicTypeLargeTitle1Clamped: UIFont { preferredFontClamped(forTextStyle: .largeTitle) }
    class var dynamicTypeTitle1Clamped: UIFont { preferredFontClamped(forTextStyle: .title1) }
    class var dynamicTypeTitle2Clamped: UIFont { preferredFontClamped(forTextStyle: .title2) }
    class var dynamicTypeTitle3Clamped: UIFont { preferredFontClamped(forTextStyle: .title3) }
    class var dynamicTypeHeadlineClamped: UIFont { preferredFontClamped(forTextStyle: .headline) }
    class var dynamicTypeBodyClamped: UIFont { preferredFontClamped(forTextStyle: .body) }
    class var dynamicTypeBody2Clamped: UIFont { preferredFontClamped(forTextStyle: .subheadline) }
    class var dynamicTypeCalloutClamped: UIFont { preferredFontClamped(forTextStyle: .callout) }
    class var dynamicTypeSubheadlineClamped: UIFont { preferredFontClamped(forTextStyle: .subheadline) }
    class var dynamicTypeFootnoteClamped: UIFont { preferredFontClamped(forTextStyle: .footnote) }
    class var dynamicTypeCaption1Clamped: UIFont { preferredFontClamped(forTextStyle: .caption1) }
    class var dynamicTypeCaption2Clamped: UIFont { preferredFontClamped(forTextStyle: .caption2) }

    // MARK: -

    func italic() -> UIFont {
        guard let fontDescriptor = fontDescriptor.withSymbolicTraits(.traitItalic) else { return self }
        return UIFont(descriptor: fontDescriptor, size: 0)
    }

    func medium() -> UIFont {
        let fontTraits = [UIFontDescriptor.TraitKey.weight: UIFont.Weight.medium]
        let fontDescriptor = fontDescriptor.addingAttributes([.traits: fontTraits])
        return UIFont(descriptor: fontDescriptor, size: 0)
    }

    func semibold() -> UIFont {
        let fontTraits = [UIFontDescriptor.TraitKey.weight: UIFont.Weight.semibold]
        let fontDescriptor = fontDescriptor.addingAttributes([.traits: fontTraits])
        return UIFont(descriptor: fontDescriptor, size: 0)
    }

    func bold() -> UIFont {
        let fontTraits = [UIFontDescriptor.TraitKey.weight: UIFont.Weight.bold]
        let fontDescriptor = fontDescriptor.addingAttributes([.traits: fontTraits])
        return UIFont(descriptor: fontDescriptor, size: 0)
    }

    func monospaced() -> UIFont {
        return .monospacedDigitFont(ofSize: pointSize)
    }

}
