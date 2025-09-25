//
//  CVQuotedMessageRenderItem.swift
//  Difft
//
//  Created by Jaymin on 2024/7/30.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit

class CVQuotedMessageRenderItem: ConversationRenderItem {
    
    enum AttachmentType {
        case thumbnail(image: UIImage, isVideo: Bool)
        case downloadFailed(backgroundColor: UIColor)
        case generic
    }
    
    static let bubbleMargin: CGFloat = 6
    static let topMargin: CGFloat = 6
    static let hPadding: CGFloat = 6
    static let vSpacing: CGFloat = 2
    static let hSpacing: CGFloat = 6
    static let trailingSpacer: CGFloat = 80
    static let textVMargin: CGFloat = 7
    static let attachmentSize: CGFloat = 54
    static let stripeThickness: CGFloat = 4
    static let backgroundSubviewsPadding: CGFloat = 8
    
    var authorTextConfig: CVLabelConfig?
    var quotedMessageTextConfig: CVLabelConfig?
    var attachmentType: AttachmentType?
    var isVoiceMessage: Bool = false
    var contentType: String = ""
    
    var authorTextColor: UIColor {
        conversationStyle.quotedReplyAuthorColor()
    }
    
    var quotedTextColor: UIColor {
        conversationStyle.replyTextColor()
    }
    
    var fileTypeTextColor: UIColor {
        conversationStyle.quotedReplyAttachmentColor()
    }
    
    var fileNameTextColor: UIColor {
        conversationStyle.quotedReplyAttachmentColor()
    }
    
    static var quotedAuthorHeight: CGFloat {
        ceil(UIFont.ows_dynamicTypeSubheadline.ows_italic().lineHeight)
    }
    
    var hasQuotedAttachment: Bool {
        guard let quotedReply = viewItem.quotedReply else {
            return false
        }
        guard let contentType = quotedReply.contentType, !contentType.isEmpty else {
            return false
        }
        return contentType != OWSMimeTypeOversizeTextMessage
    }
    
    override func configure() {
        guard let quotedReply = viewItem.quotedReply else {
            return
        }
        if let attachment = quotedReply.attachmentStream {
            self.isVoiceMessage = attachment.isVoiceMessage()
        } else {
            self.isVoiceMessage = quotedReply.sourceFilename?.isEmpty != false
        }
        self.contentType = quotedReply.contentType ?? ""
        self.authorTextConfig = getAuthorTextConfig(quotedReply: quotedReply)
        self.quotedMessageTextConfig = getQuotedMessageTextConfig(quotedReply: quotedReply)
        self.attachmentType = getAttachmentType(quotedReply: quotedReply)
        self.viewSize = measureSize()
    }
    
    private func getAuthorTextConfig(quotedReply: OWSQuotedReplyModel) -> CVLabelConfig {
        let quoteAuthor = {
            let localNumber = TSAccountManager.localNumber()
            if localNumber == quotedReply.authorId {
                if isOutgoingMessage {
                    return Localized("QUOTED_AUTHOR_INDICATOR_YOURSELF")
                } else {
                    return Localized("QUOTED_AUTHOR_INDICATOR_YOU")
                }
            } else {
                return String(format: Localized("QUOTED_AUTHOR_INDICATOR_YOU_FORMAT"), quotedReply.authorName)
            }
        }()
        
        return .unstyledText(
            quoteAuthor,
            font: .ows_dynamicTypeSubheadline.ows_italic(),
            numberOfLines: 1,
            lineBreakMode: .byTruncatingTail
        )
    }
    
