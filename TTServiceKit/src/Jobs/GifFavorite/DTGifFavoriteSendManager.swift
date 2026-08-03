//
// Copyright 2024 Difft. All rights reserved.
//
// Single entry-point for favoriting / unfavoriting a GIF with an optimistic,
// retryable, offline-capable pipeline (modeled on ``ReactionSendManager``).
//
//  Flow:
//   1. Optimistically write the localStore pending op (instant / offline display) and
//      preseed the display cache, in the same DB transaction as the persisted job.
//   2. Broadcast the change (favorites tab refreshes immediately) — the caller can toast now.
//   3. The ``DTGifFavoriteJobRunner`` uploads (panel) / re-resolves (message) and commits,
//      retrying with exponential backoff on reachability changes and app relaunch.
//
//  On permanent failure / retry exhaustion the runner rolls the optimistic op back.
//

import Foundation
import GRDB
import SignalCoreKit

@objc
public final class DTGifFavoriteSendManager: NSObject {

    // MARK: - Singleton

    @objc public static let shared = DTGifFavoriteSendManager()

    // MARK: - Properties

    private var db: (any DB)!
    private var jobQueueRunner: JobQueueRunner<
        JobRecordFinderImpl<DTGifFavoriteJobRecord>,
        DTGifFavoriteJobRunnerFactory
    >!
    private var isStarted = false
    private let localStore = DTGifFavoriteLocalStore()

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
        let finder = JobRecordFinderImpl<DTGifFavoriteJobRecord>(db: db)
        let factory = DTGifFavoriteJobRunnerFactory(db: db)
        self.jobQueueRunner = JobQueueRunner(
            canExecuteJobsConcurrently: false,
            db: db,
            jobFinder: finder,
            jobRunnerFactory: factory
        )
        jobQueueRunner.listenForReachabilityChanges(reachabilityManager: reachabilityManager)
        // The runner retries EXISTING jobs on reconnect; reconcile additionally re-creates jobs for
        // any orphaned pending op (upgrade leftovers, or an op whose job was lost).
        NotificationCenter.default.addObserver(
            self, selector: #selector(reachabilityChanged),
            name: SSKReachability.owsReachabilityDidChange, object: nil)
    }

    /// Restore persisted jobs from a previous launch, then reconcile any orphaned pending ops.
    @objc
    public func start() {
        guard !isStarted else { return }
        isStarted = true
        jobQueueRunner.start(shouldRestartExistingJobs: true)
        reconcile()
    }

    @objc
    private func reachabilityChanged() {
        reconcile()
    }

    // MARK: - Public API

    /// Panel add (pre-upload): seed the display cache from the local WebP, enqueue an optimistic
    /// pending op keyed by a temp key, and schedule the upload+commit job. Callers should toast now.
    public func enqueuePanelFavorite(localWebpPath: String, giphyId: String, width: Int, height: Int) {
        let tempKey = "pending:" + giphyId
        // Upload source must survive a Caches purge (else a slow/offline job's source vanishes and it
        // retries forever) → stage it in the durable dir. Also seed the Caches display cache so the
        // favorites grid renders it instantly.
        let uploadPath = DTGifFavoriteAssetLoader.shared.stagePendingUpload(fileHash: tempKey, sourcePath: localWebpPath) ?? localWebpPath
        DTGifFavoriteAssetLoader.shared.seedLocalAsset(fileHash: tempKey, sourcePath: localWebpPath)
        let byteCount = Self.fileByteCount(uploadPath)
        let placeholder = FavoriteAttachmentPointer(
            id: "", authorizeId: 0, key: "", digest: "",
            fileHash: tempKey, contentType: OWSMimeTypeImageWebp,
            width: width, height: height, size: Int(byteCount)
        )
        let record = DTGifFavoriteJobRecord(
            op: .favorite, fileHash: tempKey, pointer: nil,
            localWebpPath: uploadPath, messageAttachmentId: nil, giphyId: giphyId
        )
        enqueue(record) { tx in
            self.localStore.enqueueAdd(placeholder, localWebpPath: uploadPath, now: Self.nowMs(), tx)
            self.localStore.linkGiphy(giphyId, fileHash: tempKey, tx)
        }
    }

    /// Message add: the attachment bytes are already on the server. Compute its real fileHash locally
    /// (no network), seed the display cache from the on-disk attachment, and defer the pointer
    /// resolution (checkFileExists) to the job.
    public func enqueueMessageFavorite(stream: TSAttachmentStream) {
        guard let fileHash = DTGifFavoriteTranscoder.fileHash(for: stream) else {
            Logger.error("[GifFav] message favorite skipped — missing encryption key")
            return
        }
        let localPath = stream.filePath()
        if let localPath {
            DTGifFavoriteAssetLoader.shared.seedLocalAsset(fileHash: fileHash, sourcePath: localPath)
        }
        let imageSize = stream.imageSize()
        let placeholder = FavoriteAttachmentPointer(
            id: "", authorizeId: 0,
            key: stream.encryptionKey.base64EncodedString(),
            digest: stream.digest?.base64EncodedString() ?? "",
            fileHash: fileHash, contentType: OWSMimeTypeImageWebp,
            width: Int(imageSize.width), height: Int(imageSize.height), size: Int(stream.byteCount)
        )
        let record = DTGifFavoriteJobRecord(
            op: .favorite, fileHash: fileHash, pointer: nil,
            localWebpPath: localPath, messageAttachmentId: stream.uniqueId, giphyId: nil
        )
        enqueue(record) { tx in
            self.localStore.enqueueAdd(placeholder, localWebpPath: localPath, now: Self.nowMs(), tx)
        }
    }

    /// Re-favorite an already-saved item (bump-to-top): the pointer is known and on the server, so
    /// no upload is needed — just re-enqueue with a fresh sort key and commit.
    public func enqueueResolvedFavorite(pointer: FavoriteAttachmentPointer, giphyId: String?) {
        // A still-uploading placeholder (authorizeId 0) has no server pointer to commit — its in-flight
        // job will land it. Don't spawn a duplicate (doomed) job, but still bump it to the top locally
        // so a re-favorite of a not-yet-committed item moves it up.
        guard pointer.authorizeId > 0 else {
            db.write { tx in self.localStore.bumpPending(fileHash: pointer.fileHash, now: Self.nowMs(), tx.asSDSWrite) }
            DTGifFavoritesRepository.shared.postFavoritesDidChange()
            return
        }
        let record = DTGifFavoriteJobRecord(
            op: .favorite, fileHash: pointer.fileHash, pointer: pointer,
            localWebpPath: nil, messageAttachmentId: nil, giphyId: giphyId
        )
        enqueue(record) { tx in
            self.localStore.enqueueAdd(pointer, now: Self.nowMs(), tx)
            if let giphyId { self.localStore.linkGiphy(giphyId, fileHash: pointer.fileHash, tx) }
        }
    }

    /// Bump a favorited GIPHY asset to the top without re-uploading (looks up its stored pointer).
    public func enqueueBump(giphyId: String) {
        let pointer = databaseStorage.read { tx -> FavoriteAttachmentPointer? in
            guard let fileHash = self.localStore.fileHash(forGiphy: giphyId, tx) else { return nil }
            return self.localStore.pointer(forFileHash: fileHash, tx)
        }
        guard let pointer else { return }
        enqueueResolvedFavorite(pointer: pointer, giphyId: giphyId)
    }

    /// Unfavorite an item by content fileHash.
    public func enqueueUnfavorite(fileHash: String) {
        // Capture the GIPHY link before unlinking so a permanent-failure rollback can restore it.
        let giphyId = databaseStorage.read { tx in self.localStore.giphyId(forFileHash: fileHash, tx) }
        let record = DTGifFavoriteJobRecord(op: .unfavorite, fileHash: fileHash, giphyId: giphyId)
        enqueue(record) { tx in
            self.localStore.enqueueRemove(fileHash: fileHash, now: Self.nowMs(), tx)
            self.localStore.unlinkGiphy(fileHash: fileHash, tx)
        }
    }

    // MARK: - Enqueue plumbing

    /// One pending op ↔ one job: apply the optimistic localStore write and insert the job in the same
    /// transaction, then broadcast + schedule. No dedup needed — in the single-op model a duplicate
    /// job is harmless (it commits idempotently, or finds its op already gone and self-removes), so we
    /// never risk deleting a still-running job's row (JobRecord.status never flips to .running).
    private func enqueue(_ record: DTGifFavoriteJobRecord, optimistic: @escaping (SDSAnyWriteTransaction) -> Void) {
        DatabaseOfflineManager.shared.canOfflineUpdateDatabase = true
        db.write { tx in
            optimistic(tx.asSDSWrite)
            record.anyInsert(transaction: tx)
        }
        Logger.info("[GifFav] enqueued op=\(record.op.rawValue) fileHash=\(record.fileHash.prefix(8))")
        DTGifFavoritesRepository.shared.postFavoritesDidChange()
        jobQueueRunner.addPersistedJob(record)
    }

    // MARK: - Reconcile (the explicit replacement for the old flush-all safety net)

    /// Ensure every pending op has a live job. Re-enqueues jobs for orphans — pending written by an
    /// older app version (no job), or an op whose job was somehow lost — and drops unrecoverable
    /// placeholder ghosts. Called on launch and on network reconnect.
    public func reconcile() {
        var toSchedule: [DTGifFavoriteJobRecord] = []
        db.write { tx in
            let pending = self.localStore.pendingOps(tx.asSDSRead)
            let jobbedKeys = self.existingJobKeys(tx: tx)
            guard !pending.isEmpty else { return }
            for op in pending where !jobbedKeys.contains(op.fileHash) {
                let giphyId = self.localStore.giphyId(forFileHash: op.fileHash, tx.asSDSRead)
                let record: DTGifFavoriteJobRecord
                switch op.action {
                case .favorite:
                    if let pointer = op.pointer, pointer.authorizeId > 0 {
                        record = DTGifFavoriteJobRecord(op: .favorite, fileHash: op.fileHash, pointer: pointer, giphyId: giphyId)
                    } else if let webp = op.localWebpPath {
                        record = DTGifFavoriteJobRecord(op: .favorite, fileHash: op.fileHash, localWebpPath: webp, giphyId: giphyId)
                    } else {
                        // No server pointer and no local file → unrecoverable; drop the ghost.
                        self.localStore.clearPending(fileHashes: [op.fileHash], tx.asSDSWrite)
                        continue
                    }
                case .unfavorite:
                    record = DTGifFavoriteJobRecord(op: .unfavorite, fileHash: op.fileHash, giphyId: giphyId)
                case .rewrap, .reset:
                    continue
                }
                record.anyInsert(transaction: tx)
                toSchedule.append(record)
            }
        }
        for record in toSchedule {
            Logger.info("[GifFav] reconcile re-enqueued op=\(record.op.rawValue) fileHash=\(record.fileHash.prefix(8))")
            jobQueueRunner.addPersistedJob(record)
        }
    }

    /// The pending keys (threadId) of all persisted gif-favorite jobs.
    private func existingJobKeys(tx: DBWriteTransaction) -> Set<String> {
        let sql = """
            SELECT "\(DTGifFavoriteJobRecord.columnName(.threadId))" FROM \(DTGifFavoriteJobRecord.databaseTableName)
            WHERE "\(DTGifFavoriteJobRecord.columnName(.label))" = ?
        """
        let arguments: StatementArguments = [DTGifFavoriteJobRecord.jobRecordType.jobRecordLabel]
        guard let keys = try? String.fetchAll(tx.database, sql: sql, arguments: arguments) else { return [] }
        return Set(keys)
    }

    // MARK: - Helpers

    private static func nowMs() -> Int64 {
        Int64(NSDate.ows_millisecondTimeStamp())
    }

    private static func fileByteCount(_ path: String) -> UInt64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return (attrs?[.size] as? NSNumber)?.uint64Value ?? 0
    }
}
