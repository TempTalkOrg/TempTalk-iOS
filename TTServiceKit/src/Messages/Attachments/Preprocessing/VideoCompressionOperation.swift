//
//  Copyright (c) 2026 Open Whisper Systems. All rights reserved.
//

import AVFoundation
import Foundation

/// Failure modes the video compression op needs to distinguish from generic
/// transport errors so the dependent upload/send ops don't run with a stale
/// or half-swapped attachment row.
enum VideoCompressionOperationError: Error {
    /// Placeholder attachment was removed (typically because the user deleted
    /// the message mid-compression). Treat as a non-retryable failure so the
    /// dependent upload op short-circuits instead of trying to fetch a row
    /// that no longer exists.
    case attachmentMissing
    /// `MIMETypeUtil.filePathForAttachment(...)` couldn't synthesize an output
    /// path for the recompressed payload.
    case outputPathUnavailable
    /// The compressed temp file failed to move into the attachment folder.
    /// Wrapped underlying `FileManager` error.
    case moveFailed(Error)
}

/// Compresses a placeholder attachment's video payload and swaps the stream's path
/// in place (uniqueId unchanged, so the cell's thumbnail cache stays warm). When the
/// source already meets the preset, only the placeholder fields are cleared.
///
/// This op must mutate only the attachment row. `OWSSendMessageOperation` holds the
/// same in-memory `TSOutgoingMessage` instance from enqueue through send, and
/// `OWSUploadOperation` writes `message.rapidFiles` onto it without persisting —
/// so re-reading the message row here, or touching message fields, would drop that.
/// `touchOwningMessage` only marks the row dirty for the change observer.
@objc public final class VideoCompressionOperation: OWSOperation, @unchecked Sendable {

    @objc public let messageUniqueId: String
    @objc public let attachmentUniqueId: String

    private var task: Task<Void, Never>?
    private let compressorLock = UnfairLock()
    private var _compressor: VideoCompressor?
    private var compressor: VideoCompressor? {
        get { compressorLock.withLock { _compressor } }
        set { compressorLock.withLock { _compressor = newValue } }
    }

    @objc public init(messageUniqueId: String, attachmentUniqueId: String) {
        self.messageUniqueId = messageUniqueId
        self.attachmentUniqueId = attachmentUniqueId
        super.init()
    }

    public override func run() {
        // `OWSOperation.main` guards this once, but the window between that check and
        // the Task creation below is still open.
        guard !isCancelled else {
            reportCancelled()
            return
        }
        // `_ =` discards the optional chain's `Void?`; without it the compiler infers
        // `Task<()?, Never>` and the assignment to `task` won't type-check.
        let newTask = Task { [weak self] in
            _ = await self?.performCompression()
        }
        task = newTask
        // A `cancel()` landing between the guard and this assignment saw `task == nil`
        // and was a no-op, leaving the stored Task running unflagged. Propagate by
        // hand so it still reaches `Task.checkCancellation()` in performCompression.
        if isCancelled {
            newTask.cancel()
        }
    }

    public override func cancel() {
        super.cancel()
        task?.cancel()
        compressor?.cancel()
    }

    // MARK: - Implementation

