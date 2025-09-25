//
// Copyright 2019 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Accelerate
import AVFoundation
import Foundation

public protocol AudioWaveformSamplingObserver: AnyObject {
    func audioWaveformDidFinishSampling(_ audioWaveform: AudioWaveform)
}

// MARK: -

@objc public class AudioWaveformManagerImpl: NSObject, AudioWaveformManager {

    private typealias AttachmentId = String

    
    // create single instance
    @objc public static let shared = AudioWaveformManagerImpl()
    
//    public func audioWaveform(
//        forAttachment attachment: AttachmentStream,
//        highPriority: Bool
//    ) -> Task<AudioWaveform, Error> {
//        switch attachment.info.contentType {
//        case .file, .invalid, .image, .video, .animatedImage:
//            return Task {
//                throw OWSAssertionError("Invalid attachment type!")
//            }
//        case .audio(_, let relativeWaveformFilePath):
//            guard let relativeWaveformFilePath else {
//                return Task {
//                    // We could not generate a waveform at write time; don't retry now.
//                    throw AudioWaveformError.invalidAudioFile
//                }
//            }
//            let encryptionKey = attachment.attachment.encryptionKey
//            return Task {
//                let fileURL = AttachmentStream.absoluteAttachmentFileURL(
//                    relativeFilePath: relativeWaveformFilePath
//                )
//                // waveform is validated at creation time; no need to revalidate every read.
//                let data = try Cryptography.decryptFileWithoutValidating(
//                    at: fileURL,
//                    metadata: .init(
//                        key: encryptionKey
//                    )
//                )
//                return try AudioWaveform(archivedData: data)
//            }
//        }
//    }

    public func audioWaveform(
        forAudioPath audioPath: String,
        waveformPath: String
    ) -> Task<AudioWaveform, Error> {
        return buildAudioWaveForm(
            source: .unencryptedFile(path: audioPath),
            waveformPath: waveformPath,
            identifier: .file(UUID()),
            highPriority: false
        )
    }

//    public func audioWaveform(
//        forEncryptedAudioFileAtPath filePath: String,
//        encryptionKey: Data,
//        plaintextDataLength: UInt32,
//        mimeType: String,
//        outputWaveformPath: String
//    ) async throws {
//        let task = buildAudioWaveForm(
//            source: .encryptedFile(
//                path: filePath,
//                encryptionKey: encryptionKey,
//                plaintextDataLength: plaintextDataLength,
//                mimeType: mimeType
//            ),
//            waveformPath: outputWaveformPath,
//            identifier: .file(UUID()),
//            highPriority: false
//        )
//        // Don't need the waveform; its written to disk by now.
//        _ = try await task.value
//    }
    
    @objc public func audioDuration(from filePath: String) -> TimeInterval {
        let fileURL = URL(fileURLWithPath: filePath)
        let asset = AVURLAsset(url: fileURL)
        let duration = asset.duration

        guard duration.isValid && !duration.isIndefinite else {
            return 0.0
        }

        return CMTimeGetSeconds(duration)
    }

    @objc public func audioWaveformSync(
        forAudioPath audioPath: String
    ) throws -> AudioWaveform {
        return try _buildAudioWaveForm(
            source: .unencryptedFile(path: audioPath),
            waveformPath: nil
        )
    }

//    public func audioWaveformSync(
//        forEncryptedAudioFileAtPath filePath: String,
//        encryptionKey: Data,
//        plaintextDataLength: UInt32,
//        mimeType: String
//    ) throws -> AudioWaveform {
//        return try _buildAudioWaveForm(
//            source: .encryptedFile(
//                path: filePath,
//                encryptionKey: encryptionKey,
//                plaintextDataLength: plaintextDataLength,
//                mimeType: mimeType
//            ),
//            waveformPath: nil
//        )
//    }

    private enum AVAssetSource {
        case unencryptedFile(path: String)
//        case encryptedFile(
//            path: String,
//            encryptionKey: Data,
//            plaintextDataLength: UInt32,
//            mimeType: String
//        )
    }