    private func getQuotedMessageTextConfig(quotedReply: OWSQuotedReplyModel) -> CVLabelConfig {
        let displayableQuotedText = viewItem.hasQuotedText ? viewItem.displayableQuotedText() : nil
        let fileTypeForSnippet: String? = {
            guard let contentType = quotedReply.contentType, !contentType.isEmpty else {
                return nil
            }
            if MIMETypeUtil.isAudio(contentType) {
                return quotedReply.attachmentStream?.sourceFilename ?? Localized("QUOTED_REPLY_TYPE_AUDIO")
            }
            if MIMETypeUtil.isVideo(contentType) {
                return Localized("QUOTED_REPLY_TYPE_VIDEO")
            }
            if MIMETypeUtil.isImage(contentType) {
                return Localized("QUOTED_REPLY_TYPE_IMAGE")
            }
            if MIMETypeUtil.isAnimated(contentType) {
                return Localized("QUOTED_REPLY_TYPE_GIF")
            }
            return nil
        }()
        let (quoteText, quoteFont, quoteColor) = {
            if quotedReply.inputPreviewType == .topicFromMainViewReply {
                return ("", UIFont.ows_dynamicTypeBody, quotedTextColor)
            }
            if let displayableQuotedText, !displayableQuotedText.displayText.isEmpty {
                var text = displayableQuotedText.displayText
                // 卡片类型消息，预览时需要移除 markdown 格式
                if let cardContent = quotedReply.replyItem?.card?.content, !cardContent.isEmpty {
                    text = text.removeMarkdownStyle()
                }
                return (text, UIFont.ows_dynamicTypeBody, quotedTextColor)
            }
            if let fileTypeForSnippet {
                return (fileTypeForSnippet, UIFont.ows_dynamicTypeBody.ows_italic(), fileTypeTextColor)
            }
            if let sourceFileName = quotedReply.sourceFilename {
                return (sourceFileName, UIFont.ows_dynamicTypeBody, fileNameTextColor)
            }
            return (Localized("QUOTED_REPLY_TYPE_ATTACHMENT"), UIFont.ows_dynamicTypeBody.ows_italic(), fileTypeTextColor)
        }()
        
        return .unstyledText(
            quoteText,
            font: quoteFont,
            textColor: quoteColor,
            numberOfLines: 2,
            lineBreakMode: .byTruncatingTail
        )
    }
    
    private func getAttachmentType(quotedReply: OWSQuotedReplyModel) -> AttachmentType? {
        guard let contentType = quotedReply.contentType, !contentType.isEmpty else {
            return nil
        }
        guard contentType != OWSMimeTypeOversizeTextMessage else {
            return nil
        }
        
        if TSAttachmentStream.hasThumbnail(forMimeType: contentType), let image = quotedReply.thumbnailImage {
            return .thumbnail(image: image, isVideo: MIMETypeUtil.isVideo(contentType))
        }
        
        if quotedReply.thumbnailDownloadFailed {
            let isQuotingSelf = {
                guard let localNumber = TSAccountManager.localNumber() else {
                    return false
                }
                return quotedReply.authorId == localNumber
            }()
            let backgroundColor = isQuotingSelf ? conversationStyle.bubbleColorOutgoingSent : conversationStyle.quotingSelfHighlightColor()
            return .downloadFailed(backgroundColor: backgroundColor)
        }
        
        return .generic
    }
    
    private func measureSize() -> CGSize {
        guard let quotedReply = viewItem.quotedReply else {
            return .zero
        }

        var size: CGSize = .zero
        size.width = Self.hPadding * 2 + Self.stripeThickness + Self.hSpacing * 2 + Self.trailingSpacer
        
        var thumbnailHeight: CGFloat = 0
        if hasQuotedAttachment {
            size.width += Self.attachmentSize
            thumbnailHeight = Self.attachmentSize
        }
        
        let maxTextWidth = conversationStyle.maxMessageWidth - size.width
        let quotedAuthorSize: CGSize = {
            guard let authorTextConfig else {
                return .zero
            }
            return authorTextConfig.measure(maxWidth: maxTextWidth)
        }()
        var textWidth = quotedAuthorSize.width
        var textHeight = Self.textVMargin * 2 + Self.quotedAuthorHeight + Self.vSpacing
        
        let quotedMessageSize: CGSize = {
            guard let quotedMessageTextConfig else {
                return .zero
            }
            return quotedMessageTextConfig.measure(maxWidth: maxTextWidth)
        }()
        textWidth = max(textWidth, quotedMessageSize.width)
        textHeight += quotedMessageSize.height
        
        textWidth = min(textWidth, maxTextWidth)
        size.width += textWidth
        size.height += max(textHeight, thumbnailHeight)
        
        return CGSizeCeil(size)
    }
    
}
