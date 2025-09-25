//
//  CVBodyTextRenderItem.swift
//  Difft
//
//  Created by Jaymin on 2024/7/31.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit

class CVBodyTextRenderItem: ConversationRenderItem {
    
    enum TextStyle {
        case normal
        case combinedForwarding
        case card
        case confidential
        case none
    }
    
    static let kVisitingCardScheme = "personinfocard"
    
    var bodyTextStyle: TextStyle = .none
    var bodyTextConfig: CVTextViewConfig?
    var hasTapForMore = false
    var confidentialEnable = true
    var lastLineSize = CGSizeZero
    
    private let isShowBodyMediaView: Bool
    private let singleForwardTitleWidth: CGFloat
    
    var bodyTextColor: UIColor {
        guard let message = viewItem.interaction as? TSMessage else {
            return ConversationStyle.bubbleTextColorOutgoing
        }
        
        if viewItem.isConfidentialMessage &&
            !message.isSingleForward() &&
            !message.isMultiForward() &&
            confidentialEnable {
            return UIColor.clear
        } else {
            return conversationStyle.bubbleTextColor(message: message)
        }
    }
    
    var isCombinedForwardingStyle: Bool {
        guard let message = viewItem.interaction as? TSMessage else {
            return false
        }
        guard let subForwardingMessages = message.combinedForwardingMessage?.subForwardingMessages else {
            return false
        }
        if subForwardingMessages.count > 1 ||
            (subForwardingMessages.count == 1 &&
             subForwardingMessages.first?.subForwardingMessages.count ?? 0 > 0) {
            return true
        }
        return false
    }
    
    init(
        viewItem: any ConversationViewItem,
        conversationStyle: ConversationStyle,
        isShowBodyMediaView: Bool,
        singleForwardTitleWidth: CGFloat
    ) {
        self.isShowBodyMediaView = isShowBodyMediaView
        self.singleForwardTitleWidth = singleForwardTitleWidth
        
        super.init(viewItem: viewItem, conversationStyle: conversationStyle)
    }
    
    override func configure() {
        let showBodyTextView = viewItem.hasBodyText || !isShowBodyMediaView
        if showBodyTextView, !isCombinedForwardingStyle, viewItem.messageCellType() != .card {
            if let (textConfig, hasTapMore) = getDefaultBodyTextConfig() {
                self.bodyTextStyle = .normal
                self.bodyTextConfig = textConfig
                self.hasTapForMore = hasTapMore
                self.viewSize = measureDefaultBodyTextSize(textConfig: textConfig)
                self.lastLineSize = measureDefaultBodyLastLineSize(textConfig: textConfig)
            }
        }
        
        if isCombinedForwardingStyle {
            if let textConfig = getCombinedForwardingBodyTextConfig() {
                self.bodyTextStyle = .combinedForwarding
                self.bodyTextConfig = textConfig
                self.viewSize = measureCombinedForwardingBodyTextSize(textConfig: textConfig)
            }
        }
        
        if viewItem.messageCellType() == .card {
            self.bodyTextStyle = .card
            let textConfig = getCardBodyTextConfig()
            self.bodyTextConfig = textConfig
            self.viewSize = measureCardBodyTextSize(textConfig: textConfig)
        }
        
        //call at last
        if viewItem.isConfidentialMessage && confidentialEnable {
            self.bodyTextStyle = .confidential
        }
    }
    
    func getDefaultBodyTextConfig() -> (textConfig: CVTextViewConfig, hasTapForMore: Bool)? {
        guard let displayableBodyText = viewItem.displayableBodyText() else {
            return nil
        }
        let text = displayableBodyText.displayText
        guard !text.isEmpty else {
            return nil
        }
        
        let font: UIFont = {
            let pointSize = UIFont.ows_dynamicTypeBody.pointSize
            switch(displayableBodyText.jumbomojiCount) {
            case 1:
                return .ows_regularFont(withSize: pointSize + 18)
            case 2:
                return .ows_regularFont(withSize: pointSize + 12)
            case 3, 4, 5:
                return .ows_regularFont(withSize: pointSize + 6)
            default:
                return .ows_dynamicTypeBody
            }
        }()
        let textColor = bodyTextColor
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 1
        let attributedString = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
        )
        
        DTPatternHelper.getForwardMessageSourceText(with: text, withCallBackCheckingResult: { resultArray in
            resultArray.forEach { result in
                let range = result.range(at: 0)
                if range.length > 0 {
                    let substring = text.substring(withRange: range)
                    let uid = DTPatternHelper.getForwardUidString(substring)
                    attributedString.addAttribute(
                        .link,
                        value: "\(Self.kVisitingCardScheme)://\(uid)",
                        range: range
                    )
                    attributedString.addAttribute(
                        .underlineStyle,
                        value: NSUnderlineStyle.single.rawValue,
                        range: range
                    )
                    attributedString.addAttribute(
                        .foregroundColor,
                        value: Theme.primaryTextColor,
                        range: range
                    )
                }
            }
        })
        if let mentions = viewItem.mentions {
            mentions.forEach { mention in
                let range = NSMakeRange(Int(mention.start), Int(mention.length))
                if range.location + range.length > text.count {
                    Logger.error("[mention] range:\(range) out of bounds")
                    return
                }
                attributedString.addAttribute(
                    .foregroundColor,
                    value: Theme.themeBlueColor,
                    range: range
                )
                attributedString.addAttribute(
                    .link,
                    value: "\(Self.kVisitingCardScheme)://\(mention.uid)",
                    range: range
                )
            }
        }
        
