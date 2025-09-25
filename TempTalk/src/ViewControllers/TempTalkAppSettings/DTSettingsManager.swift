//
//  DTSettingsManager.swift
//  Difft
//
//  Created by Henry on 2025/6/15.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import GRDB

@objcMembers
open class DTSettingsManager: NSObject, ObservableObject, DTSettingsManagerProtocol {
    static let shared = DTSettingsManager()
    
    private let serialQueue = DispatchQueue(label: "com.temptalk.resetKeyConsumer")
    
    private let keyValueStore = SDSKeyValueStore(collection: "ResetIdentifyKeyValueCollection")
    static let kSystemMessagesKeyMapNotification = "kSystemMessagesKeyMapNotification"
    private var isCheckingResetKeyMap = false
    
    deinit {
        isCheckingResetKeyMap = false
    }
    
    public func syncRemoteProfileInfo() {
        DTChatProfileInfoApi().profileInfo(sucess: { entity in
            if entity?.status == 0,
               let data = entity?.data,
               let contacts = data["contacts"] as? [[String: Any]],
               let contact = contacts.first,
               let privateConfigs = contact["privateConfigs"] as? [String: Any] {
                let saveToPhotos = privateConfigs["saveToPhotos"] as? Bool ?? false
                MediaSavePolicyManager.shared.updateSaveToPhoto(needSave: saveToPhotos)
                Logger.info("sync save to photos \(saveToPhotos)")
            }
        }) { _ in
            Logger.info("sync save to photos failure")
        }
    }
    
    public func deleteResetIdentityKeyThreads(operatorId: String, resetIdentityKeyTime: UInt64) {
        Logger.info("\(logTag) begin deleting reset identity key threads")
        // 本地存储
        databaseStorage.asyncWrite { transaction in
            let resetRecord = ResetIdentifyKeyRecord(operatorId: operatorId, resetIdentifyKeyTime: resetIdentityKeyTime, isCompleted: false)
            resetRecord.anyInsert(transaction: transaction)
        } completion: {
            // 监听
            MessageArchiver.shared.registerAppStateObserver()
            // 检查Map
            self.checkResetKeyMap()
        }
    }
    
    func checkResetKeyMap() {
        guard !isCheckingResetKeyMap else { return }
        isCheckingResetKeyMap = true
        clearMapInfos()
        var records: [ResetIdentifyKeyRecord] = []
        databaseStorage.asyncRead { transaction in
            do {
                records = try AnyResetIdentifyKeyRecordFinder.fetchResetKeyRecords(transaction: transaction)
            } catch {
                Logger.info("\(self.logTag) fetch records failure")
            }
        } completion: {
            for record in records {
                guard !record.isCompleted else {
                    continue
                }
                
                self.serialQueue.async {
                    self.deleteRestKeyMessages(entity: record)
                }
            }
            self.isCheckingResetKeyMap = false
        }
    }
    
    func checkResetIdentifyKey() {
        var resetTime: UInt64 = 0
        databaseStorage.asyncRead { transaction in
            resetTime = AnyResetIdentifyKeyRecordFinder.lastResetKeyRecord(transaction: transaction)
        } completion: {
            DTQueryIdentityKeyApi().quertIdentity([], resetIdentityKeyTime: resetTime) { response in
                guard let responseObject = response.responseBodyJson as? [String: Any],
                      let data = responseObject["data"] as? [String: Any],
                      let keys = data["keys"] as? [[String: Any]] else {
                    Logger.error("\(self.logTag) prase queryIdentity failed")
                    return
                }
                do {
                    if let identityKeys = try MTLJSONAdapter.models(of: DTPrekeyBundle.self, fromJSONArray: keys) as? [DTPrekeyBundle] {
                        self.batchInsert(identityKeys: identityKeys, completion: {
                            self.checkResetKeyMap()
                        })
                    }
                } catch {
                    Logger.error("\(self.logTag) prase DTPrekeyBundle model failed")
                }
           }
        }
    }
}

// utils
extension DTSettingsManager {
    private func filterArchiveMessages(from interactions: [TSInteraction]) -> [TSMessage] {
        interactions.compactMap { interaction in
            if let msg = interaction as? TSMessage {
                return msg
            }
            return nil
        }
    }
    
