//
// Copyright 2024 Difft. All rights reserved.
//
// Single entry-point for sending emoji reactions with optimistic update.
//
//  Flow:
//   1. Optimistic-write reactionMap on the target message (instant UI).
//   2. Persist a ``ReactionSendJobRecord`` in the same DB transaction.
//   3. Enqueue the job into the ``JobQueueRunner``.
//
//  On permanent failure / retry exhaustion the runner calls ``rollbackOptimisticUpdate``.
//

import Foundation
import GRDB
import SignalCoreKit

@objc
public final class ReactionSendManager: NSObject {

    // MARK: - Singleton

    @objc public static let shared = ReactionSendManager()

    // MARK: - Properties

    private var db: (any DB)!
    private var jobQueueRunner: JobQueueRunner<
        JobRecordFinderImpl<ReactionSendJobRecord>,
        ReactionSendJobRunnerFactory
    >!
    private var isStarted = false

    private override init() {
        super.init()
    }

    // MARK: - Setup

    /// ObjC-visible entry point. Bridges to the protocol-typed ``setup(reachabilityManager:)``.
    @objc
    public func setup(reachabilityManager: SSKReachabilityManagerImpl) {
        setup(reachabilityManager: reachabilityManager as SSKReachabilityManager)
    }

    /// Call once during app launch (after ``SDSDatabaseStorage`` is ready).
    public func setup(reachabilityManager: SSKReachabilityManager) {
        let db: any DB = databaseStorage
        self.db = db
        let finder = JobRecordFinderImpl<ReactionSendJobRecord>(db: db)
        let factory = ReactionSendJobRunnerFactory(db: db)
        self.jobQueueRunner = JobQueueRunner(
            canExecuteJobsConcurrently: false,
            db: db,
            jobFinder: finder,
            jobRunnerFactory: factory
        )
        jobQueueRunner.listenForReachabilityChanges(reachabilityManager: reachabilityManager)
    }

    /// Restore persisted jobs from a previous launch.
    @objc
    public func start() {
        guard !isStarted else { return }
        isStarted = true
        jobQueueRunner.start(shouldRestartExistingJobs: true)
    }

    // MARK: - Public API (replaces ThreadUtil.sendReactionMessage)

    @objc
    public func sendReaction(
        emoji: String,
        remove: Bool,
        targetMessage: TSMessage,
        thread: TSThread
    ) {
        guard targetMessage is TSIncomingMessage || targetMessage is TSOutgoingMessage else {
            owsFailDebug("[ReactionSend] Unexpected message class: \(type(of: targetMessage))")
            return
        }

        let operationTimestamp = adjustedTimestamp(
            emoji: emoji,
            remove: remove,
            targetMessage: targetMessage
        )

        let sourceDeviceId: UInt32
        let authorId: String
        if let outgoing = targetMessage as? TSOutgoingMessage {
            sourceDeviceId = outgoing.sourceDeviceId > 0 ? outgoing.sourceDeviceId : OWSDevice.currentDeviceId()
            authorId = TSAccountManager.localNumber() ?? ""
        } else if let incoming = targetMessage as? TSIncomingMessage {
            sourceDeviceId = incoming.sourceDeviceId
            authorId = incoming.authorId
        } else {
            return
        }

        DatabaseOfflineManager.shared.canOfflineUpdateDatabase = true

        let jobRecord = db.write { tx in
            // Capture old reaction timestamp before optimistic update removes it.
            var removedOriginTimestamp: UInt64 = 0
            if remove, let reactionMap = targetMessage.reactionMap as? [String: [DTReactionSource]] {
                let localNumber = TSAccountManager.shared.localNumber(with: tx.asSDSRead) ?? ""
                if let sources = reactionMap[emoji] {
                    for source in sources where source.source == localNumber {
                        removedOriginTimestamp = source.timestamp
                        break
                    }
                }
            }

            self.removeDuplicatePendingJobs(
                conversationId: thread.uniqueId,
                realSourceTimestamp: targetMessage.timestamp,
                realSourceAuthor: authorId,
                emoji: emoji,
                tx: tx
            )

            self.applyOptimisticUpdate(
                emoji: emoji,
                remove: remove,
                operationTimestamp: operationTimestamp,
                targetMessage: targetMessage,
                thread: thread,
                authorId: authorId,
                sourceDeviceId: sourceDeviceId,
                tx: tx
            )

            let record = ReactionSendJobRecord(
                conversationId: thread.uniqueId,
                realSourceTimestamp: targetMessage.timestamp,
                realSourceDevice: sourceDeviceId,
                realSourceAuthor: authorId,
                emoji: emoji,
                removeAction: remove,
                operationTimestamp: operationTimestamp,
                removedOriginTimestamp: removedOriginTimestamp
            )
            record.anyInsert(transaction: tx)
            return record
        }

        jobQueueRunner.addPersistedJob(jobRecord)
    }