        var shouldIgnoreEvents = false
        let hasTapMore = displayableBodyText.isTextTruncated
        if hasTapMore {
            shouldIgnoreEvents = true
        } else {
            if let outgoingMessage = viewItem.interaction as? TSOutgoingMessage {
                shouldIgnoreEvents = outgoingMessage.messageState != .sent
            }
        }
        
        let textConfig = CVTextViewConfig.attributeText(
            attributedString,
            font: font,
            textColor: textColor,
            maximumNumberOfLines: 0,
            lineBreakMode: .byWordWrapping,
            linkTextAttributes: [.foregroundColor: Theme.themeBlueColor],
            shouldIgnoreEvents: shouldIgnoreEvents
        )
        
        return (textConfig, hasTapMore)
    }
    
    func getCombinedForwardingBodyTextConfig() -> CVTextViewConfig? {
        guard let message = viewItem.interaction as? TSMessage,
              let combinedForwardingMessage = message.combinedForwardingMessage else {
            return nil
        }
        let attributedString = DTForwardMessageHelper.combinedForwardingMessageBodyText(
            withIsGroupThread: combinedForwardingMessage.isFromGroup,
            combinedMessage: message
        )
        
        return .attributeText(
            attributedString,
            maximumNumberOfLines: 6,
            lineBreakMode: .byTruncatingTail,
            linkTextAttributes: [:],
            shouldIgnoreEvents: true
        )
    }
    
    func getCardBodyTextConfig() -> CVTextViewConfig {
        guard let attributedString = viewItem.buildAndConfigCardAttrString() else {
            return .empty
        }
        
        return .attributeText(
            attributedString,
            maximumNumberOfLines: 0,
            lineBreakMode: .byWordWrapping,
            linkTextAttributes: [:],
            shouldIgnoreEvents: false,
            textContainerInset: .init(top: 3, leading: 0, bottom: 0, trailing: 0)
        )
    }
    
    func calculateLastLineWidth(for message: String,
                                font: UIFont,
                                maxBubbleWidth: CGFloat,
                                bubblePadding: CGFloat) -> CGFloat {
        // 用于计算消息最后一行的宽度
        let maxWidth = maxBubbleWidth - bubblePadding * 2
        let text = message as NSString
        let rect = text.boundingRect(with: CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude), options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: font], context: nil)
        
        // 获取最后一行的宽度
        let textRange = NSRange(location: 0, length: text.length)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        let storage = NSTextStorage(string: message)
        layoutManager.addTextContainer(textContainer)
        storage.addLayoutManager(layoutManager)
        
        var lastLineWidth: CGFloat = 0
        layoutManager.enumerateLineFragments(forGlyphRange: textRange) { (_, usedRect, _, _, _) in
            lastLineWidth = usedRect.width
        }
        return lastLineWidth
    }
    
    func measureDefaultBodyTextSize(textConfig: CVTextViewConfig) -> CGSize {
        guard viewItem.hasBodyText else {
            return .zero
        }
        
        let hMargins = conversationStyle.textInsetHorizontal * 2
        let maxTextWidth = floor(conversationStyle.maxMessageWidth - hMargins)
        var result = textConfig.measure(maxWidth: maxTextWidth)
        // Note: 解决光标展示不全问题
        result.width += 1 / UIScreen.main.scale
        result.height += 1 / UIScreen.main.scale
        
        // Note: 系统在判断是否换行时，一般会根据词的完整性进行换行，这导致很多实际触发了换行，宽度却小于 maxTextWidth 的情况
        // 为了使大部分气泡的位置对称，进行宽度兼容处理，小于最大宽度 15pt 以内的，直接按照最大宽度处理
        let gap = maxTextWidth - result.width
        if gap <= 15 {
            result.width = maxTextWidth
        }
        
        if singleForwardTitleWidth > 0 {
            result.width = max(result.width, singleForwardTitleWidth)
        }
        
        return CGSizeCeil(result)
    }
    
    func measureDefaultBodyLastLineSize(textConfig: CVTextViewConfig) -> CGSize {
        guard viewItem.hasBodyText else {
            return .zero
        }
        
        let hMargins = conversationStyle.textInsetHorizontal * 2
        let maxTextWidth = floor(conversationStyle.maxMessageWidth - hMargins)
        var result = textConfig.measureLastLine(maxWidth: maxTextWidth)
        // Note: 解决光标展示不全问题
        result.width += 1 / UIScreen.main.scale
        result.height += 1 / UIScreen.main.scale
        
        return CGSizeCeil(result)
    }
    
    func measureCombinedForwardingBodyTextSize(textConfig: CVTextViewConfig) -> CGSize {
        guard isCombinedForwardingStyle else {
            return .zero
        }
        let hMargins = conversationStyle.textInsetHorizontal * 2
        let maxTextWidth = UIScreen.main.bounds.size.width * 2 / 3 - hMargins
        let result = textConfig.measure(maxWidth: maxTextWidth)
        
        return CGSizeCeil(result)
    }
    
    func measureCardBodyTextSize(textConfig: CVTextViewConfig) -> CGSize {
        return CGSizeZero
    }
    
}
