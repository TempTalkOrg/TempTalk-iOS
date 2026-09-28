//
//  Copyright (c) 2026 Open Whisper Systems. All rights reserved.
//

import Photos

public enum MediaPreviewItemState {
    case pending
    case compressing
    case ready
    case failed(Error)
}

/// One asset on the media-preview screen, carrying the prepared attachment and
/// the state its cell renders from. `MediaPreviewProcessor` drives the state;
/// the cell observes `onStateChanged`.
public class MediaPreviewItem {

    public let asset: PHAsset
    public let isFullImage: Bool

    public private(set) var signalAttachment: SignalAttachment?
    public private(set) var state: MediaPreviewItemState = .pending

    public var onStateChanged: ((MediaPreviewItemState) -> Void)?

    public init(asset: PHAsset, isFullImage: Bool) {
        self.asset = asset
        self.isFullImage = isFullImage
    }

    /// Always hops to the main queue: callers are the processor's background
    /// operations, and both `state` and the cell callback are main-queue only.
    public func updateState(_ newState: MediaPreviewItemState, attachment: SignalAttachment? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.state = newState
            self.signalAttachment = attachment ?? self.signalAttachment
            self.onStateChanged?(self.state)
        }
    }

    public var isVideo: Bool {
        asset.mediaType == .video
    }
}
