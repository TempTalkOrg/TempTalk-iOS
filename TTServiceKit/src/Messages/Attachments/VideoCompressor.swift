//
//  VideoCompressor.swift
//  SignalMessaging
//
//  Copyright (c) 2024 Difft. All rights reserved.
//

import AVFoundation
import CoreMedia

/// Resolves display dimensions after applying the track transform.
@objc public final class VideoDisplaySizeResolver: NSObject {
    /// Use only when tracks are already loaded.
    @objc(displaySizeOfAsset:)
    public static func displaySize(of asset: AVAsset) -> CGSize {
        guard let track = asset.tracks(withMediaType: .video).first else {
            return .zero
        }
        let transformed = track.naturalSize.applying(track.preferredTransform)
        return CGSize(width: abs(transformed.width), height: abs(transformed.height))
    }

    /// Loads tracks asynchronously before measuring; returns `.zero` on failure.
    @objc(displaySizeOfAsset:completion:)
    public static func displaySize(of asset: AVAsset, completion: @escaping (CGSize) -> Void) {
        let key = "tracks"
        asset.loadValuesAsynchronously(forKeys: [key]) {
            var loadingError: NSError?
            guard asset.statusOfValue(forKey: key, error: &loadingError) == .loaded else {
                Logger.error("Failed to load video tracks for display size: \(String(describing: loadingError))")
                completion(.zero)
                return
            }
            completion(displaySize(of: asset))
        }
    }
}

// MARK: - VideoCompressionCancellable

public protocol VideoCompressionCancellable: AnyObject {
    func cancel()
    var progress: Double { get }
}

// MARK: - VideoCompressionError

public enum VideoCompressionError: Error {
    case noVideoTrack
    case cancelled
    case writeFailed(underlyingError: Error?)
    case exportSessionCreationFailed
    case fileSizeTooLarge
}

// MARK: - VideoQualityPreset

public enum VideoQualityPreset {
    /// 720p + duration-based dynamic bitrate (default for non-original)
    case auto
    /// Passthrough if H.264 <= 1080p, otherwise 1080p re-encode (default for original)
    case original
}

// MARK: - VideoCompressionConfig

public struct VideoCompressionConfig {
    let isPassthrough: Bool
    let maxLongSide: Int
    let videoBitrate: Int       // bps
    let audioBitrate: Int       // bps
    let audioSampleRate: Float64
    let audioChannels: Int

    static func resolve(
        preset: VideoQualityPreset,
        sourceCodec: CMVideoCodecType,
        sourceResolution: CGSize,
        sourceBitrate: Float,
        duration: TimeInterval
    ) -> VideoCompressionConfig {
        let isH264 = sourceCodec == kCMVideoCodecType_H264
        let longSide = max(sourceResolution.width, sourceResolution.height)

        switch preset {
        case .auto:
            let targetBitrate = dynamicBitrate(for: duration, maxLongSide: 1280)
            // Skip the re-encode when the source already fits the target
            // envelope. Without this a 296x640 / 3.4 Mbps clip gets rebuilt at
            // the same resolution (it can't be upscaled past 640) purely to
            // shave the bitrate — measured at 27% smaller for ~3s of work plus
            // a second lossy pass. The 1.5x tolerance is the break-even point
            // where re-encoding stops paying for itself.
            if isH264, longSide <= 1280, sourceBitrate > 0,
               sourceBitrate <= Float(targetBitrate) * 1.5 {
                return VideoCompressionConfig(
                    isPassthrough: true,
                    maxLongSide: Int(longSide),
                    videoBitrate: 0,
                    audioBitrate: 0,
                    audioSampleRate: 0,
                    audioChannels: 0
                )
            }
            return VideoCompressionConfig(
                isPassthrough: false,
                maxLongSide: 1280,
                videoBitrate: targetBitrate,
                audioBitrate: 64_000,
                audioSampleRate: 44100,
                audioChannels: 2
            )
        case .original:
            if isH264 && longSide <= 1920 {
                return VideoCompressionConfig(
                    isPassthrough: true,
                    maxLongSide: Int(longSide),
                    videoBitrate: 0,
                    audioBitrate: 0,
                    audioSampleRate: 0,
                    audioChannels: 0
                )
            }
            return VideoCompressionConfig(
                isPassthrough: false,
                maxLongSide: 1920,
                videoBitrate: dynamicBitrate(for: duration, maxLongSide: 1920),
                audioBitrate: 64_000,
                audioSampleRate: 44100,
                audioChannels: 2
            )
        }
    }

