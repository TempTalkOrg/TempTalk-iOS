//
//  ConversationViewController+Attachment.swift
//  Wea
//
//  Created by Felix on 2022/5/31.
//  Copyright © 2022 Difft. All rights reserved.
//

import Foundation
import QuickLook
import TTServiceKit

// MARK: Public

@objc extension ConversationViewController {
    
    var genericAttachmenViewItem: ConversationViewItem? {
        get { viewState.genericAttachmenViewItem }
        set { viewState.genericAttachmenViewItem = newValue }
    }
    
    public override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .portrait
    }
    
    public override var shouldAutorotate: Bool {
        false
    }
    
    /// 预览附件
    func previewAttachment(attachmentStream: TSAttachmentStream, viewItem: ConversationViewItem) {
        guard let filePath = attachmentStream.filePath(),
              FileManager.default.fileExists(atPath: filePath) else {
            return
        }
        
        let url = NSURL(fileURLWithPath: filePath)
        guard QLPreviewController.canPreview(url) else {
            DTToastHelper.show(withInfo: "Unsupported file type")
            return
        }
        genericAttachmenViewItem = viewItem
        currentPreviewFileURL = url
        previewController.reloadData()
        present(previewController, animated: true)
    }
    
    /// 点击 incoming message 中下载失败的附件
    func tapDownloadFailedAttachmentForIncomingMessage(
        viewItem: ConversationViewItem,
        attachmentPointer: TSAttachmentPointer,
        autoRestart: Bool
    ) {
        guard let message = viewItem.interaction as? TSMessage else {
            return
        }
        if autoRestart {
            redownloadAttachment(attachmentPointer, for: message)
        } else {
            showRedownloadActionSheet(attachmentPointer: attachmentPointer, for: message)
        }
    }
    
    /// 点击引用消息中下载失败的缩略图
    func tapDownloadFailedThumbnailForQuotedReply(
        _ quotedReply: OWSQuotedReplyModel,
        viewItem: ConversationViewItem,
        attachmentPointer: TSAttachmentPointer
    ) {
        guard let message = viewItem.interaction as? TSMessage else {
            owsFailDebug("message had unexpected class: \(type(of: viewItem.interaction))")
            return
        }
        
        let processor = OWSAttachmentsProcessor(attachmentPointer: attachmentPointer)
        databaseStorage.asyncWrite { transaction in
            processor.fetchAttachments(
                for: nil,
                forceDownload: true,
                transaction: transaction
            ) { [weak self] attachmentStream in
                
                guard let self else { return }
                self.databaseStorage.asyncWrite { postSuccessTransaction in
                    message.setQuotedMessageThumbnailAttachmentStream(attachmentStream)
                    message.anyInsert(transaction: transaction)
                }
                
            } failure: { [weak self] error in
                
                guard let self else { return }
                OWSLogger.warn("\(self.logTag) Failed to redownload thumbnail with error: \(error.localizedDescription)")
                
                self.databaseStorage.asyncWrite { postFailedTransaction in
                    guard let _ = message.grdbId else {
                        return
                    }
                    self.databaseStorage.touch(
                        interaction: message,
                        shouldReindex: false,
                        transaction: postFailedTransaction
                    )
                }
                
            }
        }
    }
}

// MARK: - QLPreviewControllerDataSource & QLPreviewControllerDelegate

extension ConversationViewController: QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        
    public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        1
    }
    
    public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        guard let item = self.currentPreviewFileURL else {
            return NSURL()
        }
        return item
    }
    
    public func previewControllerWillDismiss(_ controller: QLPreviewController) {
        if #available(iOS 16.0, *) {
            setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
    
    public func previewControllerDidDismiss(_ controller: QLPreviewController) {
        guard let viewItem = genericAttachmenViewItem, viewItem.isConfidentialMessage, let incomingMessage = genericAttachmenViewItem?.interaction as? TSIncomingMessage else {
            return
        }
        //mark as read confidentialMessage
        OWSReadReceiptManager.shared().confidentialMessageWasReadLocally(incomingMessage)
        //rm confidentialMessage
        databaseStorage.asyncWrite { wTransaction in
            incomingMessage.anyRemove(transaction: wTransaction)
        } completion: {
            self.genericAttachmenViewItem = nil
        }
    }
    
    public func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
        .disabled
    }
    
}

// MARK: - Private

private extension ConversationViewController {
    var currentPreviewFileURL: NSURL? {
        get {
            viewState.currentPreviewFileURL
        }
        set {
            viewState.currentPreviewFileURL = newValue
        }
    }
    
    var previewController: QLPreviewController {
        get {
            if let vc = viewState.previewController {
                return vc
            }
            let newVC = QLPreviewController()
            newVC.delegate = self
            newVC.dataSource = self
            newVC.currentPreviewItemIndex = 0
            viewState.previewController = newVC
            return newVC
        }
        set {
            viewState.previewController = newValue
        }
    }
    
    /// 重新下载附件
    func redownloadAttachment(
        _ attachmentPointer: TSAttachmentPointer,
        forceDownload: Bool = false,
        for message: TSMessage
    ) {
        let processor = OWSAttachmentsProcessor(attachmentPointer: attachmentPointer)
        processor.fetchAttachments(for: message, forceDownload: forceDownload) { _ in
            OWSLogger.info("Successfully redownloaded attachment in message timestamp: \(String(describing: message.timestampForSorting)), uniqueThreadId: \(message.uniqueThreadId)")
        } failure: { error in
            OWSLogger.warn("\(self.logTag) Failed to redownload message with error: \(error.localizedDescription)")
        }
    }
    
    /// 展示是否重新下载弹窗
    func showRedownloadActionSheet(attachmentPointer: TSAttachmentPointer, for message: TSMessage) {
        let actionSheet = ActionSheetController()
        actionSheet.addAction(OWSActionSheets.cancelAction)
        
        let retryTitle = attachmentPointer.state == .enqueued ? Localized("MESSAGES_VIEW_FAILED_DOWNLOAD_ACTION") : Localized("MESSAGES_VIEW_FAILED_DOWNLOAD_RETRY_ACTION")
        let retryAction = ActionSheetAction(title: retryTitle, style: .default) { [weak self] _ in
            guard let self else { return }
            self.redownloadAttachment(attachmentPointer, forceDownload: true, for: message)
        }
        actionSheet.addAction(retryAction)
        
        dismissKeyBoard()
        presentActionSheet(actionSheet)
    }
}

