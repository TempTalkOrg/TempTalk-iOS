//
//  TSMessageReadPositionMigrator.swift
//  TTServiceKit
//
//  Created by Kris on 2026/01/21.
//

import Foundation
import GRDB
import SignalCoreKit

/// 专门处理 TSMessageReadPosition 历史数据回填的迁移类
/// 采用渐进式处理：每次启动处理一批，直到全部完成
@objc
public class TSMessageReadPositionMigrator: NSObject {

    @objc
    public static let shared = TSMessageReadPositionMigrator()

    // KeyValueStore 用于存储迁移进度
    private let migrationStore = SDSKeyValueStore(collection: "TSMessageReadPositionMigration")
    private let checkpointKey = "backfill_checkpoint_timestamp"
    private let completedKey = "backfill_completed"
    private let maxTimestampKey = "backfill_max_timestamp"

    private override init() {
        super.init()
    }

    /// 便捷方法：在后台异步执行迁移（用于应用启动时调用）
    @objc
    public func performMigrationIfNeeded() {
        DispatchQueue.global(qos: .utility).async {
            SDSDatabaseStorage.shared.write { transaction in
                let timeThreshold: UInt64 = 60 * 60 * 1000 // 1 hour
                let result = self.backfillSyncOutgoingReadPositions(
                    batchSize: 500,
                    timeThresholdMillis: timeThreshold,
                    transaction: transaction
                )

                if result.completed {
                    OWSLogger.info("TSMessageReadPositionMigrator: migration completed")
                } else {
                    OWSLogger.info("TSMessageReadPositionMigrator: processed \(result.processed) messages, inserted \(result.inserted) positions, will continue on next launch")
                }
            }
        }
    }