    private func fetchThreadsToUpdate(from transaction: SDSAnyReadTransaction, operatorId: String,  resetIdentityKeyTime: UInt64) -> [TSThread] {
        var threadsToUpdate: [TSThread] = []

        do {
            try Bench(title: "QueryThreadsToUpdate") {
                guard case let .grdbRead(grdb) = transaction.readTransaction else { return }

                let currentThreadId = TSContactThread.threadId(fromContactId: TSAccountManager.localNumber() ?? "")
                
                var sql = ""
                var args: StatementArguments = []
                
                if TSAccountManager.localNumber() == operatorId {
                    sql = """
                        SELECT *
                        FROM \(ThreadRecord.databaseTableName)
                        WHERE (\(threadColumn: .recordType) IS \(SDSRecordType.contactThread.rawValue))
                          AND \(threadColumn: .uniqueId) IN (
                              -- outgoing messages
                              SELECT \(interactionColumn: .threadUniqueId)
                              FROM \(InteractionRecord.databaseTableName)
                              WHERE \(interactionColumn: .threadUniqueId) != ?
                                AND \(interactionColumn: .serverTimestamp) < ?
                                AND \(interactionColumn: .recordType) = \(SDSRecordType.outgoingMessage.rawValue)
                          )
                        ORDER BY \(threadColumn: .stickCallingDate) DESC,
                                 \(threadColumn: .stickDate) DESC,
                                 \(threadColumn: .lastMessageDate) DESC
                    """
                    args = [
                        currentThreadId,
                        resetIdentityKeyTime
                    ]
                    
                } else {
                    sql = """
                        SELECT *
                        FROM \(ThreadRecord.databaseTableName)
                        WHERE (\(threadColumn: .recordType) IS \(SDSRecordType.contactThread.rawValue))
                          AND \(threadColumn: .uniqueId) IN (
                              SELECT \(interactionColumn: .threadUniqueId)
                              FROM \(InteractionRecord.databaseTableName)
                              WHERE \(interactionColumn: .threadUniqueId) != ?
                                AND \(interactionColumn: .serverTimestamp) < ?
                                AND \(interactionColumn: .authorId) = ?
                                AND (\(interactionColumn: .recordType) IS \(SDSRecordType.incomingMessage.rawValue))
                          )
                        ORDER BY \(threadColumn: .stickCallingDate) DESC,
                                 \(threadColumn: .stickDate) DESC,
                                 \(threadColumn: .lastMessageDate) DESC
                    """
                    args = [
                        currentThreadId,
                        resetIdentityKeyTime,
                        operatorId
                    ]
                }

                let cursor = TSThread.grdbFetchCursor(sql: sql, arguments: args, transaction: grdb)
                while let thread = try cursor.next() {
                    threadsToUpdate.append(thread)
                }
            }
        } catch {
            Logger.error("\(self.logTag) failed to fetch threads: \(error)")
        }

        return threadsToUpdate
    }
    
    func insertSystemMessages(
        for threads: [TSThread],
        operatorId: String,
        expiredAt: UInt64
    ) {
        var map = getSystemMessagesMap()
        var hasChanged = false

        for thread in threads {
            let key = makeSystemMessagesKey(uniqueId: thread.uniqueId, operatorId: operatorId, expiredAt: expiredAt)

            if let entry = map[key], entry.systemMessageInserted {
                continue  // 已插入，跳过
            }

            // 插入本地系统消息
            generateSystemMessage(for: thread, operatorId: operatorId)

            // 标记已插入
            map[key] = InsertSystemMessageEntry(
                operatorId: operatorId,
                resetIdentifyKeyTime: expiredAt,
                systemMessageInserted: true
            )

            hasChanged = true
        }

        if hasChanged {
            saveSystemMessagesMap(map)
        }
    }
    
    private func generateSystemMessage(for thread: TSThread, operatorId: String) {
        let rawName = Environment.shared.contactsManager.displayName(forPhoneIdentifier: operatorId)
        let systemText = "\(rawName)\(Localized("RESET_IDENTITY_KEY_TIPS"))"

        if let contactThread = thread as? TSContactThread {
            self.databaseStorage.asyncWrite { transaction in
                let systemMessage = TSInfoMessage(
                    timestamp: Date.ows_millisecondTimestamp(),
                    in: contactThread,
                    messageType: .resetIdentityKey,
                    expiresInSeconds: contactThread.messageExpiresInSeconds(),
                    customMessage: systemText
                )
                systemMessage.anyInsert(transaction: transaction)
            }
        }
    }
    
