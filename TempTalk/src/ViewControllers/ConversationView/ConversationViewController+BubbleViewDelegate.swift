//
//  ConversationViewController+BubbleViewDelegate.swift
//  Signal
//
//  Created by Jaymin on 2024/1/23.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

// MARK: - Public

@objc
extension ConversationViewController {
    /// 展示个人信息卡片
    func showPersonalInfoCard(recipientId: String) {
        self.showProfileCardInfo(with: recipientId)
    }
}

// MARK: - ConversationMessageBubbleViewDelegate

extension ConversationViewController: ConversationMessageBubbleViewDelegate {
    
    // MARK: Emoji
    
    /// 点击 emoji 表情
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapReactionViewWith viewItem: any ConversationViewItem,
        emoji: String
    ) {
        guard !emoji.isEmpty else {
            return
        }
        guard let message = viewItem.interaction as? TSMessage else {
            return
        }
        let selectedEmojis = DTReactionHelper.selectedEmojis(message)
        let isNeedRemove = selectedEmojis.contains(emoji)
        
        ThreadUtil.sendReactionMessage(
            withEmoji: emoji,
            remove: isNeedRemove,
            targetMessage: message,
            in: self.thread,
            success: {},
            failure: { _ in }
        )
    }
    
    /// 长按 emoji 表情
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didLongPressReactionViewWith viewItem: any ConversationViewItem,
        emoji: String
    ) {
        guard !emoji.isEmpty else {
            return
        }
        guard let message = viewItem.interaction as? TSMessage else {
            return
        }
        let emojiContainerVC = DTReactionContainerController()
        emojiContainerVC.selectedEmoji = emoji
        emojiContainerVC.targetMessage = message
        let navigationController = OWSNavigationController(rootViewController: emojiContainerVC)
        present(navigationController, animated: true)
    }
    
    // MARK: Personal Info
    
    func messageBubbleView(_ bubbleView: ConversationMessageBubbleView, didTapContactShareViewWith viewItem: any ConversationViewItem) {
        AssertIsOnMainThread()
        
        guard let shareContractId = viewItem.contactShare?.phoneNumbers.first?.phoneNumber else {
            DTToastHelper.toast(
                withText: Localized("SHOW_PERSONAL_CARD_FAILED"),
                durationTime: 2
            )
            return
        }
        
        if viewItem.isConfidentialMessage {
            messageActionsShowDetailsForItem(viewItem)
        } else {
            showPersonalInfoCard(recipientId: shareContractId)
        }
    }
    
    // MARK: Attachment
    
    /// 点击图片
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapImageViewWith viewItem: any ConversationViewItem,
        attachmentStream: TSAttachmentStream,
        imageView: UIView
    ) {
        AssertIsOnMainThread()
        dismissKeyBoard()
        
        guard let message = viewItem.interaction as? TSMessage else {
            return
        }
        let mediaVC = MediaGalleryViewController(
            thread: self.thread,
            options: [.sliderEnabled, .showAllMediaButton]
        )
        mediaVC.presentDetailView(
            fromViewController: self,
            mediaMessage: message,
            replacingView: imageView
        )
    }
    
    /// 点击视频
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapVideoViewWith viewItem: any ConversationViewItem,
        attachmentStream: TSAttachmentStream,
        imageView: UIView
    ) {
        AssertIsOnMainThread()
        dismissKeyBoard()
        
        guard let message = viewItem.interaction as? TSMessage else {
            return
        }
        let mediaVC = MediaGalleryViewController(
            thread: self.thread,
            options: [.sliderEnabled, .showAllMediaButton]
        )
        mediaVC.presentDetailView(
            fromViewController: self,
            mediaMessage: message,
            replacingView: imageView
        )
    }
    
    /// 点击语音，播放或暂停
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapAudioViewWith viewItem: any ConversationViewItem,
        attachmentStream: TSAttachmentStream
    ) {
        if viewItem.isConfidentialMessage {
            messageActionsShowDetailsForItem(viewItem)
        } else {
            if attachmentStream.isVoiceMessage() {
                OWSAttachmentsProcessor.decryptVoiceAttachment(attachmentStream)
            }
            resumeAudioPlayer(viewItem: viewItem, attachmentStream: attachmentStream)
        }
    }
    
    /// 点击预览附件
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapGenericAttachmentViewWith viewItem: any ConversationViewItem,
        attachmentStream: TSAttachmentStream
    ) {
        AssertIsOnMainThread()
        
        previewAttachment(attachmentStream: attachmentStream, viewItem: viewItem)
    }
    
    /// 点击 incoming message 中加载失败的附件
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapDownloadFailedAttachmentWith viewItem: any ConversationViewItem,
        autoRestart: Bool,
        attachmentPointer: TSAttachmentPointer
    ) {
        AssertIsOnMainThread()
        
        tapDownloadFailedAttachmentForIncomingMessage(
            viewItem: viewItem,
            attachmentPointer: attachmentPointer,
            autoRestart: autoRestart
        )
    }
    
    /// 点击引用消息中下载失败的缩略图
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapDownloadFailedThumbnailWith viewItem: any ConversationViewItem,
        quotedReply: OWSQuotedReplyModel,
        attachmentPointer: TSAttachmentPointer
    ) {
        AssertIsOnMainThread()
        
        tapDownloadFailedThumbnailForQuotedReply(
            quotedReply,
            viewItem: viewItem,
            attachmentPointer: attachmentPointer
        )
    }
    
    // MARK: Message
    
    /// 点击长文消息，进入预览页面
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapTruncatedTextMessageWith viewItem: any ConversationViewItem
    ) {
        AssertIsOnMainThread()
        
        let longTextVC = LongTextViewController(viewItem: viewItem)
        navigationController?.pushViewController(longTextVC, animated: true)
    }
    
    /// 点击引用消息，滑动到被引用消息位置
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapConversationItemWith viewItem: any ConversationViewItem,
        quotedReply: OWSQuotedReplyModel
    ) {
        AssertIsOnMainThread()
        owsAssertDebug(quotedReply.timestamp > 0)
        owsAssertDebug(!quotedReply.authorId.isEmpty)
        
        databaseStorage.uiRead { transaction in
            self.conversationViewModel.ensureLoadWindowContainsQuotedReply(
                quotedReply,
                transaction: transaction
            ) { [weak self] indexPath in
                guard let self else { return }
                guard let indexPath, indexPath.row < self.dataSource.snapshot().numberOfItems else {
                    self.presentRemotelySourcedQuotedReplyToast()
                    return
                }
                self.collectionView.scrollToItem(at: indexPath, at: .top, animated: true)
            }
        }
    }
    
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapConfidentialTextMessageWith viewItem: ConversationViewItem
    ) {
        guard let message = viewItem.interaction as? TSMessage else {
            return
        }
        
        let confideMessageVC = DTConfideMessageController.init(message)
        let nav = OWSNavigationController.init(rootViewController: confideMessageVC)
        nav.modalPresentationStyle = .fullScreen
        self.navigationController?.presentFormSheet(nav, animated: true)
    }
    
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapConfidentialSingleForward viewItem: ConversationViewItem
    ) {
        messageActionDeleteItem(viewItem)
    }
    
    /// 点击合并转发消息
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapCombinedForwardingItemWith viewItem: any ConversationViewItem
    ) {
        AssertIsOnMainThread()
        
        guard let message = viewItem.interaction as? TSMessage else {
            return
        }
        guard let combinedForwardingMessage = message.combinedForwardingMessage else {
            return
        }
        let combinedMessageVC = DTCombinedMessageController()
        combinedMessageVC.shouldUseTheme = true
        combinedMessageVC.configure(
            thread: self.thread,
            combinedMessage: message,
            isGroupChat: combinedForwardingMessage.isFromGroup
        )
        navigationController?.pushViewController(combinedMessageVC, animated: true)
    }
    
    // MARK: Link
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapLinkWith viewItem: any ConversationViewItem,
        url: URL
    ) {
        _ = AppLinkManager.handle(url: url, fromExternal: false, sourceVC: self)
    }
}

// MARK: - Private

private extension ConversationViewController {
    /// 展示未找到被引用的消息的提示弹窗
    func presentRemotelySourcedQuotedReplyToast() {
        let toastText = Localized("QUOTED_REPLY_ORIGINAL_MESSAGE_REMOTELY_SOURCED")
        let toastController = ToastController(text: toastText)
        let bottomInset = 10 + collectionView.contentInset.bottom + view.layoutMargins.bottom
        toastController.presentToastView(fromBottomOfView: self.view, inset: bottomInset)
    }
}
