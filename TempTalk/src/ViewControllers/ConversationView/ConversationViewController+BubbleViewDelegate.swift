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
        dismissKeyBoard(byUserAction: true)
        // 判断是否是同一个 thread（1v1 会话）
        let isFromSameThread = !thread.isGroupThread() && thread.contactIdentifier() == recipientId
        self.showProfileCardInfo(with: recipientId, isFromSameThread: isFromSameThread)
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
            // Confidential contact card: show full card, then burn the source message on view.
            handleConfidentialMessageTap(viewItem: viewItem) { [weak self] in
                self?.showPersonalInfoCard(recipientId: shareContractId)
                self?.burnConfidentialMessageOnView(viewItem)
            }
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
        dismissKeyBoard(byUserAction: true)

        guard let message = viewItem.interaction as? TSMessage else {
            return
        }

        handleConfidentialMessageTap(viewItem: viewItem) { [weak self] in
            self?.openMediaGallery(message: message, imageView: imageView)
        }
    }

    private func openMediaGallery(message: TSMessage, imageView: UIView) {
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
        dismissKeyBoard(byUserAction: true)

        guard let message = viewItem.interaction as? TSMessage else {
            return
        }

        handleConfidentialMessageTap(viewItem: viewItem) { [weak self] in
            self?.openMediaGallery(message: message, imageView: imageView)
        }
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
    
    /// 点击长消息的readMore
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapReadMoreMessageWith viewItem: any ConversationViewItem
    ) {
        AssertIsOnMainThread()

        let longMessageVC = LongMessageViewController(viewItem: viewItem)
        longMessageVC.modalPresentationStyle = .overFullScreen
        longMessageVC.modalTransitionStyle = .crossDissolve
        present(longMessageVC, animated: true)
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

        // Skip alert for outgoing messages
        if message is TSOutgoingMessage {
            showConfidentialMessageDetail(message: message, viewItem: viewItem)
            return
        }

        // Check if should show alert first
        var shouldShowAlert = false
        databaseStorage.read { transaction in
            shouldShowAlert = !SSKPreferences.hasShownConfidentialMessageAlert(transaction: transaction)
        }

        // Show alert before presenting detail view
        if shouldShowAlert {
            DTConfidentialMessageAlertController.present(from: self) { [weak self] in
                self?.showConfidentialMessageDetail(message: message, viewItem: viewItem)
            }
        } else {
            showConfidentialMessageDetail(message: message, viewItem: viewItem)
        }
    }

    private func showConfidentialMessageDetail(message: TSMessage, viewItem: ConversationViewItem) {
        let cellType = viewItem.messageCellType()

        if cellType == .audio, viewItem.attachmentStream() != nil {
            let voiceMessageVC = DTConfidentialVoiceMessageController(message: message, viewItem: viewItem)
            let nav = OWSNavigationController(rootViewController: voiceMessageVC)
            nav.modalPresentationStyle = .fullScreen
            navigationController?.presentFormSheet(nav, animated: true)
        } else if cellType == .genericAttachment,
                  let attachmentStream = viewItem.attachmentStream(),
                  let filePath = attachmentStream.filePath() {
            let incomingMessage = message as? TSIncomingMessage
            let filePreviewVC = DTConfidentialFilePreviewController(
                fileURL: URL(fileURLWithPath: filePath),
                incomingMessage: incomingMessage
            )
            filePreviewVC.present(from: self)
        } else {
            let confideMessageVC = DTConfideMessageController(message)
            let nav = OWSNavigationController(rootViewController: confideMessageVC)
            nav.modalPresentationStyle = .fullScreen
            navigationController?.presentFormSheet(nav, animated: true)
        }
    }
    
    /// 点击合并转发消息
    func messageBubbleView(
        _ bubbleView: ConversationMessageBubbleView,
        didTapCombinedForwardingItemWith viewItem: any ConversationViewItem
    ) {
        AssertIsOnMainThread()
        dismissKeyBoard(byUserAction: true)

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

        // 使用 PanModal 方式展示
        let navController = DTPanModalNavController(
            rootViewController: combinedMessageVC,
            defaultHeight: UIScreen.main.bounds.height * 0.75
        )
        presentPanModal(navController)
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
    /// Burn a confidential contact card on view: mark read + delete the source message.
    /// Incoming only, mirroring DTConfidentialFilePreviewController.markAsReadAndDelete.
    func burnConfidentialMessageOnView(_ viewItem: ConversationViewItem) {
        guard let incoming = viewItem.interaction as? TSIncomingMessage,
              incoming.isConfidentialMessage() else {
            return
        }
        OWSReadReceiptManager.shared().confidentialMessageWasReadLocally(incoming)
        databaseStorage.asyncWrite { transaction in
            incoming.anyRemove(transaction: transaction)
        }
    }

    /// 处理机密消息点击，如果需要则显示提示弹窗
    func handleConfidentialMessageTap(
        viewItem: ConversationViewItem,
        action: @escaping () -> Void
    ) {
        if viewItem.isConfidentialMessage {
            // Skip alert for outgoing messages
            if viewItem.interaction is TSOutgoingMessage {
                action()
                return
            }

            var shouldShowAlert = false
            databaseStorage.read { transaction in
                shouldShowAlert = !SSKPreferences.hasShownConfidentialMessageAlert(transaction: transaction)
            }

            if shouldShowAlert {
                DTConfidentialMessageAlertController.present(from: self) {
                    action()
                }
            } else {
                action()
            }
        } else {
            action()
        }
    }

    /// 展示未找到被引用的消息的提示弹窗
    func presentRemotelySourcedQuotedReplyToast() {
        let toastText = Localized("QUOTED_REPLY_ORIGINAL_MESSAGE_REMOTELY_SOURCED")
        let toastController = ToastController(text: toastText)
        let bottomInset = 10 + collectionView.contentInset.bottom + view.layoutMargins.bottom
        toastController.presentToastView(fromBottomOfView: self.view, inset: bottomInset)
    }
}
