//
//  ConversationText.swift
//  Difft
//
//  Created by Jaymin on 2024/7/15.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit
import TTServiceKit

enum CVTextValue: Equatable, Hashable {
    typealias CacheKey = String

    case text(String)
    case attributedText(NSAttributedString)

    var isEmpty: Bool {
        switch self {
        case .text(let text):
            return text.isEmpty
        case .attributedText(let attributedText):
            return attributedText.isEmpty
        }
    }

    var nilIfEmpty: CVTextValue? {
        return self.isEmpty ? nil : self
    }

    var length: Int {
        switch self {
        case .text(let text):
            return (text as NSString).length
        case .attributedText(let attributedText):
            return attributedText.length
        }
    }

    var cacheKey: CacheKey {
        switch self {
        case .text(let text):
            return "t\(text)"
        case .attributedText(let attributedText):
            return "a\(attributedText.description)"
        }
    }
}

// MARK: -

struct CVLabelConfig {
    typealias CacheKey = String

    let text: CVTextValue
    let font: UIFont?
    let textColor: UIColor?
    let numberOfLines: Int
    let lineBreakMode: NSLineBreakMode
    let textAlignment: NSTextAlignment?
    
    static let defaultFontForUnstyledText: UIFont = .systemFont(ofSize: 17)
    
    var attributedText: NSAttributedString {
        switch text {
        case .attributedText(let attributedString):
            var result: NSAttributedString = attributedString
            if let font {
                let newAttributedString = NSMutableAttributedString(attributedString: attributedString)
                newAttributedString.addAttribute(.font, value: font, range: NSMakeRange(0, attributedString.length))
                result = newAttributedString
            }
            return result
        case .text(let text):
            let font = self.font ?? Self.defaultFontForUnstyledText
            return NSAttributedString(string: text, attributes: [.font: font])
        }
    }
    
    static let empty: CVLabelConfig = .unstyledText(.empty, font: Self.defaultFontForUnstyledText)

    init(
        text: CVTextValue,
        font: UIFont?,
        textColor: UIColor?,
        numberOfLines: Int,
        lineBreakMode: NSLineBreakMode,
        textAlignment: NSTextAlignment?
    ) {
        self.text = text
        self.font = font
        self.textColor = textColor
        self.numberOfLines = numberOfLines
        self.lineBreakMode = lineBreakMode
        self.textAlignment = textAlignment
    }
    
    static func unstyledText(
        _ text: String,
        font: UIFont,
        textColor: UIColor? = nil,
        numberOfLines: Int = 1,
        lineBreakMode: NSLineBreakMode = .byWordWrapping,
        textAlignment: NSTextAlignment? = nil
    ) -> Self {
        return .init(
            text: .text(text),
            font: font,
            textColor: textColor,
            numberOfLines: numberOfLines,
            lineBreakMode: lineBreakMode,
            textAlignment: textAlignment
        )
    }
    
    static func attributeText(
        _ attributedText: NSAttributedString,
        font: UIFont? = nil,
        textColor: UIColor? = nil,
        numberOfLines: Int = 1,
        lineBreakMode: NSLineBreakMode = .byWordWrapping,
        textAlignment: NSTextAlignment? = nil
    ) -> Self {
        return .init(
            text: .attributedText(attributedText),
            font: font,
            textColor: textColor,
            numberOfLines: numberOfLines,
            lineBreakMode: lineBreakMode,
            textAlignment: textAlignment
        )
    }

    func applyForRendering(label: UILabel) {
        label.font = font
        if let textColor {
            label.textColor = textColor
        }
        label.numberOfLines = self.numberOfLines
        label.lineBreakMode = self.lineBreakMode

        if let textAlignment = textAlignment {
            label.textAlignment = textAlignment
        } else {
            label.textAlignment = .natural
        }

        // Apply text last, to protect attributed text attributes.
        // There are also perf benefits.
        switch text {
        case .text(let text):
            label.text = text
        case .attributedText(let attributedText):
            label.attributedText = attributedText
        }
    }

    func applyForRendering(button: UIButton) {
        button.titleLabel?.font = font
        if let textColor {
            button.setTitleColor(textColor, for: .normal)
        }
        button.titleLabel?.numberOfLines = self.numberOfLines
        button.titleLabel?.lineBreakMode = self.lineBreakMode

        if let textAlignment = textAlignment {
            button.titleLabel?.textAlignment = textAlignment
        } else {
            button.titleLabel?.textAlignment = .natural
        }

        switch text {
        case .text(let text):
            button.setTitle(text, for: .normal)
        case .attributedText(let attributedText):
            button.setAttributedTitle(attributedText, for: .normal)
        }
    }