    func makeSystemMessagesKey(uniqueId: String, operatorId: String, expiredAt: UInt64) -> String {
        return "\(uniqueId)_\(operatorId)_\(Int(expiredAt))"
    }
    
    func clearMapInfos() {
        clearsystemMessagesMapValues()
    }
    
    private func clearsystemMessagesMapValues() {
        var systemMessagesKeyMap: [String: InsertSystemMessageEntry] = getSystemMessagesMap()
        for (key, entry) in systemMessagesKeyMap {
            if entry.systemMessageInserted {
                systemMessagesKeyMap.removeValue(forKey: key)
            }
        }
        saveSystemMessagesMap(systemMessagesKeyMap)
    }
    
    func deleteRestKeyMessages(entity: ResetIdentifyKeyRecord) {
        if MessageArchiver.shared.getIsArchiving() {
            // 如果当前有归档任务就不执行
            return
        }
        let operatorId: String = entity.operatorId
        let resetIdentifyKeyTime: UInt64 = entity.resetIdentifyKeyTime
        
        var threadsToUpdate: [TSThread] = []
        databaseStorage.asyncRead { transaction in
            threadsToUpdate = self.fetchThreadsToUpdate(from: transaction, operatorId: operatorId,  resetIdentityKeyTime: resetIdentifyKeyTime)
        } completion: {
            self.insertSystemMessages(for: threadsToUpdate, operatorId: operatorId, expiredAt: resetIdentifyKeyTime)
        }
        
        
        var filtered: [TSMessage] = []
        databaseStorage.asyncRead { transaction in
            var messagesToArchive: [TSInteraction] = []
            if TSAccountManager.localNumber() == operatorId {
                // 获取outgoing消息
                messagesToArchive += InteractionFinder
                    .fetchOutgoingMessages(beforeTimestamp: resetIdentifyKeyTime, transaction: transaction)
            } else {
                // 获取incoming消息
                messagesToArchive += InteractionFinder
                    .fetchIncomingMessages(authorId: operatorId, beforeTimestamp: resetIdentifyKeyTime, transaction: transaction)
            }
            
            filtered = self.filterArchiveMessages(from: messagesToArchive)
        } completion: {
            // 消息归档
            MessageArchiver.shared.enqueue(messages: filtered, entity: entity)
        }
    }

    func batchInsert(identityKeys: [DTPrekeyBundle], completion: @escaping () -> Void) {
        guard !identityKeys.isEmpty else {
            completion()
            return
        }

        let pageSize = 50
        let totalPages = Int(ceil(Double(identityKeys.count) / Double(pageSize)))
        insertPage(at: 0, totalPages: totalPages, identityKeys: identityKeys, completion: completion)
    }

    private func insertPage(at currentPage: Int,
                            totalPages: Int,
                            identityKeys: [DTPrekeyBundle],
                            completion: @escaping () -> Void) {
        guard currentPage < totalPages else {
            completion()
            return
        }
        let pageSize = 50

        let start = currentPage * pageSize
        let end = min(start + pageSize, identityKeys.count)
        let pageArray = Array(identityKeys[start..<end])

        databaseStorage.asyncWrite { transaction in
            for bundle in pageArray {
                let record = ResetIdentifyKeyRecord(operatorId: bundle.uid ?? "",
                                                    resetIdentifyKeyTime: UInt64(bundle.resetIdentityKeyTime),
                                                    isCompleted: false)
                record.anyInsert(transaction: transaction)
            }

            transaction.addAsyncCompletionOnMain {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.insertPage(at: currentPage + 1,
                                    totalPages: totalPages,
                                    identityKeys: identityKeys,
                                    completion: completion)
                }
            }
        }
    }
}

extension DTSettingsManager {
    public func getSystemMessagesMap() -> [String: InsertSystemMessageEntry] {
        var map: [String: InsertSystemMessageEntry] = [:]
        self.databaseStorage.read { transaction in
            do {
                if let jsonString: String = self.keyValueStore.getString(
                    DTSettingsManager.kSystemMessagesKeyMapNotification,
                    transaction: transaction
                ), let data = jsonString.data(using: .utf8) {
                    map = try JSONDecoder().decode([String: InsertSystemMessageEntry].self, from: data)
                }
            } catch {
                Logger.error("\(self.logTag) failed to fetch systemMessages map: \(error)")
            }
        }
        return map
    }