    private enum WaveformId: Hashable {
        case attachment(AttachmentId)
        case file(UUID)

        var cacheKey: String? {
            switch self {
            case .attachment(let id):
                return id
            case .file:
                // We don't cache ad-hoc file results.
                return nil
            }
        }
    }

    /// "High priority" just gets its own queue.
    private let taskQueue = SerialTaskQueue()
    private let highPriorityTaskQueue = SerialTaskQueue()

    private var cache = LRUCache<AttachmentId, Weak<AudioWaveform>>(maxSize: 64)

    private func buildAudioWaveForm(
        source: AVAssetSource,
        waveformPath: String,
        identifier: WaveformId,
        highPriority: Bool
    ) -> Task<AudioWaveform, Error> {
        return Task {
            if
                let cacheKey = identifier.cacheKey,
                let cachedValue = self.cache[cacheKey]?.value
            {
                return cachedValue
            }

            let taskQueue = highPriority ? self.highPriorityTaskQueue : self.taskQueue
            return try await taskQueue.enqueue(operation: {
                let waveform = try self._buildAudioWaveForm(
                    source: source,
                    waveformPath: waveformPath
                )

                identifier.cacheKey.map { self.cache[$0] = Weak(value: waveform) }
                return waveform
            }).value
        }
    }

    private func _buildAudioWaveForm(
        source: AVAssetSource,
        // If non-nil, writes the waveform to this output file.
        waveformPath: String?
    ) throws -> AudioWaveform {
        if let waveformPath {
            do {
                let waveformData = try Data(contentsOf: URL(fileURLWithPath: waveformPath))
                // We have a cached waveform on disk, read it into memory.
                return try AudioWaveform(archivedData: waveformData)
            } catch POSIXError.ENOENT, CocoaError.fileReadNoSuchFile, CocoaError.fileNoSuchFile {
                // The file doesn't exist...
            } catch {
                owsFailDebug("Error: \(error)")
                // Remove the file from disk and create a new one.
                OWSFileSystem.deleteFileIfExists(waveformPath)
            }
        }

        let asset: AVAsset
        switch source {
        case .unencryptedFile(let path):
            asset = try assetFromUnencryptedAudioFile(atAudioPath: path)
//        case let .encryptedFile(path, encryptionKey, plaintextDataLength, mimeType):
//            asset = try assetFromEncryptedAudioFile(
//                atPath: path,
//                encryptionKey: encryptionKey,
//                plaintextDataLength: plaintextDataLength,
//                mimeType: mimeType
//            )
        }

        guard asset.isReadable else {
            owsFailDebug("unexpectedly encountered unreadable audio file.")
            throw AudioWaveformError.invalidAudioFile
        }

        guard CMTimeGetSeconds(asset.duration) <= Self.maximumDuration else {
            throw AudioWaveformError.audioTooLong
        }

        guard let urlAsset = asset as? AVURLAsset else {
            throw AudioWaveformError.invalidAudioFile
        }

        let waveform = try sampleWaveformUsingAVAudioFile(url: urlAsset.url)
        
        // 兜底校验：如果波形数据异常（太短，或者全是同一个值，或平均分贝极低）
        if waveform.decibelSamples.count < 10 ||
           waveform.decibelSamples.allSatisfy({ abs($0 - waveform.decibelSamples.first!) < 0.1 }) ||
           waveform.decibelSamples.allSatisfy({ $0 < AudioWaveform.silenceThreshold }) {
            // 替换成默认静音波形（或其他兜底数据）
            return AudioWaveform(decibelSamples: Array(repeating: AudioWaveform.silenceThreshold, count: AudioWaveform.sampleCount))
        }


//        if let waveformPath {
//            do {
//                let parentDirectoryPath = (waveformPath as NSString).deletingLastPathComponent
//                if OWSFileSystem.ensureDirectoryExists(parentDirectoryPath) {
//                    switch source {
//                    case .unencryptedFile:
//                        try waveform.write(toFile: waveformPath, atomically: true)
//                    case .encryptedFile(_, let encryptionKey, _, _):
//                        let waveformData = try waveform.archive()
//                        let (encryptedWaveform, _) = try Cryptography.encrypt(waveformData, encryptionKey: encryptionKey)
//                        try encryptedWaveform.write(to: URL(fileURLWithPath: waveformPath), options: .atomicWrite)
//                    }
//
//                } else {
//                    owsFailDebug("Could not create parent directory.")
//                }
//            } catch {
//                owsFailDebug("Error: \(error)")
//            }
//        }

        return waveform
    }