    func measure(maxWidth: CGFloat) -> CGSize {
        let size = CVText.measureLabelSize(labelConfig: self, maxWidth: maxWidth)
        if size.width > maxWidth {
            owsFailDebug("size.width: \(size.width) > maxWidth: \(maxWidth)")
        }
        return size
    }

    var cacheKey: CacheKey {
        switch text {
        case .text(_):
            // textColor doesn't affect measurement.
            let font = self.font ?? Self.defaultFontForUnstyledText
            return "\(text.cacheKey),\(font.fontName),\(font.pointSize),\(numberOfLines),\(lineBreakMode.rawValue),\(textAlignment?.rawValue ?? 0)"
        case .attributedText(_):
            if let font {
                return "\(text.cacheKey),\(font.fontName),\(font.pointSize),\(numberOfLines),\(lineBreakMode.rawValue),\(textAlignment?.rawValue ?? 0)"
            }
            return "\(text.cacheKey),\(numberOfLines),\(lineBreakMode.rawValue),\(textAlignment?.rawValue ?? 0)"
        }
    }
}

struct CVTextViewConfig {
    typealias CacheKey = String
    
    let text: CVTextValue
    let font: UIFont?
    let textColor: UIColor?
    let maximumNumberOfLines: Int
    let lineBreakMode: NSLineBreakMode
    let textAlignment: NSTextAlignment?
    let linkTextAttributes: [NSAttributedString.Key : Any]
    let shouldIgnoreEvents: Bool
    let textContainerInset: UIEdgeInsets
    
    static let defaultFontForUnstyledText: UIFont = .systemFont(ofSize: 17)
    
    var attributedText: NSAttributedString {
        switch text {
        case .attributedText(let attributedString):
            var result: NSAttributedString = attributedString
            if let font {
                let newAttributedString = NSMutableAttributedString(attributedString: attributedString)
                newAttributedString.addAttribute(.font, value: font, range: NSMakeRange(0, attributedString.length))
                result = newAttributedString
            }
            return result
        case .text(let text):
            let font = self.font ?? Self.defaultFontForUnstyledText
            return NSAttributedString(string: text, attributes: [.font: font])
        }
    }
    
    static let empty: CVTextViewConfig = .unstyledText(.empty, font: Self.defaultFontForUnstyledText)
    
    init(
        text: CVTextValue,
        font: UIFont?,
        textColor: UIColor?,
        maximumNumberOfLines: Int,
        lineBreakMode: NSLineBreakMode,
        textAlignment: NSTextAlignment?,
        linkTextAttributes: [NSAttributedString.Key : Any],
        shouldIgnoreEvents: Bool,
        textContainerInset: UIEdgeInsets
    ) {
        self.text = text
        self.font = font
        self.textColor = textColor
        self.maximumNumberOfLines = maximumNumberOfLines
        self.lineBreakMode = lineBreakMode
        self.textAlignment = textAlignment
        self.linkTextAttributes = linkTextAttributes
        self.shouldIgnoreEvents = shouldIgnoreEvents
        self.textContainerInset = textContainerInset
    }
    
    static func unstyledText(
        _ text: String,
        font: UIFont,
        textColor: UIColor? = nil,
        maximumNumberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byWordWrapping,
        textAlignment: NSTextAlignment? = nil,
        linkTextAttributes: [NSAttributedString.Key : Any] = [:],
        shouldIgnoreEvents: Bool = false,
        textContainerInset: UIEdgeInsets = .zero
    ) -> Self {
        return .init(
            text: .text(text),
            font: font,
            textColor: textColor,
            maximumNumberOfLines: maximumNumberOfLines,
            lineBreakMode: lineBreakMode,
            textAlignment: textAlignment,
            linkTextAttributes: linkTextAttributes,
            shouldIgnoreEvents: shouldIgnoreEvents,
            textContainerInset: textContainerInset
        )
    }
    
