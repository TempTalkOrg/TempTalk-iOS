//
// Copyright 2024 Difft. All rights reserved.
//
// Executes a single reaction-send attempt: builds the outgoing proto,
// dispatches through the existing ``MessageSender`` pipeline, classifies
// errors, and triggers LWW rollback on permanent failure or retry exhaustion.
//

import Foundation
import SignalCoreKit

// MARK: - Runner

public final class ReactionSendJobRunner: JobRunner, @unchecked Sendable {
    public typealias JobRecordType = ReactionSendJobRecord
    public typealias JobAttemptResultSuccessType = Void

    /// 110 retries × 15-min max backoff ≈ 24 hours total retry window.
    private static let retryLimit: UInt = 110

    private let db: any DB

    init(db: any DB) {
        self.db = db
    }

    // MARK: - JobRunner

    public func runJobAttempt(_ jobRecord: ReactionSendJobRecord) async -> JobAttemptResult<Void> {
        let sendResult: Result<Void, Error> = await withCheckedContinuation { continuation in
            let resumed = AtomicBool(false, lock: .sharedGlobal)
            self.buildAndSend(jobRecord: jobRecord) { result in
                guard resumed.tryToSetFlag() else { return }
                continuation.resume(returning: result)
            }
        }

        switch sendResult {
        case .success:
            db.write { tx in jobRecord.anyRemove(transaction: tx) }
            return .finished(.success(()))

        case .failure(let error):
            return classifyAndHandle(error, jobRecord: jobRecord)
        }
    }

    public func didFinishJob(_ jobRecordId: JobRecord.RowId, result: JobResult<Void>) async {
        // Fully silent — no toast, no badge, no system message.
    }

    // MARK: - Build & Send

    private func buildAndSend(jobRecord: ReactionSendJobRecord, completion: @escaping (Result<Void, Error>) -> Void) {
        let messageSender = SSKEnvironment.shared.messageSenderRef

        var thread: TSThread?
        db.read { tx in
            thread = TSThread.anyFetch(uniqueId: jobRecord.conversationId, transaction: tx.asSDSRead)
        }

        guard let thread else {
            Logger.error("[ReactionSend] Thread not found: \(jobRecord.conversationId)")
            completion(.failure(OWSGenericError("Thread not found.")))
            return
        }

        let realSource = DTRealSourceEntity(
            sourceWithTimestamp: jobRecord.realSourceTimestamp,
            sourceDevice: jobRecord.realSourceDevice,
            source: jobRecord.realSourceAuthor
        )

        let reactionMessage = DTReactionMessage(emoji: jobRecord.emoji, source: realSource, remove: jobRecord.removeAction)
        let outgoing = DTReactionOutgoingMessage(
            timestamp: jobRecord.operationTimestamp,
            reactionMessage: reactionMessage,
            thread: thread
        )

        var removedReactionSource: DTReactionSource?
        if jobRecord.removeAction, jobRecord.removedOriginTimestamp > 0 {
            removedReactionSource = DTReactionSource()
            removedReactionSource?.timestamp = jobRecord.removedOriginTimestamp
        }
        outgoing.reactionInfo = DTMergedReactionHandler.buildParams(reactionMessage: reactionMessage, removedReactionSource: removedReactionSource) ?? [:]

        messageSender.enqueue(outgoing, success: {
            completion(.success(()))
        }, failure: { error in
            completion(.failure(error))
        })
    }

    // MARK: - Error classification

    private func classifyAndHandle(_ error: Error, jobRecord: ReactionSendJobRecord) -> JobAttemptResult<Void> {
        if error.isRetryable, jobRecord.failureCount < Self.retryLimit {
            db.write { tx in jobRecord.addFailure(tx: tx) }
            let delay = OWSOperation.retryIntervalForExponentialBackoff(failureCount: jobRecord.failureCount)
            Logger.info("[ReactionSend] Transient failure, retrying after \(String(format: "%.1f", delay))s (attempt \(jobRecord.failureCount))")
            return .retryAfter(delay, canRetryEarly: true)
        } else {
            Logger.warn("[ReactionSend] Permanent failure (retryable=\(error.isRetryable), attempts=\(jobRecord.failureCount)), rolling back: \(error)")
            return rollbackAndFinish(jobRecord)
        }
    }

    // MARK: - Rollback

    private func rollbackAndFinish(_ jobRecord: ReactionSendJobRecord) -> JobAttemptResult<Void> {
        db.write { tx in
            ReactionSendManager.rollbackOptimisticUpdate(for: jobRecord, tx: tx)
            jobRecord.anyRemove(transaction: tx)
        }
        return .finished(.success(()))
    }
}

// MARK: - Factory

public final class ReactionSendJobRunnerFactory: JobRunnerFactory, @unchecked Sendable {
    public typealias JobRunnerType = ReactionSendJobRunner

    private let db: any DB

    public init(db: any DB) {
        self.db = db
    }

    public func buildRunner() -> ReactionSendJobRunner {
        ReactionSendJobRunner(db: db)
    }
}
