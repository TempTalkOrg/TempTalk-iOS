//
//  CVMessageBubbleRenderItem.swift
//  Difft
//
//  Created by Jaymin on 2024/7/25.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit

class CVMessageBubbleRenderItem: ConversationRenderItem {
        
    static let textViewSpacing: CGFloat = 2
        
    var forwardSourceRenderItem: CVForwardSourceRenderItem?
    var quotedMessageRenderItem: CVQuotedMessageRenderItem?
    var bodyMediaRenderItem: CVBodyMediaRenderItem?
    var bodyTextRenderItem: CVBodyTextRenderItem?
    var emojiReactionRenderItem: CVEmojiReactionRenderItem?
    var footerRenderItem: CVMessageFooterRenderItem?
    
    var hasOnlyBodyMediaView = false
    
    private var _confidentialEnable = true
    var confidentialEnable: Bool {
        get { _confidentialEnable }
        set {
            bodyTextRenderItem?.confidentialEnable = newValue
            _confidentialEnable = newValue
        }
    }

    
    var isShowPinMark: Bool {
        viewItem.isPinned && !viewItem.isPinMessage
    }
    
    var sharpCorners: OWSDirectionalRectCorner {
        switch (!viewItem.isFirstInCluster, !viewItem.isLastInCluster) {
        case (true, true):
            return self.isIncomingMessage ? [.topLeading, .bottomLeading] : [.topTrailing, .bottomTrailing]
        case (true, false):
            return self.isIncomingMessage ? [.topLeading] : [.topTrailing]
        case (false, true):
            return self.isIncomingMessage ? [.topTrailing] : [.bottomTrailing]
        default:
            return []
        }
    }
    
    var hasBodyMediaWithThumbnail: Bool {
        switch viewItem.messageCellType() {
        case .stillImage, .animatedImage, .video:
            return true
        default:
            return false
        }
    }
    
    var shouldShowMediaFooter: Bool {
        !viewItem.shouldHideFooter && hasBodyMediaWithThumbnail && !viewItem.hasBodyText
    }
    
    var caption1FontHeight: CGFloat {
        ceil(UIFont.ows_dynamicTypeCaption1.lineHeight * 1.25)
    }
    
    override func configure() {
        configureForForwardSourceView()
        configureForQuotedMessageView()
        configureForBodyMediaView()
        configureForBodyTextView()
        configureForEmojiReactionView()
        configureForFooterView()
        
        self.viewSize = measureSize()
    }
    
    private func configureForForwardSourceView() {
        let isShowForwardSourceView = {
            switch viewItem.messageCellType() {
            case .textMessage,
                    .card,
                    .oversizeTextMessage,
                    .genericAttachment,
                    .downloadingAttachment,
                    .stillImage,
                    .animatedImage,
                    .video,
                    .audio:
                guard let message = viewItem.interaction as? TSMessage else {
                    return false
                }
                return message.combinedForwardingMessage?.subForwardingMessages.count == 1
                
            default:
                return false
            }
        }()
        if isShowForwardSourceView {
            forwardSourceRenderItem = CVForwardSourceRenderItem(
                viewItem: viewItem,
                conversationStyle: conversationStyle
            )
        }
    }
    
    private func configureForQuotedMessageView() {
        guard viewItem.isQuotedReply, let _ = viewItem.quotedReply else {
            return
        }
        quotedMessageRenderItem = CVQuotedMessageRenderItem(
            viewItem: viewItem,
            conversationStyle: conversationStyle
        )
    }
    
    private func configureForBodyMediaView() {
        let singleForwardTitleWidth = forwardSourceRenderItem?.viewSize.width ?? .zero
        bodyMediaRenderItem = CVBodyMediaRenderItem(
            viewItem: viewItem,
            conversationStyle: conversationStyle,
            signleForwardTitleWidth: singleForwardTitleWidth
        )
    }
    
    private func configureForBodyTextView() {
        let isShowBodyMediaView = (bodyMediaRenderItem?.viewSize.height ?? 0) > 0
        let singleForwardTitleWidth = forwardSourceRenderItem?.viewSize.width ?? .zero
        bodyTextRenderItem = CVBodyTextRenderItem(
            viewItem: viewItem,
            conversationStyle: conversationStyle,
            isShowBodyMediaView: isShowBodyMediaView,
            singleForwardTitleWidth: singleForwardTitleWidth
        )
    }
    
    private func configureForEmojiReactionView() {
        guard viewItem.hasEmojiReactionView else {
            return
        }
        emojiReactionRenderItem = CVEmojiReactionRenderItem(
            viewItem: viewItem,
            conversationStyle: conversationStyle
        )
    }
    
    private func configureForFooterView() {
        if viewItem.isLastInCluster {
            self.footerRenderItem = CVMessageFooterRenderItem(
                viewItem: viewItem,
                conversationStyle: conversationStyle
            )
        }
    }
    