    static func attributeText(
        _ attributedText: NSAttributedString,
        font: UIFont? = nil,
        textColor: UIColor? = nil,
        maximumNumberOfLines: Int = 0,
        lineBreakMode: NSLineBreakMode = .byWordWrapping,
        textAlignment: NSTextAlignment? = nil,
        linkTextAttributes: [NSAttributedString.Key : Any] = [:],
        shouldIgnoreEvents: Bool = false,
        textContainerInset: UIEdgeInsets = .zero
    ) -> Self {
        return .init(
            text: .attributedText(attributedText),
            font: font,
            textColor: textColor,
            maximumNumberOfLines: maximumNumberOfLines,
            lineBreakMode: lineBreakMode,
            textAlignment: textAlignment,
            linkTextAttributes: linkTextAttributes,
            shouldIgnoreEvents: shouldIgnoreEvents,
            textContainerInset: textContainerInset
        )
    }

    func applyForRendering(textView: UITextView) {
        textView.font = font
        if let textColor {
            textView.textColor = textColor
        }
        textView.textContainer.maximumNumberOfLines = self.maximumNumberOfLines
        textView.textContainer.lineBreakMode = self.lineBreakMode
        textView.linkTextAttributes = self.linkTextAttributes
        textView.textContainerInset = self.textContainerInset
        
        if let messageTextView = textView as? OWSMessageTextView {
            messageTextView.shouldIgnoreEvents = self.shouldIgnoreEvents
        }

        if let textAlignment = textAlignment {
            textView.textAlignment = textAlignment
        } else {
            textView.textAlignment = .natural
        }

        // Apply text last, to protect attributed text attributes.
        // There are also perf benefits.
        switch text {
        case .text(let text):
            textView.text = text
        case .attributedText(let attributedText):
            textView.attributedText = attributedText
        }
    }

    func measure(maxWidth: CGFloat) -> CGSize {
        let size = CVText.measureTextViewSize(textViewConfig: self, maxWidth: maxWidth)
        if size.width > maxWidth {
            owsFailDebug("size.width: \(size.width) > maxWidth: \(maxWidth)")
        }
        return size
    }
    
    func measureLastLine(maxWidth: CGFloat) -> CGSize {
        let size = CVText.measureLastLineSize(textViewConfig: self, maxWidth: maxWidth)
        if size.width > maxWidth {
            owsFailDebug("size.width: \(size.width) > maxWidth: \(maxWidth)")
        }
        return size
    }

    var cacheKey: CacheKey {
        switch text {
        case .text(_):
            // textColor doesn't affect measurement.
            let font = self.font ?? Self.defaultFontForUnstyledText
            return "\(text.cacheKey),\(font.fontName),\(font.pointSize),\(maximumNumberOfLines),\(lineBreakMode.rawValue),\(textAlignment?.rawValue ?? 0)"
        case .attributedText(_):
            if let font {
                return "\(text.cacheKey),\(font.fontName),\(font.pointSize),\(maximumNumberOfLines),\(lineBreakMode.rawValue),\(textAlignment?.rawValue ?? 0)"
            }
            return "\(text.cacheKey),\(maximumNumberOfLines),\(lineBreakMode.rawValue),\(textAlignment?.rawValue ?? 0)"
        }
    }
}

// MARK: -

class CVText {
    typealias CacheKey = String

    private static var cacheMeasurements = true

    private static let cacheSize: Int = 500

    private static func buildCacheKey(configKey: String, maxWidth: CGFloat) -> CacheKey {
        "\(configKey),\(maxWidth)"
    }
    private static let sizeCache = LRUCache<CacheKey, CGSize>(maxSize: cacheSize)

    // MARK: Measure Label Size
    
    static func measureLabelSize(labelConfig: CVLabelConfig, maxWidth: CGFloat) -> CGSize {
        let cacheKey = buildCacheKey(configKey: labelConfig.cacheKey, maxWidth: maxWidth)
        if cacheMeasurements,
           let result = sizeCache.get(key: cacheKey) {
            return result
        }

        let result = measureLabelSizeWithLayoutManager(labelConfig: labelConfig, maxWidth: maxWidth)
        owsAssertDebug(result.isNonEmpty || labelConfig.text.isEmpty)

        if cacheMeasurements {
            sizeCache.set(key: cacheKey, value: result.ceil)
        }

        return result.ceil
    }