    private func performCompression() async {
        do {
            try Task.checkCancellation()

            let inputs = try fetchInputs()

            try Task.checkCancellation()

            let sourceAsset = AVURLAsset(url: inputs.sourceURL)
            let cmp = try await VideoCompressor.configured(
                asset: sourceAsset,
                qualityPreset: inputs.qualityPreset
            )
            self.compressor = cmp

            try Task.checkCancellation()

            // `isPassthrough` means the bitstream meets the preset, not that no file
            // work is needed: `passthrough()` still remuxes non-mp4 containers (e.g.
            // .MOV from the camera) into `.mp4`. Treating those as a no-op would ship
            // .MOV bytes as `video/mp4`, and receivers that pick their handling by
            // extension would take the wrong path.
            let sourceIsAlreadyMp4 = inputs.sourceURL.pathExtension.lowercased() == "mp4"
            if cmp.isPassthrough && sourceIsAlreadyMp4 {
                // The file on disk is the final payload. Still size-checked, or an
                // oversized H.264 ≤ 1080p mp4 would bypass every ceiling.
                let sourceBytes = (try? FileManager.default
                    .attributesOfItem(atPath: inputs.sourceURL.path)[.size] as? NSNumber)?.uint64Value ?? 0
                guard sourceBytes <= 200 * 1024 * 1024 else {
                    throw VideoCompressionError.fileSizeTooLarge
                }
                try await clearPreprocessingFields()
            } else {
                // Container remux or full re-encode; either way `compress()` returns a
                // new file under `<Tmp>/VideoCompressor/` to move into the attachment
                // folder.
                let outputURL = try await cmp.compress()
                // `swapPayload` owns the file once called and cleans up its own
                // failures. Before that there are two cancellation points plus the
                // metadata reads, and a throw there would strand the temp file.
                //
                // The identity check is not dead weight: `passthrough()` returns the
                // *input* URL untouched when the asset is already an mp4. The branch
                // above means we can't reach that today, but the "is it already mp4"
                // test is written out separately here and in `VideoCompressor`, and
                // only one of them has to drift for this defer to delete the user's
                // attachment off disk.
                var swapStarted = false
                defer {
                    if !swapStarted, outputURL != inputs.sourceURL {
                        try? FileManager.default.removeItem(at: outputURL)
                    }
                }
                try Task.checkCancellation()

                let outputAsset = AVURLAsset(url: outputURL)
                let outputBytes = (try? FileManager.default
                    .attributesOfItem(atPath: outputURL.path)[.size] as? NSNumber)?.uint64Value ?? 0
                // Covers the remux path, which `passthrough()` doesn't validate. The
                // re-encode path already throws internally; the duplicate guard is
                // cheap and keeps enforcement uniform.
                guard outputBytes <= 200 * 1024 * 1024 else {
                    throw VideoCompressionError.fileSizeTooLarge
                }
                let outputSize = VideoDisplaySizeResolver.displaySize(of: outputAsset)

                try Task.checkCancellation()

                swapStarted = true
                try await swapPayload(
                    tempOutputURL: outputURL,
                    outputBytes: UInt32(min(outputBytes, UInt64(UInt32.max))),
                    outputSize: outputSize
                )
            }

            self.reportSuccess()
        } catch is CancellationError {
            self.reportCancelled()
        } catch {
            self.reportError(error)
        }
    }

    // MARK: - DB read

    private struct CompressionInputs {
        let sourceURL: URL
        let qualityPreset: VideoQualityPreset
    }

    private func fetchInputs() throws -> CompressionInputs {
        var fetched: CompressionInputs?
        var fetchError: Error?
        databaseStorage.read { tx in
            guard let stream = TSAttachmentStream.anyFetchAttachmentStream(
                uniqueId: self.attachmentUniqueId,
                transaction: tx
            ) else {
                fetchError = OWSAssertionError("Video placeholder attachment missing")
                return
            }
            guard let url = stream.mediaURL() else {
                fetchError = OWSAssertionError("Video placeholder attachment has no media URL")
                return
            }
            guard let paramsData = stream.preprocessingParams else {
                fetchError = OWSAssertionError("Video placeholder attachment missing preprocessingParams")
                return
            }
            do {
                let params = try VideoCompressionPreprocessingParams.decode(paramsData)
                fetched = CompressionInputs(sourceURL: url, qualityPreset: params.qualityPreset)
            } catch {
                fetchError = error
            }
        }
        if let fetched { return fetched }
        throw fetchError ?? OWSAssertionError("Unknown error fetching video placeholder inputs")
    }

    // MARK: - DB writes