    private func assetFromUnencryptedAudioFile(
        atAudioPath audioPath: String
    ) throws -> AVAsset {
        let audioUrl = URL(fileURLWithPath: audioPath)

        var asset = AVURLAsset(url: audioUrl)

        if !asset.isReadable {
            if let extensionOverride = AudioWaveformManagerImpl.alternativeAudioFileExtension(fileExtension: audioUrl.pathExtension) {
                let symlinkPath = OWSFileSystem.temporaryFilePath(
                    fileExtension: extensionOverride,
                    isAvailableWhileDeviceLocked: true
                )
                do {
                    try FileManager.default.createSymbolicLink(atPath: symlinkPath,
                                                               withDestinationPath: audioPath)
                } catch {
                    owsFailDebug("Failed to create voice memo symlink: \(error)")
                    throw AudioWaveformError.fileIOError
                }
                asset = AVURLAsset(url: URL(fileURLWithPath: symlinkPath))
            }
        }

        return asset
    }

//    private func assetFromEncryptedAudioFile(
//        atPath filePath: String,
//        encryptionKey: Data,
//        plaintextDataLength: UInt32,
//        mimeType: String
//    ) throws -> AVAsset {
//        let audioUrl = URL(fileURLWithPath: filePath)
//        return try AVAsset.fromEncryptedFile(
//            at: audioUrl,
//            encryptionKey: encryptionKey,
//            plaintextLength: plaintextDataLength,
//            mimeType: mimeType
//        )
//    }

    // MARK: - Sampling

    /// The maximum duration asset that we will display waveforms for.
    /// It's too intensive to sample a waveform for really long audio files.
    fileprivate static let maximumDuration: TimeInterval = 15 * kMinuteInterval

    private func sampleWaveform(asset: AVAsset) throws -> AudioWaveform {
        try Task.checkCancellation()

        guard let assetReader = try? AVAssetReader(asset: asset) else {
            owsFailDebug("Unexpectedly failed to initialize asset reader")
            throw AudioWaveformError.fileIOError
        }

        // We just draw the waveform based on the first audio track.
        guard let audioTrack = assetReader.asset.tracks.first(where: { $0.mediaType == .audio }) else {
            owsFailDebug("audio file has no tracks")
            throw AudioWaveformError.invalidAudioFile
        }

        let trackOutput = AVAssetReaderTrackOutput(
            track: audioTrack,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
        )
        assetReader.add(trackOutput)

        let decibelSamples = try readDecibels(from: assetReader)

        try Task.checkCancellation()

        return AudioWaveform(decibelSamples: decibelSamples)
    }
    
    private func sampleWaveformUsingAVAudioFile(url: URL) throws -> AudioWaveform {
        let audioFile = try AVAudioFile(forReading: url)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioWaveformError.invalidAudioFile
        }

        try audioFile.read(into: buffer)

        guard let channelData = buffer.floatChannelData?[0] else {
            throw AudioWaveformError.invalidAudioFile
        }

        let sampleCount = Int(buffer.frameLength)
        let floatSamples = UnsafeBufferPointer(start: channelData, count: sampleCount)

        // 将浮点[-1,1]放大到Int16范围[-32768,32767]
        var scaledSamples = [Float](repeating: 0, count: sampleCount)
        var scale: Float = Float(Int16.max)
        vDSP_vsmul(floatSamples.baseAddress!, 1, &scale, &scaledSamples, 1, vDSP_Length(sampleCount))