    /// 渐进式回填历史同步消息的 readPosition
    /// 每次启动处理一批（默认500条），直到全部完成
    /// - Parameters:
    ///   - batchSize: 每批处理的消息数量，默认 500
    ///   - timeThresholdMillis: 时间阈值（毫秒），建议 1 小时
    ///   - transaction: 写事务
    /// - Returns: (是否已完成, 本次处理的消息数, 本次插入的 position 数)
    public func backfillSyncOutgoingReadPositions(
        batchSize: Int = 500,
        timeThresholdMillis: UInt64,
        transaction: SDSAnyWriteTransaction
    ) -> (completed: Bool, processed: Int, inserted: Int) {

        let startTime = CACurrentMediaTime()

        // 1. 检查是否已完成
        if migrationStore.getBool(completedKey, defaultValue: false, transaction: transaction) {
            OWSLogger.info("TSMessageReadPositionMigrator: already completed")
            return (true, 0, 0)
        }

        // 2. 获取本地用户号码（从事务中读取确保一致性）
        guard let localNumber = TSAccountManager.shared.localNumber(with: transaction) else {
            OWSLogger.warn("TSMessageReadPositionMigrator: localNumber is nil, skipping")
            return (false, 0, 0)
        }

        // 3. 首次运行：记录最大 timestamp 作为上界
        let maxTimestamp: UInt64
        if let stored = migrationStore.getUInt64(maxTimestampKey, transaction: transaction) {
            maxTimestamp = stored
        } else {
            // 查询当前最大的 timestamp
            maxTimestamp = queryMaxSyncOutgoingTimestamp(transaction: transaction)
            if maxTimestamp == 0 {
                // 没有同步消息，直接标记完成
                migrationStore.setBool(true, key: completedKey, transaction: transaction)
                OWSLogger.info("TSMessageReadPositionMigrator: no sync messages found, marked as completed")
                return (true, 0, 0)
            }
            migrationStore.setUInt64(maxTimestamp, key: maxTimestampKey, transaction: transaction)
            OWSLogger.info("TSMessageReadPositionMigrator: initialized maxTimestamp = \(maxTimestamp)")
        }

        // 4. 获取当前 checkpoint（已处理到的位置）
        let checkpoint = migrationStore.getUInt64(checkpointKey, defaultValue: 0, transaction: transaction)

        // 5. 查询本批消息（checkpoint < timestamp <= maxTimestamp）
        let messages = querySyncOutgoingMessages(
            minTimestamp: checkpoint,
            maxTimestamp: maxTimestamp,
            batchSize: batchSize,
            transaction: transaction
        )

        guard !messages.isEmpty else {
            // 没有更多消息，标记完成
            migrationStore.setBool(true, key: completedKey, transaction: transaction)
            OWSLogger.info("TSMessageReadPositionMigrator: completed, no more messages")
            return (true, 0, 0)
        }

        // 6. 按 thread 分组（保持消息顺序）
        // 备忘录消息已在 SQL 查询时过滤，无需在此处理
        var threadMessagesMap: [String: [TSOutgoingMessage]] = [:]
        for message in messages {
            let threadId = message.uniqueThreadId

            if threadMessagesMap[threadId] == nil {
                threadMessagesMap[threadId] = []
            }
            threadMessagesMap[threadId]?.append(message)
        }

        var totalInserted = 0

        // 7. 对每个 thread 进行纯内存合并并批量写入
        for (threadId, threadMessages) in threadMessagesMap {
            // threadMessages 已经按 timestamp 升序排列

            var anchorPosition: TSMessageReadPosition? = nil

            for message in threadMessages {
                if let anchor = anchorPosition {
                    // 和基准时间比较
                    let anchorReadAt = anchor.readAt
                    let currentReadAt = message.timestamp
                    let timeDiff = currentReadAt > anchorReadAt ?
                                  currentReadAt - anchorReadAt :
                                  anchorReadAt - currentReadAt

                    if timeDiff >= timeThresholdMillis {
                        // 超过阈值，写入当前基准，创建新基准
                        anchor.anyInsert(transaction: transaction)
                        totalInserted += 1

                        // 创建新基准（使用当前消息）
                        anchorPosition = TSMessageReadPosition(
                            uniqueThreadId: threadId,
                            recipientId: localNumber,
                            readPosition:DTReadPositionEntity(groupId: nil, readAt: message.timestamp, maxServerTime: message.serverTimestamp, notifySequenceId: message.notifySequenceId, maxSequenceId: message.sequenceId
                            )
                        )
                    } else {
                        // 在阈值内，需要更新时重新创建对象，确保 uniqueId 与 maxServerTime 一致
                        if message.serverTimestamp > anchor.maxServerTime {
                            // 重新创建对象，保持 readAt 不变（基准时间），更新 maxServerTime 和 updateCount
                            let newPosition = TSMessageReadPosition(
                                uniqueThreadId: threadId,
                                recipientId: localNumber,
                                readPosition: DTReadPositionEntity(
                                    groupId: nil,
                                    readAt: anchor.readAt,  // 保持原来的 readAt（基准时间）
                                    maxServerTime: message.serverTimestamp,  // 使用新的 maxServerTime
                                    notifySequenceId: message.notifySequenceId,
                                    maxSequenceId: message.sequenceId
                                )
                            )
                            // 更新 updateCount，表示这条记录被合并更新过
                            newPosition.updateCount = anchor.updateCount + 1
                            anchorPosition = newPosition
                        }
                    }
                } else {
                    // 该 thread 在本批次首次出现，创建基准
                    anchorPosition = TSMessageReadPosition(
                        uniqueThreadId: threadId,
                        recipientId: localNumber,
                        readPosition: DTReadPositionEntity(groupId: nil, readAt: message.timestamp, maxServerTime: message.serverTimestamp, notifySequenceId: message.notifySequenceId, maxSequenceId: message.sequenceId
                        )
                    )
                }
            }

            // 批次结束，写入该 thread 剩余的基准
            if let finalPosition = anchorPosition {
                finalPosition.anyInsert(transaction: transaction)
                totalInserted += 1
            }
        }

        // 8. 更新 checkpoint（最后一条消息的 timestamp）
        if let lastMessage = messages.last {
            migrationStore.setUInt64(lastMessage.timestamp, key: checkpointKey, transaction: transaction)
        }

        let processed = messages.count
        let timeElapsed = CACurrentMediaTime() - startTime
        let formattedTime = String(format: "%.2fms", timeElapsed * 1000)

        OWSLogger.info("TSMessageReadPositionMigrator: processed \(processed) messages, inserted \(totalInserted) positions, checkpoint = \(messages.last?.timestamp ?? 0), duration: \(formattedTime)")

        return (false, processed, totalInserted)
    }

