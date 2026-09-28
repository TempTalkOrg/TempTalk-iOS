//
//  Copyright (c) 2026 Open Whisper Systems. All rights reserved.
//

import AVFoundation
import Foundation
import Photos
import TTServiceKit
import UniformTypeIdentifiers

/// Prepares the assets backing a media-preview screen into sendable
/// `SignalAttachment`s. The work is per-item processing, not just compression:
/// images are compressed inline, plain videos become deferred
/// `.videoCompression` placeholders (recompressed later by
/// `VideoCompressionOperation`), and composition-only videos (slow-mo / edited)
/// fall back to inline compression. Each `MediaPreviewItem` ends up `.ready`
/// carrying its prepared attachment.
///
/// Runs while the preview screen is already on screen, so nothing blocks
/// presentation and each item surfaces independently — no barrier on the
/// slowest asset.
public class MediaPreviewProcessor {

    private let operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 2
        queue.qualityOfService = .userInitiated
        return queue
    }()

    private var items: [MediaPreviewItem] = []

    /// Keyed off the items' published state, not `Operation.isFinished`. The operation
    /// finishes on its own background queue while the item publishes `state` and
    /// `signalAttachment` via a main-queue hop, so `isFinished` can lead the data it
    /// gates by one hop — a send tap landing in that window would read a ready item as
    /// failed. This getter and those writes are both main-queue, so they can't disagree,
    /// and the operations stay free to finish without waiting on main.
    public var isAllCompleted: Bool {
        items.allSatisfy { item in
            switch item.state {
            case .ready, .failed:
                return true
            case .pending, .compressing:
                return false
            }
        }
    }

    public init() {}

    public func process(items: [MediaPreviewItem]) {
        self.items = items
        for item in items {
            operationQueue.addOperation(MediaPreviewItemOperation(item: item))
        }
    }

    public func cancelAll() {
        operationQueue.cancelAllOperations()
    }
}

// MARK: - MediaPreviewItemOperation

private class MediaPreviewItemOperation: OWSOperation, @unchecked Sendable {

    let item: MediaPreviewItem

    init(item: MediaPreviewItem) {
        self.item = item
        super.init()
    }

    override func run() {
        guard !isCancelled else {
            reportCancelled()
            return
        }

        item.updateState(.compressing)

        Task { [weak self] in
            guard let self else { return }

            // Failure propagates through the return value rather than by reading
            // `item.state`: `updateState` dispatches to the main queue, so a read
            // here right after the await would race with that write and often see
            // the old value — firing `reportSuccess` for a failed item, whose nil
            // attachment then gets silently dropped by the caller's compactMap.
            let failure: Error?
            if self.item.asset.mediaType == .video {
                failure = await self.compressVideo()
            } else {
                failure = await self.compressImage()
            }

            // Reported inline, never hopped to the main queue: `OWSOperation` only
            // counts as finished once these run, so deferring them would gate the
            // queue's next slot on main-thread scheduling and collapse the concurrency.
            if self.isCancelled {
                self.reportCancelled()
            } else if let error = failure {
                self.reportError(error)
            } else {
                self.reportSuccess()
            }
        }
    }

    override func didCancel() {
        item.updateState(.failed(compressionError("Cancelled")))
    }

    // MARK: - Video