    /// Duration-based dynamic bitrate (Telegram-style)
    private static func dynamicBitrate(for duration: TimeInterval, maxLongSide: Int) -> Int {
        let baseBitrate: Int
        switch duration {
        case ..<10:
            baseBitrate = 5_800_000
        case 10..<20:
            baseBitrate = 5_500_000
        case 20..<30:
            baseBitrate = 5_000_000
        default:
            baseBitrate = 3_700_000
        }
        // Scale bitrate proportionally for lower resolutions
        if maxLongSide < 1920 {
            return baseBitrate * maxLongSide / 1920
        }
        return baseBitrate
    }
}

// MARK: - VideoCompressor

public final class VideoCompressor: VideoCompressionCancellable, @unchecked Sendable {

    private let asset: AVAsset
    private let config: VideoCompressionConfig
    private let lock = UnfairLock()
    private var writer: AVAssetWriter?
    private var _isCancelled = false
    private var _progress: Double = 0

    private var isCancelled: Bool {
        get { lock.withLock { _isCancelled } }
        set { lock.withLock { _isCancelled = newValue } }
    }

    public private(set) var progress: Double {
        get { lock.withLock { _progress } }
        set { lock.withLock { _progress = newValue } }
    }

    /// True when `configured(asset:qualityPreset:)` decided the source already
    /// meets the target preset (H.264, long side ≤ preset cap) and the
    /// compressor would do a zero-recompress passthrough export. Exposed so the
    /// preprocessing operation can short-circuit the swap-payload flow: when
    /// passthrough is true we skip copying the file and just clear the
    /// preprocessing fields on the existing attachment row.
    public var isPassthrough: Bool { config.isPassthrough }

    public init(asset: AVAsset, config: VideoCompressionConfig) {
        self.asset = asset
        self.config = config
    }

    // MARK: - Factory

    public static func configured(
        asset: AVAsset,
        qualityPreset: VideoQualityPreset
    ) async throws -> VideoCompressor {
        let sourceCodec = await sourceCodec(of: asset) ?? kCMVideoCodecType_H264
        let sourceResolution = await sourceResolution(of: asset) ?? CGSize(width: 1920, height: 1080)
        // Synchronous property access: the async `load(_:)` variants are iOS 15+.
        // We only ever run against local file-backed assets on a background
        // queue, so the blocking read is negligible.
        let duration = CMTimeGetSeconds(asset.duration)

        let sourceBitrate = await sourceBitrate(of: asset) ?? 0

        let config = VideoCompressionConfig.resolve(
            preset: qualityPreset,
            sourceCodec: sourceCodec,
            sourceResolution: sourceResolution,
            sourceBitrate: sourceBitrate,
            duration: duration
        )

        return VideoCompressor(asset: asset, config: config)
    }

    // MARK: - Source Detection

    private static func sourceCodec(of asset: AVAsset) async -> CMVideoCodecType? {
        guard let track = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        // The sync API types this as [Any]; elements are always CMFormatDescription.
        guard let first = track.formatDescriptions.first else { return nil }
        return CMFormatDescriptionGetMediaSubType(first as! CMFormatDescription)
    }

    private static func sourceResolution(of asset: AVAsset) async -> CGSize? {
        guard let track = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        return track.naturalSize
    }

