//
//  ConversationMessageBubbleView+Gesture.swift
//  Signal
//
//  Created by Jaymin on 2024/5/11.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit

enum ConversationMessageGestureLocation: Int {
    case `default`
    case oversizeText
    case media
    case quotedReply
    case combinedForwarding
    case contactShare
    case card
}

extension ConversationMessageBubbleView {
    func addTapGestureHandler() {
        // 手势已在 ConversationMessageCell 中添加
        // 这里只是保留这个方法以保持兼容性
    }

    @objc func handleTapGesture(_ sender: UITapGestureRecognizer) {
        guard let viewItem = renderItem?.viewItem else { return }
        guard sender.state == .recognized else {
            Logger.verbose("Ignoring tap on message:\(viewItem.interaction.debugDescription)")
            return
        }
        
        if viewItem.isConfidentialMessage {
            let cellType = viewItem.messageCellType()
            if cellType == .textMessage || cellType == .oversizeTextMessage || cellType == .audio {
                delegate?.messageBubbleView?(self, didTapConfidentialTextMessageWith: viewItem)
                return
            }
        }
        
        if let outgoingMessage = viewItem.interaction as? TSOutgoingMessage {
            if outgoingMessage.messageState == .failed {
                // 对于语音消息，允许点击播放
                if viewItem.messageCellType() != .audio {
                    return
                }
            }
            if outgoingMessage.messageState == .sending, !outgoingMessage.isPinnedMessage {
                // Ignore taps on outgoing messages being sent.
                return
            }
        }
        
        UIMenuController.shared.hideMenu()
        
        let locationInMessageBubbleView = sender.location(in: self)
        let gestureLocation = gestureLocationForLocation(locationInMessageBubbleView)
        switch gestureLocation {
        case .oversizeText:
//            delegate?.messageBubbleView?(self, didTapTruncatedTextMessageWith: viewItem)
            break
        case .media:
            handleMediaTapGesture(viewItem: viewItem)
            
        case .quotedReply:
            if let quotedReply = viewItem.quotedReply {
                delegate?.messageBubbleView?(
                    self,
                    didTapConversationItemWith: viewItem,
                    quotedReply: quotedReply
                )
            } else {
                Logger.error("Missing quoted message.")
            }
            
        case .combinedForwarding:
            if viewItem.messageCellType() == .combinedForwarding, viewItem.isCombindedForwardMessage {
                delegate?.messageBubbleView?(self, didTapCombinedForwardingItemWith: viewItem)
            } else {
                Logger.error("Missing combined forwarding message.")
            }
            
        case .contactShare:
            if viewItem.messageCellType() == .contactShare, viewItem.contactShare != nil {
                // 获取分享名片的用户ID（消息发送者）
                var shareContactCardUid: String?

                if let incomingMessage = viewItem.interaction as? TSIncomingMessage {
                    shareContactCardUid = incomingMessage.authorId
                }

                if let uid = shareContactCardUid {
                    DTAddFriendSourceManager.shared.setShareContactSource(shareContactCardUid: uid)
                } else {
                    DTAddFriendSourceManager.shared.setOtherSource(.inUserCard)
                }
                delegate?.messageBubbleView?(self, didTapContactShareViewWith: viewItem)
            }
            
        default:
            break
        }
    }
    
    func gestureLocationForLocation(_ location: CGPoint) -> ConversationMessageGestureLocation {
        if let quotedMessageView {
            // Treat this as a "quoted reply" gesture if:
            //
            // * There is a "quoted reply" view.
            // * The gesture occured within or above the "quoted reply" view.
            let quotedLocation = self.convert(location, to: quotedMessageView)
            if quotedLocation.y <= quotedMessageView.height {
                return .quotedReply
            }
        }
        
        guard let viewItem = renderItem?.viewItem else { return .default }
        
        if let bodyMediaView {
            // Treat this as a "body media" gesture if:
            //
            // * There is a "body media" view.
            // * The gesture occured within or above the "body media" view...
            // * ...OR if the message doesn't have body text.
            
            if viewItem.contactShare != nil {
                return .contactShare
            }
            let bodyMediaLocation = self.convert(location, to: bodyMediaView)
            if bodyMediaLocation.y <= bodyMediaView.height {
                return .media
            }
            if !viewItem.hasBodyText {
                return .media
            }
        }
        
        if let bodyTextItem = renderItem?.bodyTextRenderItem, bodyTextItem.hasTapForMore {
            return .oversizeText
        }
        
        if let bodyTextItem = renderItem?.bodyTextRenderItem, bodyTextItem.isCombinedForwardingStyle {
            return .combinedForwarding
        }
        
        if viewItem.card != nil {
            return .card
        }
        
        return .default
    }
    
    private func handleMediaTapGesture(viewItem: ConversationViewItem) {
        let cellType = viewItem.messageCellType()

        switch cellType {
        case .stillImage, .animatedImage:
            guard let bodyMediaView else { return }
            guard let attachmentStream = viewItem.attachmentStream() else { return }
            delegate?.messageBubbleView?(
                self,
                didTapImageViewWith: viewItem,
                attachmentStream: attachmentStream,
                imageView: bodyMediaView
            )
        case .audio:
            guard let attachmentStream = viewItem.attachmentStream() else { return }
            delegate?.messageBubbleView?(
                self,
                didTapAudioViewWith: viewItem,
                attachmentStream: attachmentStream
            )
        case .video:
            guard let bodyMediaView else { return }
            guard let attachmentStream = viewItem.attachmentStream() else { return }
            delegate?.messageBubbleView?(
                self,
                didTapVideoViewWith: viewItem,
                attachmentStream: attachmentStream,
                imageView: bodyMediaView
            )
        case .genericAttachment:
            if viewItem.isConfidentialMessage {
                delegate?.messageBubbleView?(self, didTapConfidentialTextMessageWith: viewItem)
                return
            }
            // Check if attachment is downloaded (Stream) or not (Pointer)
            if let attachmentStream = viewItem.attachmentStream() {
                // Attachment is downloaded, preview it
                delegate?.messageBubbleView?(
                    self,
                    didTapGenericAttachmentViewWith: viewItem,
                    attachmentStream: attachmentStream
                )
            } else if let attachmentPointer = viewItem.attachmentPointer() {
                // Attachment is not downloaded (Pointer), trigger download
                if attachmentPointer.state == .failed || attachmentPointer.state == .enqueued || attachmentPointer.state == .expired {
                    delegate?.messageBubbleView?(
                        self,
                        didTapDownloadFailedAttachmentWith: viewItem,
                        autoRestart: true,
                        attachmentPointer: attachmentPointer
                    )
                }
            }
        case .downloadingAttachment:
            guard let attachmentPointer = viewItem.attachmentPointer() else { return }
            if attachmentPointer.state == .failed || attachmentPointer.state == .enqueued || attachmentPointer.state == .expired {
                delegate?.messageBubbleView?(
                    self,
                    didTapDownloadFailedAttachmentWith: viewItem,
                    autoRestart: false,
                    attachmentPointer: attachmentPointer
                )
            }
        default:
            break
        }
    }
}
