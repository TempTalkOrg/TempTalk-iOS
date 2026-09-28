//
//  Copyright (c) 2026 Open Whisper Systems. All rights reserved.
//

import Foundation

/// JSON-encoded payload persisted in `TSAttachmentStream.preprocessingParams`
/// for placeholders awaiting video compression. The placeholder needs to
/// remember which quality preset the user picked at attachment-approval time,
/// because `VideoCompressionOperation` may run minutes later (e.g. after an
/// app relaunch's stale-placeholder pass marks it failed, then the user retries)
/// and `VideoCompressor` cannot otherwise recover that intent.
public struct VideoCompressionPreprocessingParams: Codable {
    public let qualityPreset: VideoQualityPreset

    public init(qualityPreset: VideoQualityPreset) {
        self.qualityPreset = qualityPreset
    }

    public func encoded() throws -> Data {
        return try JSONEncoder().encode(self)
    }

    public static func decode(_ data: Data) throws -> VideoCompressionPreprocessingParams {
        return try JSONDecoder().decode(VideoCompressionPreprocessingParams.self, from: data)
    }
}

extension VideoQualityPreset: Codable {
    private enum RawValue: String, Codable {
        case auto
        case original
    }

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(RawValue.self)
        switch raw {
        case .auto: self = .auto
        case .original: self = .original
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .auto: try container.encode(RawValue.auto)
        case .original: try container.encode(RawValue.original)
        }
    }
}