    // MARK: - Optimistic update

    private func applyOptimisticUpdate(
        emoji: String,
        remove: Bool,
        operationTimestamp: UInt64,
        targetMessage: TSMessage,
        thread: TSThread,
        authorId: String,
        sourceDeviceId: UInt32,
        tx: DBWriteTransaction
    ) {
        let localNumber = TSAccountManager.shared.localNumber(with: tx.asSDSRead) ?? ""

        let realSource = DTRealSourceEntity(
            sourceWithTimestamp: targetMessage.timestamp,
            sourceDevice: sourceDeviceId,
            source: authorId
        )
        let reactionMessage = DTReactionMessage(emoji: emoji, source: realSource, remove: remove)

        let ownSource = DTRealSourceEntity(
            sourceWithTimestamp: operationTimestamp,
            sourceDevice: OWSDevice.currentDeviceId(),
            source: localNumber
        )
        reactionMessage.ownSource = ownSource
        reactionMessage.conversationId = thread.uniqueId

        // Directly update reactionMap on the known targetMessage instead of
        // going through saveWithTransaction: which does an indirect lookup
        // via findMessageWithTransaction: that may fail to match uniqueId.
        reactionMessage.relateReactionMessage(withOriginMessage: targetMessage, transaction: tx.asSDSWrite)
    }

    // MARK: - Rollback (called by runner on permanent failure)

    public static func rollbackOptimisticUpdate(
        for jobRecord: ReactionSendJobRecord,
        tx: DBWriteTransaction
    ) {
        let localNumber = TSAccountManager.shared.localNumber(with: tx.asSDSRead) ?? ""
        let rollbackTimestamp = jobRecord.operationTimestamp + 1
        let inversedRemove = !jobRecord.removeAction

        let realSource = DTRealSourceEntity(
            sourceWithTimestamp: jobRecord.realSourceTimestamp,
            sourceDevice: jobRecord.realSourceDevice,
            source: jobRecord.realSourceAuthor
        )
        let reactionMessage = DTReactionMessage(
            emoji: jobRecord.emoji,
            source: realSource,
            remove: inversedRemove
        )
        let ownSource = DTRealSourceEntity(
            sourceWithTimestamp: rollbackTimestamp,
            sourceDevice: OWSDevice.currentDeviceId(),
            source: localNumber
        )
        reactionMessage.ownSource = ownSource
        reactionMessage.conversationId = jobRecord.conversationId
        reactionMessage.save(with: tx.asSDSWrite)
    }

    // MARK: - Deduplication

    /// For the same target message + same emoji, remove all pending job records
    /// so only the latest send (about to be inserted) survives.
    private func removeDuplicatePendingJobs(
        conversationId: String,
        realSourceTimestamp: UInt64,
        realSourceAuthor: String,
        emoji: String,
        tx: DBWriteTransaction
    ) {
        let sql = """
            SELECT * FROM \(ReactionSendJobRecord.databaseTableName)
            WHERE "\(ReactionSendJobRecord.columnName(.label))" = ?
              AND "\(ReactionSendJobRecord.columnName(.threadId))" = ?
              AND "\(ReactionSendJobRecord.columnName(.status))" = \(JobRecord.Status.ready.rawValue)
            ORDER BY "\(ReactionSendJobRecord.columnName(.id))"
        """
        let arguments: StatementArguments = [
            ReactionSendJobRecord.jobRecordType.jobRecordLabel,
            conversationId
        ]

        guard let records = try? ReactionSendJobRecord.fetchAll(tx.database, sql: sql, arguments: arguments) else {
            return
        }

        for record in records where
            record.realSourceTimestamp == realSourceTimestamp
            && record.realSourceAuthor == realSourceAuthor
            && record.emoji == emoji
        {
            Logger.info("[ReactionSend] Removing duplicate pending job \(record.uniqueId) for emoji=\(emoji)")
            record.anyRemove(transaction: tx)
        }
    }

    // MARK: - Helpers

    /// If removing and the current timestamp is behind the existing reaction,
    /// bump it by 1 to ensure LWW precedence.
    private func adjustedTimestamp(
        emoji: String,
        remove: Bool,
        targetMessage: TSMessage
    ) -> UInt64 {
        var ts = NSDate.ows_millisecondTimeStamp()
        if remove, let reactionMap = targetMessage.reactionMap as? [String: [DTReactionSource]] {
            let localNumber = TSAccountManager.localNumber() ?? ""
            if let sources = reactionMap[emoji] {
                for source in sources where source.source == localNumber {
                    if ts < source.timestamp {
                        ts = source.timestamp + 1
                    }
                    break
                }
            }
        }
        return ts
    }
}
