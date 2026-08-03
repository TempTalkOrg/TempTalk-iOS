//
// Copyright 2024 Difft. All rights reserved.
//
// Executes a single GIF favorite attempt: resolves the account-level pointer
// (uploading the panel WebP or re-checking a message attachment when needed),
// commits it through the existing favorites CAS flush, classifies errors, and
// rolls back the optimistic state on permanent failure or retry exhaustion.
//

import Foundation
import SignalCoreKit

// MARK: - Runner

public final class DTGifFavoriteJobRunner: JobRunner, @unchecked Sendable {
    public typealias JobRecordType = DTGifFavoriteJobRecord
    public typealias JobAttemptResultSuccessType = Void

    /// 110 retries × 15-min max backoff ≈ 24 hours total retry window (aligned with reactions).
    private static let retryLimit: UInt = 110

    private let db: any DB
    private let localStore = DTGifFavoriteLocalStore()

    init(db: any DB) {
        self.db = db
    }

    // MARK: - JobRunner

    public func runJobAttempt(_ jobRecord: DTGifFavoriteJobRecord) async -> JobAttemptResult<Void> {
        var effectiveFileHash = jobRecord.fileHash
        do {
            switch jobRecord.op {
            case .favorite:
                let resolved = try await resolvePointer(jobRecord)
                effectiveFileHash = resolved.fileHash
                // Swap the placeholder pending op for the resolved pointer (fileHash may change for panel).
                let stillWanted = db.write { tx in
                    self.localStore.resolvePendingFavorite(
                        placeholderFileHash: jobRecord.fileHash,
                        resolved: resolved,
                        giphyId: jobRecord.giphyId,
                        tx.asSDSWrite
                    )
                }
                // User unfavorited while the upload was in flight — don't resurrect it. Drop the job
                // and its seeds; the (now orphaned) account-level asset is harmless.
                guard stillWanted else {
                    db.write { tx in jobRecord.anyRemove(transaction: tx) }
                    DTGifFavoriteAssetLoader.shared.removeCachedAsset(fileHash: jobRecord.fileHash)
                    DTGifFavoriteAssetLoader.shared.removePendingUpload(fileHash: jobRecord.fileHash)
                    if jobRecord.fileHash != resolved.fileHash {
                        DTGifFavoriteAssetLoader.shared.removeCachedAsset(fileHash: resolved.fileHash)
                    }
                    return .finished(.success(()))
                }
                // Keep display seamless: move the seeded local asset onto the real fileHash.
                if jobRecord.fileHash != resolved.fileHash, let webp = jobRecord.localWebpPath {
                    DTGifFavoriteAssetLoader.shared.seedLocalAsset(fileHash: resolved.fileHash, sourcePath: webp)
                }
                // Single-op: commit ONLY this favorite. Other pending ops are owned by their own jobs,
                // so one op's failure can never roll back or block another.
                try await DTGifFavoritesRepository.shared.commitFavorite(resolved)

            case .unfavorite:
                try await DTGifFavoritesRepository.shared.commitUnfavorite(fileHash: jobRecord.fileHash)

            case .rewrap, .reset:
                throw OWSGenericError("[GifFav] unexpected op in gif favorite job")
            }

            db.write { tx in jobRecord.anyRemove(transaction: tx) }
            // Upload done → drop the durable staging copy (keyed by the original/temp fileHash).
            if jobRecord.op == .favorite, jobRecord.localWebpPath != nil {
                DTGifFavoriteAssetLoader.shared.removePendingUpload(fileHash: jobRecord.fileHash)
            }
            Logger.info("[GifFav] job committed op=\(jobRecord.op.rawValue) fileHash=\(effectiveFileHash.prefix(8))")
            return .finished(.success(()))
        } catch {
            return handleFailure(error, jobRecord: jobRecord, effectiveFileHash: effectiveFileHash)
        }
    }

