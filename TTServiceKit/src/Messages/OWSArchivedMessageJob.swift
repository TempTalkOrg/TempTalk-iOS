//
//  OWSArchivedMessageJob.swift
//  TTServiceKit
//
//  Created by user on 2024/7/3.
//

import Foundation
extension OWSArchivedMessageJob {
    /// 当前方法会将数据直接插入到归档消息的表格中
    @objc @discardableResult public func checkAndArchive(message: TSMessage, withThread thread: TSThread, transaction: SDSAnyWriteTransaction) -> Bool {
        
        if needArchive(message: message, withThread: thread) {
            self.archiveMessage(message, transaction: transaction)
            return true
        }
        
        return false
    }        
    @objc public func needArchive(message: TSMessage, withThread thread: TSThread) -> Bool {
        if let threadConfig = thread.threadConfig, message.serverTimestamp < threadConfig.endTimestamp {
            return true
        }
        return false
    }
}