    private func measureSize() -> CGSize {
        var cellSize: CGSize = .zero
        var textViewSizeArray: [CGSize] = []
        
        if let forwardSourceViewHeight = forwardSourceRenderItem?.viewSize.height {
            cellSize.height += forwardSourceViewHeight
        }
        
        if let quotedMessageViewSize = quotedMessageRenderItem?.viewSize, !CGSizeEqualToSize(quotedMessageViewSize, .zero) {
            cellSize.height += CVQuotedMessageRenderItem.topMargin
            cellSize.width = max(cellSize.width, quotedMessageViewSize.width)
            cellSize.height += quotedMessageViewSize.height
        }
        
        let caption1FontHeight: CGFloat = self.caption1FontHeight
        if let bodyMediaRenderItem, !CGSizeEqualToSize(bodyMediaRenderItem.viewSize, .zero) {
            let bodyMediaSize = bodyMediaRenderItem.viewSize
            if bodyMediaRenderItem.hasFullWidthMediaView {
                if viewItem.isQuotedReply {
                    cellSize.height += CVForwardSourceRenderItem.mediaQuotedReplyVSpacing
                }
                cellSize.width = max(cellSize.width, bodyMediaSize.width)
                cellSize.height += bodyMediaSize.height
            } else {
                textViewSizeArray.append(bodyMediaSize)
            }
        }
        
        if let bodyTextRenderItem, !CGSizeEqualToSize(bodyTextRenderItem.viewSize, .zero) {
            let bodyTextSize = bodyTextRenderItem.viewSize
            
            if viewItem.messageCellType() == .card {
                textViewSizeArray.append(bodyTextSize)
                
            } else if bodyTextRenderItem.isCombinedForwardingStyle {
                textViewSizeArray.append(bodyTextSize)
                textViewSizeArray.append(.init(width: bodyTextSize.width, height: caption1FontHeight + 2))
                
            } else {
                textViewSizeArray.append(bodyTextSize)
                if bodyTextRenderItem.hasTapForMore {
                    textViewSizeArray.append(.init(width: bodyTextSize.width, height: caption1FontHeight))
                }
            }
        }
        
        var reactionSize = CGSizeZero
        if let emojiReactionRenderItem, !viewItem.isPinMessage {
            reactionSize = emojiReactionRenderItem.measureSize(bubbleWidth: cellSize.width)
            textViewSizeArray.append(reactionSize)
        }
        
        if !textViewSizeArray.isEmpty {
            let groupSize = sizeForTextViewSizeArray(textViewSizeArray)
            cellSize.width = max(cellSize.width, groupSize.width)
            cellSize.height += groupSize.height
        }
        
        var showFooterView = false
        if viewItem.isLastInCluster ||
            viewItem.interaction is TSOutgoingMessage {
            showFooterView = true
        }
        
        // Make sure the bubble is always wide enough to complete it's bubble shape.
        let kOWSMessageCellCornerRadius_Large: CGFloat = 5
        let bubbleMinWidth: CGFloat = kOWSMessageCellCornerRadius_Large * 2
        cellSize.width = max(cellSize.width, bubbleMinWidth)
        cellSize.width = min(cellSize.width, conversationStyle.maxMessageWidth)
        
        if showFooterView {
            // 失败的话，不展示错误提示
            var readFailedSize: CGFloat = 0
            if let outgoingMessage = viewItem.interaction as? TSOutgoingMessage, outgoingMessage.messageState == .failed {
                readFailedSize = ConversationOutgoingMessageRenderItem.readStatusImageSize
            }
            
            let footerWidth = CVMessageFooterRenderItem.footerWidth(viewItem: viewItem, footerViewTitle: footerRenderItem?.footerViewTitle) - readFailedSize
            if let lastLineSize = bodyTextRenderItem?.lastLineSize, lastLineSize != .zero {
                if reactionSize != .zero {
                    let readStatus_reaction_width = reactionSize.width + footerWidth - CVMessageFooterRenderItem.footerViewSpace
                    if readStatus_reaction_width > conversationStyle.maxMessageWidth {
                        cellSize.height += CVMessageFooterRenderItem.footerViewHeight
                    } else {
                        cellSize.width = max(cellSize.width, readStatus_reaction_width)
                    }
                } else {
                    let text_readStatus_width = conversationStyle.textInsetHorizontal + lastLineSize.width + footerWidth
                    if text_readStatus_width > conversationStyle.maxMessageWidth {
                        cellSize.height += CVMessageFooterRenderItem.footerViewHeight
                    } else {
                        cellSize.width = max(cellSize.width, text_readStatus_width)
                    }
                }
            } else if let bodyTextRenderItem, !bodyTextRenderItem.isCombinedForwardingStyle,
                      viewItem.messageCellType() != .contactShare{
                cellSize.height += CVMessageFooterRenderItem.footerViewHeight + 4

            }
        }
        
        return CGSizeCeil(cellSize)
    }
    
    private func sizeForTextViewSizeArray(_ sizeArray: [CGSize]) -> CGSize {
        guard !sizeArray.isEmpty else {
            return .zero
        }
        var result: CGSize = .zero
        sizeArray.forEach {
            result.width = max(result.width, $0.width)
            result.height += $0.height
        }
        result.height += Self.textViewSpacing * CGFloat(sizeArray.count - 1)
        result.height += conversationStyle.textInsetTop + conversationStyle.textInsetBottom
        result.width += conversationStyle.textInsetHorizontal * 2
        
        return result
    }
}