    static func measureLabelSizeWithLayoutManager(labelConfig: CVLabelConfig, maxWidth: CGFloat) -> CGSize {
        guard !labelConfig.text.isEmpty else {
            return .zero
        }
        
        let textContainer = NSTextContainer(size: CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        textContainer.maximumNumberOfLines = labelConfig.numberOfLines
        textContainer.lineBreakMode = labelConfig.lineBreakMode
        textContainer.lineFragmentPadding = 0
        return textContainer.size(for: labelConfig.attributedText)
    }
    
    
    // MARK: Measure TextView Size
    
    static func measureLastLineSize(textViewConfig: CVTextViewConfig, maxWidth: CGFloat) -> CGSize {
        let cacheKey = buildCacheKey(configKey: "lastLine" + textViewConfig.cacheKey, maxWidth: maxWidth)
        if cacheMeasurements,
           let result = sizeCache.get(key: cacheKey) {
            return result
        }

        let result = measureLastLineWithLayoutManager(textViewConfig: textViewConfig, maxWidth: maxWidth)
        owsAssertDebug(result.isNonEmpty || textViewConfig.text.isEmpty)

        if cacheMeasurements {
            sizeCache.set(key: cacheKey, value: result.ceil)
        }

        return result.ceil
    }
    
    static func measureLastLineWithLayoutManager(textViewConfig: CVTextViewConfig, maxWidth: CGFloat) -> CGSize {
        guard !textViewConfig.text.isEmpty else {
            return .zero
        }
        
        let textContainer = NSTextContainer(size: CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        textContainer.maximumNumberOfLines = textViewConfig.maximumNumberOfLines
        textContainer.lineBreakMode = textViewConfig.lineBreakMode
        textContainer.lineFragmentPadding = 0
        return textContainer.lastLineSize(for: textViewConfig.attributedText)
    }
    
    static func measureTextViewSize(textViewConfig: CVTextViewConfig, maxWidth: CGFloat) -> CGSize {
        let cacheKey = buildCacheKey(configKey: textViewConfig.cacheKey, maxWidth: maxWidth)
        if cacheMeasurements,
           let result = sizeCache.get(key: cacheKey) {
            return result
        }

        let result = measureTextViewSizeWithLayoutManager(textViewConfig: textViewConfig, maxWidth: maxWidth)
        owsAssertDebug(result.isNonEmpty || textViewConfig.text.isEmpty)

        if cacheMeasurements {
            sizeCache.set(key: cacheKey, value: result.ceil)
        }

        return result.ceil
    }

    static func measureTextViewSizeWithLayoutManager(textViewConfig: CVTextViewConfig, maxWidth: CGFloat) -> CGSize {
        guard !textViewConfig.text.isEmpty else {
            return .zero
        }
        
        let textContainer = NSTextContainer(size: CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        textContainer.maximumNumberOfLines = textViewConfig.maximumNumberOfLines
        textContainer.lineBreakMode = textViewConfig.lineBreakMode
        textContainer.lineFragmentPadding = 0
        return textContainer.size(for: textViewConfig.attributedText)
    }
}

// MARK: -

private extension NSTextContainer {
    
    func size(for attributedString: NSAttributedString) -> CGSize {
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(self)

        // The string must be assigned to the NSTextStorage *after* it has
        // an associated layout manager. Otherwise, the `NSOriginalFont`
        // attribute will not be defined correctly resulting in incorrect
        // measurement of character sets that font doesn't support natively
        // (CJK, Arabic, Emoji, etc.)
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)
        textStorage.setAttributedString(attributedString)

        // The NSTextStorage object owns all the other layout components,
        // so there are only weak references to it. In optimized builds,
        // this can result in it being freed before we perform measurement.
        // We can work around this by explicitly extending the lifetime of
        // textStorage until measurement is completed.
        let size = withExtendedLifetime(textStorage) { layoutManager.usedRect(for: self).size }

        return size.ceil
    }
    
    func lastLineSize(for attributedString: NSAttributedString) -> CGSize {
        let layoutManager = NSLayoutManager()
        layoutManager.addTextContainer(self)

        // The string must be assigned to the NSTextStorage *after* it has
        // an associated layout manager. Otherwise, the `NSOriginalFont`
        // attribute will not be defined correctly resulting in incorrect
        // measurement of character sets that font doesn't support natively
        // (CJK, Arabic, Emoji, etc.)
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)
        textStorage.setAttributedString(attributedString)

        // 获取最后一行的宽度
        var lastLineSize = CGSizeZero
        layoutManager.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: attributedString.length)) { (_, usedRect, _, _, stop) in
            lastLineSize = usedRect.size
        }

        return lastLineSize
    }
}