    /// Average video bitrate of the source, used to decide whether a re-encode
    /// would actually shrink anything.
    private static func sourceBitrate(of asset: AVAsset) async -> Float? {
        guard let track = asset.tracks(withMediaType: .video).first else {
            return nil
        }
        return track.estimatedDataRate
    }

    // MARK: - Compress

    public func compress(progressHandler: ((Double) -> Void)? = nil) async throws -> URL {
        if config.isPassthrough {
            return try await passthrough()
        }
        return try await reencode(progressHandler: progressHandler)
    }

    public func cancel() {
        isCancelled = true
        writer?.cancelWriting()
    }

    // MARK: - Passthrough

    private func passthrough() async throws -> URL {
        if let urlAsset = asset as? AVURLAsset,
           urlAsset.url.pathExtension.lowercased() == "mp4" {
            return urlAsset.url
        }

        let outputURL = VideoCompressor.temporaryOutputURL()
        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw VideoCompressionError.exportSessionCreationFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        await exportSession.export()

        guard !isCancelled else { throw VideoCompressionError.cancelled }

        guard exportSession.status == .completed else {
            throw VideoCompressionError.writeFailed(underlyingError: exportSession.error)
        }
        return outputURL
    }

    // MARK: - Re-encode

    private func reencode(progressHandler: ((Double) -> Void)?) async throws -> URL {
        let outputURL = VideoCompressor.temporaryOutputURL()

        let reader = try AVAssetReader(asset: asset)
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        writer.shouldOptimizeForNetworkUse = true
        self.writer = writer

        // Video track
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw VideoCompressionError.noVideoTrack
        }

        let naturalSize = videoTrack.naturalSize
        let transform = videoTrack.preferredTransform
        let nominalFrameRate = videoTrack.nominalFrameRate
        let totalSeconds = CMTimeGetSeconds(asset.duration)

        let outputSize = scaledSize(from: naturalSize, transform: transform)