    /// Passthrough branch: the file on disk is already the final payload, so just
    /// clear the placeholder fields. Throws so the caller can't report success on a
    /// row update that didn't happen (e.g. message deleted mid-compression).
    private func clearPreprocessingFields() async throws {
        ensureThumbnailOffTransaction()

        let result: Result<Void, Error> = await databaseStorage.awaitableWrite { dbTx in
            // Bridge to the legacy SDS transaction — the TSAttachment* APIs
            // haven't been migrated to the DBTransaction abstraction yet.
            let tx = dbTx.asSDSWrite
            guard let stream = TSAttachmentStream.anyFetchAttachmentStream(
                uniqueId: self.attachmentUniqueId,
                transaction: tx
            ) else {
                return .failure(VideoCompressionOperationError.attachmentMissing)
            }
            stream.anyUpdateAttachmentStream(transaction: tx) { instance in
                instance.preprocessingKind = .none
                instance.preprocessingParams = nil
            }
            self.touchOwningMessage(transaction: tx)
            return .success(())
        }
        try result.get()
    }

    /// Recompress branch: move the temp output into the attachment folder, repoint
    /// the stream, and reset the upload-state fields that would otherwise let
    /// `OWSUploadOperation` short-circuit on stale digest/server data.
    ///
    /// Throws rather than failing quietly: if the row still points at the
    /// placeholder payload, the dependent upload op would ship the uncompressed
    /// bytes or fetch a vanished attachment.
    private func swapPayload(
        tempOutputURL: URL,
        outputBytes: UInt32,
        outputSize: CGSize
    ) async throws {
        // Before the write, so the rename below always has something to move: the
        // sender generates this asynchronously, and a fast passthrough or remux can
        // reach here first.
        ensureThumbnailOffTransaction()

        let result: Result<Void, Error> = await databaseStorage.awaitableWrite { dbTx in
            // Bridge to the legacy SDS transaction — see clearPreprocessingFields.
            let tx = dbTx.asSDSWrite
            guard let stream = TSAttachmentStream.anyFetchAttachmentStream(
                uniqueId: self.attachmentUniqueId,
                transaction: tx
            ) else {
                // Attachment was deleted while we were compressing (user
                // removed the message). Drop the temp output and bubble up
                // as a terminal error so the dependent upload/send ops
                // short-circuit instead of running against a vanished row.
                try? FileManager.default.removeItem(at: tempOutputURL)
                return .failure(VideoCompressionOperationError.attachmentMissing)
            }

            let attachmentsFolder = TSAttachmentStream.attachmentsFolder()
            let outputContentType = "video/mp4"
            guard let newAbsolutePath = MIMETypeUtil.filePath(
                forAttachment: stream.uniqueId,
                ofMIMEType: outputContentType,
                sourceFilename: "output.mp4",
                inFolder: attachmentsFolder
            ) else {
                try? FileManager.default.removeItem(at: tempOutputURL)
                return .failure(VideoCompressionOperationError.outputPathUnavailable)
            }

            // Defensive: `filePathForAttachment` is wired to put files under
            // `attachmentsFolder`, but if a future refactor ever lets it
            // return a path outside that root we'd lose the ability to
            // derive a relative path and the row would point at an
            // unreachable file. Validate *before* the move so a tripped
            // guard doesn't strand the compressed output at the bogus
            // destination — clean up `tempOutputURL` and bail.
            guard newAbsolutePath.hasPrefix(attachmentsFolder) else {
                try? FileManager.default.removeItem(at: tempOutputURL)
                return .failure(VideoCompressionOperationError.outputPathUnavailable)
            }
            let newRelativePath = String(newAbsolutePath.dropFirst(attachmentsFolder.count))

            let containingDir = (newAbsolutePath as NSString).deletingLastPathComponent
            _ = OWSFileSystem.ensureDirectoryExists(containingDir)

            // Captured pre-swap so cleanup doesn't re-read the mutated stream.
            let oldFilePath = stream.filePath()
            let oldThumbnailPath = stream.thumbnailPath()
            let newThumbnailPath = (
                (newAbsolutePath as NSString).deletingPathExtension as String
            ) + "-signal-ios-thumbnail.jpg"

            // If something is already at the destination (retry after partial
            // failure), remove it before the move.
            try? FileManager.default.removeItem(atPath: newAbsolutePath)

            do {
                try FileManager.default.moveItem(atPath: tempOutputURL.path, toPath: newAbsolutePath)
            } catch {
                try? FileManager.default.removeItem(at: tempOutputURL)
                return .failure(VideoCompressionOperationError.moveFailed(error))
            }

            // Renamed before the row update, not after: the update fires
            // anyDidUpdateWithTransaction → ensureThumbnail, which would find nothing
            // at the new path and decode a frame under the write lock — the stall this
            // path avoids elsewhere, and wasted since the rename overwrites it anyway.
            if let oldThumbnailPath, FileManager.default.fileExists(atPath: oldThumbnailPath) {
                try? FileManager.default.removeItem(atPath: newThumbnailPath)
                try? FileManager.default.moveItem(atPath: oldThumbnailPath, toPath: newThumbnailPath)
            }

            stream.anyUpdateAttachmentStream(transaction: tx) { instance in
                instance.applyCompressedVideoPayload(
                    relativePath: newRelativePath,
                    byteCount: outputBytes,
                    contentType: outputContentType,
                    width: UInt32(max(outputSize.width, 0)),
                    height: UInt32(max(outputSize.height, 0))
                )
                // Reset just enough upload state to defeat OWSUploadOperation's
                // `isUploaded && serverId > 0` early-return. The other upload
                // fields (encryptionKey/digest/encryptedDatalength) are nil/0
                // on a fresh placeholder anyway, and the upload op
                // re-derives them, so we don't bother nulling them here.
                instance.isUploaded = false
                instance.serverId = 0
                instance.serverAttachmentId = ""
                instance.digest = nil
                instance.preprocessingKind = .none
                instance.preprocessingParams = nil
            }

            self.touchOwningMessage(transaction: tx)

            // Deferred to post-commit so a rollback can't orphan the file.
            tx.addAsyncCompletion(queue: .global(qos: .utility)) {
                let fm = FileManager.default
                // The placeholder thumbnail is generated off-transaction, so it can
                // land on the old path after the rename above. Drop the leftover.
                if let oldThumbnailPath, fm.fileExists(atPath: oldThumbnailPath) {
                    try? fm.removeItem(atPath: oldThumbnailPath)
                }
                if let oldFilePath, oldFilePath != newAbsolutePath, fm.fileExists(atPath: oldFilePath) {
                    try? fm.removeItem(atPath: oldFilePath)
                }
            }

            return .success(())
        }
        try result.get()
    }

    // MARK: - Helpers

    /// Writes the thumbnail outside any transaction. Both row updates here fire
    /// `-[TSAttachmentStream anyDidUpdateWithTransaction:]` → `ensureThumbnail`, and
    /// letting that run inside the write transaction decodes a video frame while
    /// holding the DB lock — the stall this whole path exists to avoid. Idempotent,
    /// so racing the sender's async generation is harmless.
    private func ensureThumbnailOffTransaction() {
        var stream: TSAttachmentStream?
        databaseStorage.read { tx in
            stream = TSAttachmentStream.anyFetchAttachmentStream(
                uniqueId: self.attachmentUniqueId,
                transaction: tx
            )
        }
        stream?.ensureThumbnail()
    }

    /// The change observer keys off interactions, not attachments, so mutating the
    /// attachment row alone leaves the cell spinning until some later write dirties
    /// the message (measured ~2.4s, when the upload completed).
    private func touchOwningMessage(transaction: SDSAnyWriteTransaction) {
        guard let message = TSInteraction.anyFetch(
            uniqueId: messageUniqueId,
            transaction: transaction
        ) else {
            return
        }
        databaseStorage.touch(interaction: message, shouldReindex: false, transaction: transaction)
    }

}