    public func saveSystemMessagesMap(_ map: [String: InsertSystemMessageEntry]) {
        if let jsonData = try? JSONEncoder().encode(map),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            self.databaseStorage.write { transaction in
                self.keyValueStore.setString(jsonString, key: DTSettingsManager.kSystemMessagesKeyMapNotification, transaction: transaction)
            }
        }
    }
    
}

@objc
class MessageArchiver: NSObject {
    static let shared = MessageArchiver()

    private let archiveBatchSize = 50
    private let archiveDelay: TimeInterval = 1.0
    private var pendingMessages: [TSMessage] = []

    private override init() {}
    private var isArchiving = false
    private var resetRecord: ResetIdentifyKeyRecord? = nil

    // 外部传入待处理消息
    func enqueue(messages: [TSMessage], entity: ResetIdentifyKeyRecord) {
        pendingMessages.append(contentsOf: messages)
        resetRecord = entity
        if !isArchiving {
            Logger.info("\(self.logTag) messages isArchiving")
            tryResumeIfNeeded()
        }
    }
    
    func getIsArchiving() -> Bool {
        return isArchiving
    }

    // 根据条件判断是否应中断
    private func shouldHandleMessages() -> Bool {
        let ctx = CurrentAppContext()

        if !ctx.isMainApp || !ctx.isAppForegroundAndActive() {
            return false
        }
        return true
    }

    // 尝试开始任务
    func tryResumeIfNeeded() {
        isArchiving = true
        processNextBatch()
    }

    // 真正执行归档
    private func processNextBatch() {
        guard shouldHandleMessages() else {
            resetArchiving()
            Logger.info("\(self.logTag) messages interrupt")
            return
        }
        
        guard !pendingMessages.isEmpty else {
            databaseStorage.asyncWrite { transaction in
                if let record = self.resetRecord {
                    do {
                        try AnyResetIdentifyKeyRecordFinder.updateResetKeyCompleted(operationId: record.operatorId, resetIdentifyKeyTime: record.resetIdentifyKeyTime, transaction: transaction)
                    } catch {
                        Logger.info("\(self.logTag) update record failure")
                    }
                }
            } completion: {
                // 已经都删除完毕
                self.resetArchiving()
                // 再次去循环队列，看看有没有任务需要执行
                DTSettingsManager.shared.checkResetKeyMap()
            }
            return
        }

        let batch = Array(pendingMessages.prefix(archiveBatchSize))
        pendingMessages.removeFirst(min(archiveBatchSize, pendingMessages.count))
        
        BenchManager.bench(title: "clearResetIndentifyKeyMessages") {
            databaseStorage.asyncWrite { transaction in
                for msg in batch {
                    msg.anyRemove(transaction: transaction)
                }
                
//                let idsToDelete = batch.map { $0.uniqueId }
//                guard !idsToDelete.isEmpty else {
//                    // 标记下当前已经结束
//                    self.resetArchiving()
//                    Logger.info("\(self.logTag) clear messages end")
//                    return
//                }
//                DTSettingsManager.shared.updateCurrentResetIdentifyStatusKeyData(isCompeted: false)
//              
//                let sql = """
//                          DELETE
//                          FROM \(InteractionRecord.databaseTableName)
//                          WHERE \(interactionColumn: .uniqueId) IN (\(idsToDelete.map { "\'\($0)'" }.joined(separator: ",")))
//                          """
//                let arguments: StatementArguments = []
//
//                switch transaction.writeTransaction {
//                case .grdbWrite(let grdbWrite):
//                    // 4. 执行 SQL
//                    grdbWrite.executeWithCachedStatement(sql: sql, arguments: arguments)
//                }
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + self.archiveDelay) {
            self.processNextBatch()
        }
    }

    // 恢复时调用
    func registerAppStateObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        tryResumeIfNeeded()
    }

    // 清除监听（若需要）
    func stop() {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func resetArchiving() {
        isArchiving = false
        resetRecord = nil
    }
}

public struct InsertSystemMessageEntry: Codable {
    let operatorId: String
    let resetIdentifyKeyTime: UInt64
    var systemMessageInserted: Bool
}