        // Video reader output
        let videoReaderOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            ]
        )
        videoReaderOutput.alwaysCopiesSampleData = false
        reader.add(videoReaderOutput)

        // Video writer input
        let videoWriterInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: videoOutputSettings(size: outputSize, frameRate: nominalFrameRate)
        )
        videoWriterInput.expectsMediaDataInRealTime = false
        videoWriterInput.transform = transform
        writer.add(videoWriterInput)

        // Audio track (optional)
        let audioTrack = asset.tracks(withMediaType: .audio).first
        var audioReaderOutput: AVAssetReaderTrackOutput?
        var audioWriterInput: AVAssetWriterInput?

        if let audioTrack {
            let aReaderOutput = AVAssetReaderTrackOutput(
                track: audioTrack,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVSampleRateKey: config.audioSampleRate,
                    AVNumberOfChannelsKey: config.audioChannels
                ]
            )
            aReaderOutput.alwaysCopiesSampleData = false
            reader.add(aReaderOutput)
            audioReaderOutput = aReaderOutput

            let aWriterInput = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: audioOutputSettings()
            )
            aWriterInput.expectsMediaDataInRealTime = false
            writer.add(aWriterInput)
            audioWriterInput = aWriterInput
        }

        guard reader.startReading() else {
            throw VideoCompressionError.writeFailed(underlyingError: reader.error)
        }
        guard writer.startWriting() else {
            throw VideoCompressionError.writeFailed(underlyingError: writer.error)
        }
        writer.startSession(atSourceTime: .zero)

        // Process video and audio concurrently
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                try await self?.transferSamples(
                    from: videoReaderOutput,
                    to: videoWriterInput,
                    totalSeconds: totalSeconds,
                    progressHandler: progressHandler
                )
            }

            if let audioReaderOutput, let audioWriterInput {
                group.addTask { [weak self] in
                    try await self?.transferSamples(
                        from: audioReaderOutput,
                        to: audioWriterInput,
                        totalSeconds: 0,
                        progressHandler: nil
                    )
                }
            }

            try await group.waitForAll()
        }

        guard !isCancelled else {
            writer.cancelWriting()
            throw VideoCompressionError.cancelled
        }

        await writer.finishWriting()

        guard writer.status == .completed else {
            throw VideoCompressionError.writeFailed(underlyingError: writer.error)
        }

        // Validate file size
        let attrs = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = attrs[.size] as? UInt64 ?? 0
        guard fileSize <= 200 * 1024 * 1024 else {
            try? FileManager.default.removeItem(at: outputURL)
            throw VideoCompressionError.fileSizeTooLarge
        }

        return outputURL
    }

    // MARK: - Sample Transfer

    private func transferSamples(
        from output: AVAssetReaderOutput,
        to input: AVAssetWriterInput,
        totalSeconds: Double,
        progressHandler: ((Double) -> Void)?
    ) async throws {
        nonisolated(unsafe) let input = input
        nonisolated(unsafe) let output = output

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var didResume = false

            func finish(throwing error: Error? = nil) {
                guard !didResume else { return }
                didResume = true
                input.markAsFinished()
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }

            input.requestMediaDataWhenReady(on: DispatchQueue(label: "com.difft.videocompressor.\(input.mediaType.rawValue)")) { [weak self] in
                guard let self else {
                    finish()
                    return
                }

                while input.isReadyForMoreMediaData {
                    guard !self.isCancelled else {
                        finish(throwing: VideoCompressionError.cancelled)
                        return
                    }

                    guard let sampleBuffer = output.copyNextSampleBuffer() else {
                        finish()
                        return
                    }

                    input.append(sampleBuffer)

                    if totalSeconds > 0, let progressHandler {
                        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                        let current = CMTimeGetSeconds(timestamp)
                        let p = min(max(current / totalSeconds, 0), 1)
                        self.progress = p
                        progressHandler(p)
                    }
                }
            }
        }
    }

    // MARK: - Output Settings

    private func videoOutputSettings(size: CGSize, frameRate: Float) -> [String: Any] {
        let compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: config.videoBitrate,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
            AVVideoMaxKeyFrameIntervalKey: max(Int(frameRate) * 2, 30)
        ]

        return [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: compressionProperties
        ]
    }

    private func audioOutputSettings() -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: config.audioSampleRate,
            AVNumberOfChannelsKey: config.audioChannels,
            AVEncoderBitRateKey: config.audioBitrate
        ]
    }

    // MARK: - Helpers

    /// Compute output size based on naturalSize (pre-transform),
    /// clamping to maxLongSide and ensuring even dimensions.
    /// The transform is applied separately via `AVAssetWriterInput.transform`.
    private func scaledSize(from naturalSize: CGSize, transform: CGAffineTransform) -> CGSize {
        // For scaling purposes, the "display long side" accounts for rotation
        let isRotated = abs(transform.b) == 1 && abs(transform.c) == 1
        let displayWidth = isRotated ? naturalSize.height : naturalSize.width
        let displayHeight = isRotated ? naturalSize.width : naturalSize.height
        let displayLongSide = max(displayWidth, displayHeight)
        let maxLongSide = CGFloat(config.maxLongSide)

        // Use naturalSize (un-rotated) for the actual encode dimensions
        let width = naturalSize.width
        let height = naturalSize.height

        guard displayLongSide > maxLongSide else {
            return CGSize(
                width: evenDimension(width),
                height: evenDimension(height)
            )
        }

        let scale = maxLongSide / displayLongSide
        return CGSize(
            width: evenDimension(width * scale),
            height: evenDimension(height * scale)
        )
    }

    private func evenDimension(_ value: CGFloat) -> Int {
        let rounded = Int(value.rounded(.down))
        return rounded - (rounded % 2)
    }

    private static func temporaryOutputURL() -> URL {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("VideoCompressor", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
    }
}
