//
//  DTUploadAttachmentPointerOperation.swift
//  TTServiceKit
//
//  Created by Jaymin on 2024/11/29.
//

import Foundation
import SignalCoreKit

// 处理转发本地未下载的附件
@objc public class DTUploadAttachmentPointerOperation: OWSOperation, @unchecked Sendable {
    
    private let attachmentId: String
    private let recipientIds: [String]
    
    @objc public var rapidFileCallback: ((DTRapidFile) -> Void)?
    
    @objc public init(attachmentId: String, recipientIds: [String]) {
        self.attachmentId = attachmentId
        self.recipientIds = recipientIds
        
        super.init()
        self.remainingRetries = 4
    }
    
    public override func run() {
        var attachmentPointer: TSAttachmentPointer?
        self.databaseStorage.read { transaction in
            attachmentPointer = TSAttachmentPointer.anyFetchAttachmentPointer(uniqueId: self.attachmentId, transaction: transaction)
        }
        guard let attachmentPointer, !attachmentPointer.encryptionKey.isEmpty else {
            Logger.error(OWSAnalyticsEvents.messageSenderErrorCouldNotLoadAttachment())
            let error = OWSErrorMakeFailedToSendOutgoingMessageError()
            reportError(error)
            return
        }
        
        let originKey = attachmentPointer.encryptionKey
        guard let keyHash = SSKCryptography.computeSHA256Digest(originKey)?.base64EncodedString() else {
            Logger.error("get key hash failed for attachment id: \(attachmentPointer.uniqueId)")
            let error = OWSErrorMakeFailedToSendOutgoingMessageError()
            reportError(error)
            return
        }
        
        DTFileRequestHandler.checkFileExists(withFileHash: keyHash, recipients: self.recipientIds) { [weak self] entity, error in
            guard let self else { return }
            if let error {
                Logger.error("checkFileExists failed with error: \(error.localizedDescription)")
                self.reportError(error)
                return
            }
            guard let entity, entity.exists  else {
                Logger.error("checkFileExists with error: entity not exists")
                let error = OWSErrorCheckAttachmentError("file not exists")
                self.reportError(error)
                return
            }
            guard !entity.cipherHash.isEmpty, !entity.attachmentId.isEmpty else {
                Logger.error("checkFileExistsWithFileHash with error: attachmentId or url == nil")
                let error = OWSErrorCheckAttachmentError("attachmentId or url == nil")
                self.reportError(error)
                return
            }
            let rapidFile = DTRapidFile()!
            rapidFile.rapidHash = keyHash
            rapidFile.authorizedId = entity.authorizeId
            self.rapidFileCallback?(rapidFile)
            
            self.handleSuccess(with: attachmentPointer, serverId: entity.authorizeIdToInt)
        }
    }
    
    private func handleSuccess(with attachmentPointer: TSAttachmentPointer, serverId: UInt64) {
        self.databaseStorage.asyncWrite { transaction in
            // checkFileExists 后，若 recipientIds 不同，将会产生新的 serverId，需要进行更新
            attachmentPointer.updateAfterFileCheck(withServerId: serverId, transaction: transaction)
            
            transaction.addAsyncCompletionOnMain {
                self.reportSuccess()
            }
        }
    }
}