    /// 查询当前所有 outgoing 消息的最大 timestamp（用于历史数据回填）
    /// 只考虑无未读消息的 thread，有未读的 thread 会通过正常已读流程处理
    private func queryMaxSyncOutgoingTimestamp(transaction: SDSAnyWriteTransaction) -> UInt64 {
        let startTime = CACurrentMediaTime()

        let sql = """
        SELECT MAX(i.\(interactionColumn: .timestamp))
        FROM \(InteractionRecord.databaseTableName) i
        INNER JOIN \(ThreadRecord.databaseTableName) t ON i.\(interactionColumn: .threadUniqueId) = t.\(threadColumn: .uniqueId)
        WHERE i.\(interactionColumn: .recordType) = ?
        AND t.\(threadColumn: .unreadMessageCount) = 0
        """

        let arguments: StatementArguments = [
            SDSRecordType.outgoingMessage.rawValue
        ]

        var result: UInt64 = 0

        switch transaction.writeTransaction {
        case .grdbWrite(let grdbWrite):
            do {
                if let maxTimestamp = try UInt64.fetchOne(grdbWrite.database, sql: sql, arguments: arguments) {
                    result = maxTimestamp
                }
            } catch {
                OWSLogger.error("queryMaxSyncOutgoingTimestamp error: \(error)")
            }
        }

        let timeElapsed = CACurrentMediaTime() - startTime
        let formattedTime = String(format: "%.2fms", timeElapsed * 1000)
        OWSLogger.info("TSMessageReadPositionMigrator: queryMaxSyncOutgoingTimestamp = \(result), duration: \(formattedTime)")

        return result
    }

    /// 查询一批 outgoing 消息（minTimestamp < timestamp <= maxTimestamp）
    /// 排除备忘录 thread 的消息和有未读消息的 thread
    private func querySyncOutgoingMessages(
        minTimestamp: UInt64,
        maxTimestamp: UInt64,
        batchSize: Int,
        transaction: SDSAnyWriteTransaction
    ) -> [TSOutgoingMessage] {

        let startTime = CACurrentMediaTime()

        // 获取备忘录 thread 的 uniqueId
        let noteToSelfThreadId = TSContactThread.threadId(fromContactId: TSAccountManager.shared.localNumber(with: transaction) ?? "")

        let sql = """
        SELECT i.* FROM \(InteractionRecord.databaseTableName) i
        INNER JOIN \(ThreadRecord.databaseTableName) t ON i.\(interactionColumn: .threadUniqueId) = t.\(threadColumn: .uniqueId)
        WHERE i.\(interactionColumn: .recordType) = ?
        AND i.\(interactionColumn: .timestamp) > ?
        AND i.\(interactionColumn: .timestamp) <= ?
        AND i.\(interactionColumn: .threadUniqueId) != ?
        AND t.\(threadColumn: .unreadMessageCount) = 0
        ORDER BY i.\(interactionColumn: .timestamp) ASC
        LIMIT ?
        """

        let arguments: StatementArguments = [
            SDSRecordType.outgoingMessage.rawValue,
            minTimestamp,
            maxTimestamp,
            noteToSelfThreadId,
            batchSize
        ]

        var messages: [TSOutgoingMessage] = []

        switch transaction.writeTransaction {
        case .grdbWrite(let grdbWrite):
            do {
                let cursor = TSInteraction.grdbFetchCursor(sql: sql, arguments: arguments, transaction: grdbWrite)
                while let interaction = try cursor.next() {
                    if let outgoingMessage = interaction as? TSOutgoingMessage {
                        messages.append(outgoingMessage)
                    }
                }
            } catch {
                OWSLogger.error("querySyncOutgoingMessages error: \(error)")
            }
        }

        let timeElapsed = CACurrentMediaTime() - startTime
        let formattedTime = String(format: "%.2fms", timeElapsed * 1000)
        OWSLogger.info("TSMessageReadPositionMigrator: querySyncOutgoingMessages fetched \(messages.count) messages, duration: \(formattedTime)")

        return messages
    }

    /// 重置迁移状态（仅用于测试或重新迁移）
    @objc
    public func resetMigrationState(transaction: SDSAnyWriteTransaction) {
        migrationStore.removeValue(forKey: checkpointKey, transaction: transaction)
        migrationStore.removeValue(forKey: completedKey, transaction: transaction)
        migrationStore.removeValue(forKey: maxTimestampKey, transaction: transaction)
        OWSLogger.info("TSMessageReadPositionMigrator: reset migration state")
    }
}