    /// Returns nil on success / cancellation, an error on failure. The error is
    /// also published to `item.state` for the cell to render.
    private func compressVideo() async -> Error? {
        let avAsset: AVAsset
        do {
            avAsset = try await requestAVAsset()
        } catch {
            Logger.error("Request AVAsset failed: \(error).")
            item.updateState(.failed(error))
            return error
        }
        guard !isCancelled else { return nil }

        let fileName = item.asset.value(forKey: "filename") as? String

        // Nothing is compressed here. We hand the send path a placeholder
        // pointing at the original `AVURLAsset` URL, carrying the quality preset
        // in `preprocessingParams`; `OWSMessageSender` dispatches a
        // `VideoCompressionOperation` after enqueue, which recompresses while
        // the placeholder bubble is already visible.
        //
        // The deferral needs a real file on disk to point at. PhotoKit returns
        // slow-motion and edited videos as `AVComposition` — a recipe of
        // segments, not a file — so those fall through to inline compression.
        guard let urlAsset = avAsset as? AVURLAsset else {
            return await legacyCompressVideo(avAsset: avAsset, fileName: fileName)
        }

        let url = urlAsset.url
        let dataUTI = MIMETypeUtil.utiType(forFileExtension: url.pathExtension) ?? UTType.video.identifier
        let qualityPreset: VideoQualityPreset = item.isFullImage ? .original : .auto

        // Oversized sources that the compressor would pass through are doomed to hit
        // the same ceiling downstream, by which point the bubble is on screen and the
        // send visibly bounces. Fail here while the user can still lower quality or
        // pick another clip. `.auto` isn't gated — it always re-encodes to 720p, so
        // even a 1 GB 4K source comes out at tens of MB.
        let sourceBytes = (try? FileManager.default
            .attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.uint64Value ?? 0
        if sourceBytes > UInt64(OWSMediaUtils.kMaxFileSizeVideo) {
            // Track loads only after the cheap size check already failed.
            let predicted = try? await VideoCompressor.configured(
                asset: urlAsset,
                qualityPreset: qualityPreset
            )
            if predicted?.isPassthrough == true {
                Logger.error("Video exceeds size limit at this quality: \(sourceBytes) bytes.")
                let error = compressionError("Video exceeds the size limit at this quality.")
                item.updateState(.failed(error))
                return error
            }
        }

        let dataSource: DataSource
        do {
            dataSource = try DataSourcePath.dataSource(with: url, shouldDeleteOnDeallocation: false)
        } catch {
            Logger.error("Create dataSource failed: \(error).")
            item.updateState(.failed(error))
            return error
        }
        dataSource.sourceFilename = fileName

        // The placeholder factory skips the source-bytes cap so a 4K / HEVC original
        // that would shrink fine isn't rejected before compression runs; the ceiling
        // is re-checked against the compressed output instead.
        let attachment = SignalAttachment.videoPlaceholderAttachment(dataSource: dataSource, dataUTI: dataUTI)
        if attachment.hasError {
            Logger.error("Invalid attachment: \(attachment.errorName ?? "Unknown error").")
            let error = compressionError(attachment.errorName)
            item.updateState(.failed(error))
            return error
        }

        // The preset rides along on the placeholder: the "original size" toggle lives
        // here, and there's nowhere else to recover that intent once the row is
        // waiting in the preparation queue.
        do {
            let params = VideoCompressionPreprocessingParams(qualityPreset: qualityPreset)
            attachment.preprocessingParams = try params.encoded()
            attachment.preprocessingKind = .videoCompression
        } catch {
            Logger.error("Encode preprocessing params failed: \(error).")
            item.updateState(.failed(error))
            return error
        }

        item.updateState(.ready, attachment: attachment)
        return nil
    }

    /// Inline compression fallback for videos with no single backing file, so the
    /// deferred placeholder flow can't be used.
    ///
    /// PhotoKit hands back an `AVComposition` for slow-motion videos (a
    /// high-frame-rate source plus time mappings) and edited ones (original plus
    /// adjustments). Both are recipes, not files, so there's no stable URL for a
    /// placeholder to reference later. Turning one into a file requires an export
    /// pass — exactly the expensive step deferral exists to postpone — so this
    /// path keeps the original behavior: export and compress now, producing a
    /// normal already-compressed attachment that uploads directly. It blocks the
    /// preview cell while exporting, but compositions are uncommon and the export
    /// is unavoidable whenever it runs.
    private func legacyCompressVideo(avAsset: AVAsset, fileName: String?) async -> Error? {
        do {
            let presentName = item.isFullImage
                ? AVAssetExportPresetHighestQuality
                : AVAssetExportPreset640x480
            let attachment = try await SignalAttachment.compressVideoAsMp4(
                asset: avAsset,
                baseFilename: fileName,
                dataUTI: UTType.video.identifier,
                presentName: presentName
            )
            if attachment.hasError {
                Logger.error("Invalid attachment: \(attachment.errorName ?? "Unknown error").")
                let error = compressionError(attachment.errorName)
                item.updateState(.failed(error))
                return error
            }
            item.updateState(.ready, attachment: attachment)
            return nil
        } catch {
            Logger.error("Compress video failed: \(error).")
            item.updateState(.failed(error))
            return error
        }
    }

    // MARK: - Image

    private func compressImage() async -> Error? {
        var imageQuality: TSImageQuality = .original
        if !item.asset.mediaSubtypes.contains(.photoScreenshot) && !item.isFullImage {
            imageQuality = .compact
        }

        let imageData: Data
        let dataUTI: String

        do {
            (imageData, dataUTI) = try await requestImageData()
        } catch {
            Logger.error("Request image data failed: \(error).")
            item.updateState(.failed(error))
            return error
        }

        guard let dataSource = DataSourceValue.dataSource(with: imageData, utiType: dataUTI) else {
            Logger.error("Create dataSource for image failed.")
            let error = compressionError("Failed to create data source")
            item.updateState(.failed(error))
            return error
        }
        dataSource.sourceFilename = item.asset.value(forKey: "filename") as? String

        let attachment = SignalAttachment.attachment(
            dataSource: dataSource,
            dataUTI: dataUTI,
            imageQuality: imageQuality
        )
        if attachment.hasError {
            Logger.error("Invalid attachment: \(attachment.errorName ?? "Unknown error").")
            let error = compressionError(attachment.errorName)
            item.updateState(.failed(error))
            return error
        }
        item.updateState(.ready, attachment: attachment)
        return nil
    }

    // MARK: - PHImageManager Async Bridges

    private func requestAVAsset() async throws -> AVAsset {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.version = .current
            // Always pull the original. `.automatic` lets PhotoKit hand back a
            // pre-transcoded (downscaled) version that `VideoCompressor` would
            // then compress a second time, stacking two lossy passes. The
            // `isFullImage` choice must only drive our own compressor preset,
            // never the fidelity of the source fed into it.
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestAVAsset(
                forVideo: item.asset,
                options: options
            ) { avAsset, _, info in
                if let avAsset {
                    continuation.resume(returning: avAsset)
                } else {
                    let error = info?[PHImageErrorKey] as? NSError
                        ?? self.compressionError("Failed to load video")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func requestImageData() async throws -> (Data, String) {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.version = .current
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .none

            PHImageManager.default().requestImageDataAndOrientation(
                for: item.asset,
                options: options
            ) { imageData, dataUTI, _, info in
                if let imageData, let dataUTI {
                    continuation.resume(returning: (imageData, dataUTI))
                } else {
                    let error = info?[PHImageErrorKey] as? NSError
                        ?? self.compressionError("Failed to load image")
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Helpers

    private func compressionError(_ message: String?) -> NSError {
        NSError(
            domain: "MediaPreview",
            code: -2,
            userInfo: [NSLocalizedDescriptionKey: message ?? "Unknown error"]
        )
    }
}
