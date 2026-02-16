//
//  UIFont+DynamicType.swift
//  TTMessaging
//
//  Created by Henry on 2026/01/12.
//  Copyright © 2026 Difft. All rights reserved.
//

import UIKit

/// UIFont extension for easy dynamic type support
public extension UIFont {

    // MARK: - Dynamic Type Fonts

    /// 获取固定大小的字体（忽略系统 Dynamic Type）
    private static func dt_fixedSizeFont(forTextStyle textStyle: UIFont.TextStyle) -> UIFont {
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

    /// Body text (17pt default)
    @objc static var dt_body: UIFont {
        return dt_fixedSizeFont(forTextStyle: .body).scaled()
    }

    /// Headline text (17pt semibold default)
    @objc static var dt_headline: UIFont {
        return dt_fixedSizeFont(forTextStyle: .headline).scaled()
    }

    /// Subheadline text (15pt default)
    @objc static var dt_subheadline: UIFont {
        return dt_fixedSizeFont(forTextStyle: .subheadline).scaled()
    }

    /// Footnote text (13pt default)
    @objc static var dt_footnote: UIFont {
        return dt_fixedSizeFont(forTextStyle: .footnote).scaled()
    }

    /// Caption 1 text (12pt default)
    @objc static var dt_caption1: UIFont {
        return dt_fixedSizeFont(forTextStyle: .caption1).scaled()
    }

    /// Caption 2 text (11pt default)
    @objc static var dt_caption2: UIFont {
        return dt_fixedSizeFont(forTextStyle: .caption2).scaled()
    }

    /// Callout text (16pt default)
    @objc static var dt_callout: UIFont {
        return dt_fixedSizeFont(forTextStyle: .callout).scaled()
    }

    /// Title 1 text (28pt default)
    @objc static var dt_title1: UIFont {
        return dt_fixedSizeFont(forTextStyle: .title1).scaled()
    }

    /// Title 2 text (22pt default)
    @objc static var dt_title2: UIFont {
        return dt_fixedSizeFont(forTextStyle: .title2).scaled()
    }

    /// Title 3 text (20pt default)
    @objc static var dt_title3: UIFont {
        return dt_fixedSizeFont(forTextStyle: .title3).scaled()
    }

    /// Large title text (34pt default)
    @objc static var dt_largeTitle: UIFont {
        return dt_fixedSizeFont(forTextStyle: .largeTitle).scaled()
    }
}

/// UILabel extension for easy dynamic type setup
public extension UILabel {

    /// Set font for dynamic type
    @objc func dt_setFont(_ font: UIFont) {
        self.font = font
    }
}

/// UITextField extension for easy dynamic type setup
public extension UITextField {

    /// Set font for dynamic type
    @objc func dt_setFont(_ font: UIFont) {
        self.font = font
    }
}

/// UITextView extension for easy dynamic type setup
public extension UITextView {

    /// Set font for dynamic type
    @objc func dt_setFont(_ font: UIFont) {
        self.font = font
    }
}

/// UIButton extension for easy dynamic type setup
public extension UIButton {

    /// Set title label font for dynamic type
    @objc func dt_setTitleFont(_ font: UIFont) {
        titleLabel?.font = font
    }
}
