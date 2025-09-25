//
//  FailedAttachmentDownloadsJob.swift
//  TTServiceKit
//
//  Created by Kris.s on 2022/11/19.
//

import Foundation

@objc
public class FailedAttachmentDownloadsJob: NSObject, Dependencies {
    /// Used for logging the total number of attachments modified
    private var count: UInt = 0
    public override init() {}

    @objc
    public func runSync() {
        databaseStorage.write { writeTx in
            AttachmentFinder.downloadingAttachmentPointerIds(transaction: writeTx).forEach { attachmentId in
                // Since we can't directly mutate the enumerated attachments, we store only their ids in hopes
                // of saving a little memory and then enumerate the (larger) TSAttachment objects one at a time.
                autoreleasepool {
                    self.updateAttachmentPointerIfNecessary(attachmentId, transaction: writeTx)
                }
            }
        }
        Logger.info("Finished job. Marked \(count) in-progress attachments as failed")
    }

    public func updateAttachmentPointerIfNecessary(_ uniqueId: String, transaction writeTx: SDSAnyWriteTransaction) {
        // Preconditions: Must be a valid attachment pointer that hasn't failed
        guard let attachment = TSAttachmentPointer.anyFetchAttachmentPointer(
            uniqueId: uniqueId,
            transaction: writeTx
        ) else {
            owsFailDebug("Missing attachment with id: \(uniqueId)")
            return
        }

        switch attachment.state {
        case .downloading:
            attachment.anyUpdateAttachmentPointer(transaction: writeTx) { instance in
                instance.state
                = .failed;
            }
            count += 1
            
            switch count {
            case ...3:
                Logger.info("marked attachment pointer as failed: \(attachment.uniqueId)")
            case 4:
                Logger.info("eliding logs for further attachment pointers. final count will be reported once complete.")
            default:
                break
            }
        case .enqueued, .failed:
            // This should not have been returned from `unfailedAttachmentPointerIds`
            owsFailDebug("Attachment has unexpected state \(attachment.uniqueId).")
        @unknown default:
            owsFailDebug("unknown type attachment.")
        }
    }
}
