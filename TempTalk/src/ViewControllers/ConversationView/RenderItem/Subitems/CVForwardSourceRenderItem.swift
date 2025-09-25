//
//  CVForwardSourceRenderItem.swift
//  Difft
//
//  Created by Jaymin on 2024/7/30.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit

class CVForwardSourceRenderItem: ConversationRenderItem {
    
    static let mediaQuotedReplyVSpacing: CGFloat = 6
    static let forwardSourceFont: UIFont = .ows_dynamicTypeFootnote
    
    var singleForwardTitle: NSAttributedString?
    var fixForwardSourceLabelHeight: CGFloat = .zero
    
    var textColor: UIColor? {
        guard let message = viewItem.interaction as? TSMessage else {
            return nil
        }
        return conversationStyle.bubbleTextColor(message: message)
    }
    
    override func configure() {
        self.singleForwardTitle = getSingleForwardTitle()
        
        // 文字控件顶部自带间隔，图片/视频顶部与source间隔太小，需要修正
        let shouldFixForwardSourceHeight = {
            let cellTypes: [OWSMessageCellType] = [.stillImage, .animatedImage, .video]
            return cellTypes.contains(viewItem.messageCellType())
        }()
        if shouldFixForwardSourceHeight {
            fixForwardSourceLabelHeight = Self.mediaQuotedReplyVSpacing
        }
        
        self.viewSize = measureSize()
    }
    
    private func getSingleForwardTitle() -> NSAttributedString? {
        guard let message = viewItem.interaction as? TSMessage else {
            return nil
        }
        guard let singleForwardMessage = message.combinedForwardingMessage?.subForwardingMessages.first else {
            return nil
        }
        let messageDate = Date(millisecondsSince1970: singleForwardMessage.timestamp)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yy HH:mm"
        let suffix = String(
            format: Localized("FORWARD_MESSAGE_SINGLE_TITLE"),
            dateFormatter.string(from: messageDate)
        )
        var fullText = suffix
        let authorName = singleForwardMessage.authorName
        if !authorName.isEmpty {
            fullText += authorName
        }
        let attributeTitle = NSMutableAttributedString(string: fullText)
        attributeTitle.addAttribute(
            .font,
            value: Self.forwardSourceFont,
            range: .init(location: 0, length: suffix.count)
        )
        if !authorName.isEmpty {
            attributeTitle.addAttribute(
                .font,
                value: Self.forwardSourceFont.ows_semibold(),
                range: .init(location: suffix.count, length: authorName.count)
            )
        }
        let titleColor: UIColor = {
            if viewItem.messageCellType() == .card {
                return Theme.isDarkThemeEnabled ? .ows_darkSkyBlue : Theme.primaryTextColor.withAlphaComponent(0.8)
            }
            let bodyTextColor = conversationStyle.bubbleTextColor(message: message).withAlphaComponent(0.8)
            let outgoingColor: UIColor = Theme.isDarkThemeEnabled ? .ows_darkSkyBlue : bodyTextColor
            return self.isIncomingMessage ? outgoingColor : bodyTextColor
        }()
        attributeTitle.addAttribute(
            .foregroundColor,
            value: titleColor,
            range: .init(location: 0, length: fullText.count)
        )
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = -5
        attributeTitle.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: .init(location: 0, length: fullText.count)
        )
        
        return attributeTitle
    }
    
    private func measureSize() -> CGSize {
        guard let singleForwardTitle, !singleForwardTitle.isEmpty else {
            return .zero
        }
        
        let width = singleForwardTitle.boundingRect(
            with: .init(width: CGFloat.infinity, height: 0),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size.width
        
        let height: CGFloat = {
            switch(viewItem.messageCellType()) {
            case .stillImage, .animatedImage, .video, .audio:
                return ceil(Self.forwardSourceFont.semibold().pointSize * 2 + Self.mediaQuotedReplyVSpacing * 3) + 5
            case .textMessage, .oversizeTextMessage, .genericAttachment, .downloadingAttachment, .card:
                return ceil(Self.forwardSourceFont.semibold().pointSize * 2 + Self.mediaQuotedReplyVSpacing * 2) + 5
            default:
                return .zero
            }
        }()
        
        return CGSizeCeil(CGSize(width: width, height: height))
    }
}