        // 转换成Int16
        var int16Samples = [Int16](repeating: 0, count: sampleCount)
        vDSP_vfixr16(scaledSamples, 1, &int16Samples, 1, vDSP_Length(sampleCount))

        // 更新采样器
        let sampler = AudioWaveformSampler(inputCount: sampleCount, outputCount: AudioWaveform.sampleCount)
        int16Samples.withUnsafeBufferPointer { bufferPtr in
            sampler.update(bufferPtr)
        }

        return AudioWaveform(decibelSamples: sampler.finalize())
    }


    private func readDecibels(from assetReader: AVAssetReader) throws -> [Float] {
        let sampler = AudioWaveformSampler(
            inputCount: sampleCount(from: assetReader),
            outputCount: AudioWaveform.sampleCount
        )

        assetReader.startReading()
        while assetReader.status == .reading {
            // Stop reading if the operation is cancelled.
            try Task.checkCancellation()

            guard let trackOutput = assetReader.outputs.first else {
                owsFailDebug("track output unexpectedly missing")
                throw AudioWaveformError.invalidAudioFile
            }

            // Process any newly read data.
            guard
                let nextSampleBuffer = trackOutput.copyNextSampleBuffer(),
                let blockBuffer = CMSampleBufferGetDataBuffer(nextSampleBuffer)
            else {
                // There is no more data to read, break
                break
            }

            var lengthAtOffset = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            let result = CMBlockBufferGetDataPointer(
                blockBuffer,
                atOffset: 0,
                lengthAtOffsetOut: &lengthAtOffset,
                totalLengthOut: nil,
                dataPointerOut: &dataPointer
            )
            guard result == kCMBlockBufferNoErr else {
                owsFailDebug("track data unexpectedly inaccessible")
                throw AudioWaveformError.invalidAudioFile
            }
            let bufferPointer = UnsafeBufferPointer(start: dataPointer, count: lengthAtOffset)
            bufferPointer.withMemoryRebound(to: Int16.self) { sampler.update($0) }
            CMSampleBufferInvalidate(nextSampleBuffer)
        }

        return sampler.finalize()
    }

    private func sampleCount(from assetReader: AVAssetReader) -> Int {
        let samplesPerChannel = Int(assetReader.asset.duration.value)

        // We will read in the samples from each channel, interleaved since
        // we only draw one waveform. This gives us an average of the channels
        // if it is, for example, a stereo audio file.
        return samplesPerChannel * channelCount(from: assetReader)
    }

    private func channelCount(from assetReader: AVAssetReader) -> Int {
        guard
            let output = assetReader.outputs.first as? AVAssetReaderTrackOutput,
            let formatDescriptions = output.track.formatDescriptions as? [CMFormatDescription]
        else {
            return 0
        }

        var channelCount = 0

        for description in formatDescriptions {
            guard let basicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(description) else {
                continue
            }
            channelCount = Int(basicDescription.pointee.mChannelsPerFrame)
        }

        return channelCount
    }
    
    public static func alternativeAudioFileExtension(fileExtension: String) -> String? {
        // In some cases, Android sends audio messages with the "audio/mpeg" mime type. This
        // makes our choice of file extension ambiguous—`.mp3` or `.m4a`? AVFoundation uses the
        // extension to read the file, and if the extension is wrong, it won't be readable.
        //
        // We "lie" about the extension to generate the waveform so that AVFoundation may read
        // it. This is brittle but necessary to work around the buggy marriage of Android's
        // content type and AVFoundation's behavior.
        //
        // Note that we probably still want this code even if Android updates theirs, because
        // iOS users might have existing attachments.
        //
        // See:
        // <https://github.com/signalapp/Signal-iOS/issues/3590>.
        switch fileExtension {
        case "m4a": return "aac"
        case "mp3": return "m4a"
        default: return nil
        }
    }
}