    public func didFinishJob(_ jobRecordId: JobRecord.RowId, result: JobResult<Void>) async {
        // Fully silent — success/rollback happen inline in runJobAttempt; no toast/badge/system message.
    }

    // MARK: - Pointer resolution

    private func resolvePointer(_ jobRecord: DTGifFavoriteJobRecord) async throws -> FavoriteAttachmentPointer {
        if let pointer = jobRecord.pointer, pointer.authorizeId > 0 {
            return pointer   // already on the server (bump / message re-favorite)
        }
        if let webp = jobRecord.localWebpPath, jobRecord.messageAttachmentId == nil {
            return try await DTGifFavoriteTranscoder.makePointer(uploadingWebpAt: webp)
        }
        if let attachmentId = jobRecord.messageAttachmentId {
            var stream: TSAttachmentStream?
            db.read { tx in
                stream = TSAttachmentStream.anyFetchAttachmentStream(uniqueId: attachmentId, transaction: tx.asSDSRead)
            }
            guard let stream else {
                throw OWSGenericError("[GifFav] message attachment gone: \(attachmentId)")
            }
            return try await DTGifFavoriteTranscoder.makePointer(from: stream)
        }
        throw OWSGenericError("[GifFav] job has no pointer source")
    }

    // MARK: - Error handling

    private func handleFailure(
        _ error: Error,
        jobRecord: DTGifFavoriteJobRecord,
        effectiveFileHash: String
    ) -> JobAttemptResult<Void> {
        if error.isRetryable, jobRecord.failureCount < Self.retryLimit {
            db.write { tx in jobRecord.addFailure(tx: tx) }
            let delay = OWSOperation.retryIntervalForExponentialBackoff(failureCount: jobRecord.failureCount)
            return .retryAfter(delay, canRetryEarly: true)
        }
        rollback(jobRecord: jobRecord, effectiveFileHash: effectiveFileHash)
        return .finished(.success(()))
    }

    // MARK: - Rollback

    private func rollback(jobRecord: DTGifFavoriteJobRecord, effectiveFileHash: String) {
        // The pending op may be keyed by the original or the resolved fileHash — clear both.
        let hashes: Set<String> = [jobRecord.fileHash, effectiveFileHash]
        db.write { tx in
            let sdsTx = tx.asSDSWrite
            self.localStore.clearPending(fileHashes: hashes, sdsTx)
            if jobRecord.op == .favorite {
                for hash in hashes {
                    self.localStore.unlinkGiphy(fileHash: hash, sdsTx)
                }
            } else if jobRecord.op == .unfavorite, let giphyId = jobRecord.giphyId {
                // The item stays favorited (confirmed was never touched) — restore the GIPHY link
                // the optimistic unfavorite removed, so the search grid doesn't show it unfavorited.
                self.localStore.linkGiphy(giphyId, fileHash: jobRecord.fileHash, sdsTx)
            }
            jobRecord.anyRemove(transaction: tx)
        }
        if jobRecord.op == .favorite {
            for hash in hashes {
                DTGifFavoriteAssetLoader.shared.removeCachedAsset(fileHash: hash)
            }
            DTGifFavoriteAssetLoader.shared.removePendingUpload(fileHash: jobRecord.fileHash)
        }
        // Silent: the only user feedback is the optimistic toast at enqueue time. A permanent
        // failure just quietly reverts the item (matching the emoji reaction job's silent rollback).
        DTGifFavoritesRepository.shared.postFavoritesDidChange()
    }
}

// MARK: - Factory

public final class DTGifFavoriteJobRunnerFactory: JobRunnerFactory, @unchecked Sendable {
    public typealias JobRunnerType = DTGifFavoriteJobRunner

    private let db: any DB

    public init(db: any DB) {
        self.db = db
    }

    public func buildRunner() -> DTGifFavoriteJobRunner {
        DTGifFavoriteJobRunner(db: db)
    }
}
