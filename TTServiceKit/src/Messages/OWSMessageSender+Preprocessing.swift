//
//  Copyright (c) 2026 Open Whisper Systems. All rights reserved.
//

import AVFoundation
import Foundation

@objc extension MessageSender {

    /// Pixel size from track metadata — no frame is decoded. Stamped onto
    /// placeholder rows before insert so `-[TSAttachmentStream imageSize]` sizes the
    /// cell from the row instead of falling back to `calculateImageSize`, which
    /// decodes a full-resolution still just to measure it.
    @objc
    public static func videoPixelSize(forFileURL url: URL) -> CGSize {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else {
            return .zero
        }
        let naturalSize = track.naturalSize
        let transform = track.preferredTransform
        let isRotated = abs(transform.b) == 1 && abs(transform.c) == 1
        return isRotated
            ? CGSize(width: naturalSize.height, height: naturalSize.width)
            : naturalSize
    }

    /// Returns a preprocessing operation for the given attachment, or nil if no
    /// preprocessing is needed (i.e. `preprocessingKind == None`). Bridged into
    /// ObjC because `OWSMessageSender.enqueueMessage:` lives in Objective-C.
    @objc
    public func makePreprocessingOperation(forMessage message: TSOutgoingMessage,
                                           attachment stream: TSAttachmentStream) -> OWSOperation? {
        switch stream.preprocessingKind {
        case .none:
            return nil
        case .videoCompression:
            return VideoCompressionOperation(
                messageUniqueId: message.uniqueId,
                attachmentUniqueId: stream.uniqueId
            )
        @unknown default:
            owsFailDebug("Unknown preprocessingKind \(stream.preprocessingKind.rawValue) on \(stream.uniqueId)")
            return nil
        }
    }
}
