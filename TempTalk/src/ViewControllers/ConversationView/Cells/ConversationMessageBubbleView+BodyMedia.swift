//
//  ConversationMessageBubbleView+BodyMedia.swift
//  Signal
//
//  Created by Jaymin on 2024/4/20.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit
import ImageIO
import SnapKit
import TTMessaging
import TTServiceKit

/// Coalesces and caches off-main encrypted attachment decodes.
enum EncryptedAttachmentThumbnailLoader {
    private static let queue = DispatchQueue(
        label: "org.temptalk.attachment-thumbnail.decrypt",
        qos: .userInitiated
    )
    private static let lock = NSLock()
    private static var completions: [String: [(UIImage?) -> Void]] = [:]

    private static let sharedCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 32 * 1024 * 1024
        return cache
    }()

    private static func cacheKey(attachmentId: String, maxPixelSize: Int) -> String {
        "\(attachmentId)@\(maxPixelSize)"
    }

    static func cachedImage(attachmentId: String, maxPixelSize: Int) -> UIImage? {
        sharedCache.object(forKey: cacheKey(attachmentId: attachmentId, maxPixelSize: maxPixelSize) as NSString)
    }

    static func store(_ image: UIImage, attachmentId: String, maxPixelSize: Int) {
        let key = cacheKey(attachmentId: attachmentId, maxPixelSize: maxPixelSize)
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        sharedCache.setObject(image, forKey: key as NSString, cost: cost)
    }

    static func loadCached(
        attachmentId: String,
        maxPixelSize: Int,
        work: @escaping () -> UIImage?,
        completion: @escaping (UIImage?) -> Void
    ) {
        let cacheKey = Self.cacheKey(attachmentId: attachmentId, maxPixelSize: maxPixelSize)
        if let cached = sharedCache.object(forKey: cacheKey as NSString) {
            completion(cached)
            return
        }
        load(attachmentId: cacheKey, work: work) { image in
            if let image {
                let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
                sharedCache.setObject(image, forKey: cacheKey as NSString, cost: cost)
            }
            completion(image)
        }
    }

    static func load(
        attachmentId: String,
        work: @escaping () -> UIImage?,
        completion: @escaping (UIImage?) -> Void
    ) {
        lock.lock()
        if completions[attachmentId] != nil {
            completions[attachmentId]?.append(completion)
            lock.unlock()
            return
        }
        completions[attachmentId] = [completion]
        lock.unlock()

        queue.async {
            let image = autoreleasepool(invoking: work)
            DispatchQueue.main.async {
                lock.lock()
                let callbacks = completions.removeValue(forKey: attachmentId) ?? []
                lock.unlock()
                callbacks.forEach { $0(image) }
            }
        }
    }

    static func downsampledImage(data: Data, maxPixelSize: Int = 512) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }
        return UIImage(cgImage: image)
    }
}

// MARK: - Body Media

extension ConversationMessageBubbleView {
    
    var hasBodyMediaWithThumbnail: Bool {
        guard let renderItem else {
            return false
        }
        return renderItem.hasBodyMediaWithThumbnail
    }
    
    func configureBodyMediaView(renderItem: CVMessageBubbleRenderItem, textViews: inout [TextViewEntity]) {
        guard let bodyMediaItem = renderItem.bodyMediaRenderItem else { return }
        
        let viewItem = renderItem.viewItem
        let style = renderItem.conversationStyle
        guard let bodyMediaView = createBodyMediaView(viewItem: viewItem, mediaItem: bodyMediaItem, style: style) else {
            return
        }
        bodyMediaView.clipsToBounds = true
        bodyMediaView.isUserInteractionEnabled = false
        self.bodyMediaView = bodyMediaView
        
        // stillImage, animatedImage, video, contactShare, task, vote
        if bodyMediaItem.hasFullWidthMediaView {
            if viewItem.isQuotedReply {
                addSpacingViewOnStackView(spacing: CVForwardSourceRenderItem.mediaQuotedReplyVSpacing)
            }
            
            // stillImage, animatedImage, video
            if bodyMediaItem.hasBodyMediaWithThumbnail {
                stackView.addArrangedSubview(bodyMediaView)
                
                let shapeView = OWSBubbleShapeView.bubbleDraw()
                shapeView.strokeThickness = CGHairlineWidth()
                shapeView.strokeColor = Theme.isDarkThemeEnabled ? .init(white: 1, alpha: 0.2) : .init(white: 0, alpha: 0.2)
                bodyMediaView.addSubview(shapeView)
                bubbleView.addPartnerView(shapeView)
                shapeView.snp.makeConstraints { make in
                    make.edges.equalToSuperview()
                }
                
            } else {
                switch viewItem.messageCellType() {
                case .contactShare:
                    stackView.addArrangedSubview(bodyMediaView)
                default:
                    break
                }
            }
        } else {
            textViews.append(.init(view: bodyMediaView, height: nil))
        }
    }
    
    func configureMediaFooterOverlay(renderItem: CVMessageBubbleRenderItem) {
        guard let bodyMediaView else { return }
        guard renderItem.shouldShowMediaFooter else { return }
        
        let maxGradientHeight: CGFloat = 40
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(white: 0, alpha: 0).cgColor,
            UIColor(white: 0, alpha: 0.4).cgColor
        ]
        let gradientView = OWSLayerView(frame: .zero) { layerView in
            var frame = layerView.bounds
            frame.size.height = min(maxGradientHeight, layerView.height)
            frame.origin.y = layerView.height - frame.size.height
            gradientLayer.frame = frame
        }
        gradientView.layer.addSublayer(gradientLayer)
        bodyMediaView.addSubview(gradientView)
        gradientView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

// MARK: - Private

extension ConversationMessageBubbleView {
    private func createBodyMediaView(viewItem: ConversationViewItem, mediaItem: CVBodyMediaRenderItem, style: ConversationStyle) -> UIView? {
        var bodyMediaView: UIView? = nil
        switch viewItem.messageCellType() {
        case .stillImage:
            bodyMediaView = createStillImageView(viewItem: viewItem)
        case .animatedImage:
            bodyMediaView = createAnimatedImageView(viewItem: viewItem)
        case .audio:
            bodyMediaView = createAudioView(viewItem: viewItem, style: style)
        case .video:
            bodyMediaView = createVideoView(viewItem: viewItem)
        case .videoTranscoding:
            bodyMediaView = createVideoTranscodingView(viewItem: viewItem)
        case .genericAttachment:
            bodyMediaView = createGenericAttachmentView(viewItem: viewItem, style: style)
        case .downloadingAttachment:
            bodyMediaView = createDownloadingAttachmentView(viewItem: viewItem, mediaItem: mediaItem, style: style)
        case .contactShare:
            bodyMediaView = createContactShareView(viewItem: viewItem, style: style)
        default:
            break
        }
        return bodyMediaView
    }
    
    private func createStillImageView(viewItem: ConversationViewItem) -> UIView {
        let stillImageView = UIImageView()
        // We need to specify a contentMode since the size of the image
        // might not match the aspect ratio of the view.
        stillImageView.contentMode = .scaleAspectFill
        // Use trilinear filters for better scaling quality at
        // some performance cost.
        stillImageView.layer.minificationFilter = CALayerContentsFilter.trilinear
        stillImageView.layer.magnificationFilter = CALayerContentsFilter.trilinear
        stillImageView.backgroundColor = .white
        
        addAttachmentUploadViewIfNecessary(viewItem: viewItem)
        
        var encryptedThumbnailLoadInFlight = false
        var shouldDisplayThumbnail = false

        self.loadCellContentBlock = { [weak self, weak stillImageView] in
            guard let self else { return }
            guard let stillImageView else { return }
            shouldDisplayThumbnail = true
            guard stillImageView.image == nil else { return }
            guard let attachmentStream = viewItem.attachmentStream() else {
                return
            }

            // hasEncryptedFile also covers retained pre-commit instances.
            if attachmentStream.hasEncryptedFile {
                let attachmentId = attachmentStream.uniqueId
                let cacheKey = attachmentId as NSString
                if let cachedImage = self.mediaCache?.object(forKey: cacheKey) as? UIImage {
                    stillImageView.image = cachedImage
                    return
                }
                guard viewItem.cellMediaLoadFailureCount < Self.maxMediaLoadRetries else { return }
                guard !encryptedThumbnailLoadInFlight else { return }
                encryptedThumbnailLoadInFlight = true

                let mediaCache = self.mediaCache
                EncryptedAttachmentThumbnailLoader.load(
                    attachmentId: attachmentId,
                    work: {
                        guard let data = attachmentStream.decryptedData() else { return nil }
                        return EncryptedAttachmentThumbnailLoader.downsampledImage(data: data)
                    },
                    completion: { [weak self, weak stillImageView] image in
                        encryptedThumbnailLoadInFlight = false
                        guard let self else { return }

                        if let image {
                            viewItem.cellMediaLoadFailureCount = 0
                            mediaCache?.setObject(image, forKey: cacheKey)
                        }

                        guard shouldDisplayThumbnail else { return }
                        guard viewItem.attachmentStream()?.uniqueId == attachmentId else { return }
                        guard let stillImageView, stillImageView.image == nil else { return }
                        guard let image else {
                            viewItem.cellMediaLoadFailureCount += 1
                            Logger.error("Failed to asynchronously load encrypted thumbnail (attempt \(viewItem.cellMediaLoadFailureCount)/\(Self.maxMediaLoadRetries))")
                            if viewItem.cellMediaLoadFailureCount >= Self.maxMediaLoadRetries {
                                self.showAttachmentErrorView(on: stillImageView)
                            }
                            return
                        }
                        stillImageView.image = image
                    }
                )
                return
            }

            guard let thumbnailPath = attachmentStream.thumbnailPath() else { return }
            let kMaxCachableSize = 1024 * 1024
            let thumbnailSize = OWSFileSystem.fileSize(ofPath: thumbnailPath)?.int64Value ?? 0
            let shouldSkipCache = thumbnailSize < kMaxCachableSize
            stillImageView.image = self.tryToLoadMedia(
                viewItem: viewItem,
                loadMedia: {
                    return attachmentStream.thumbnailImage()
                },
                mediaView: stillImageView,
                cache: self.mediaCache,
                cacheKey: attachmentStream.uniqueId,
                shouldSkipCache: shouldSkipCache
            )
        }
        
        self.unloadCellContentBlock = {
            shouldDisplayThumbnail = false
            stillImageView.image = nil
        }
        
        return stillImageView
    }
    
    /// Loads encrypted animated media off the main thread.
    private func loadAnimatedImage(
        viewItem: ConversationViewItem,
        into imageView: YYAnimatedImageView
    ) {
        guard let attachmentStream = viewItem.attachmentStream() else { return }
        let attachmentId = attachmentStream.uniqueId
        let cacheKey = attachmentId as NSString

        if let cached = self.mediaCache?.object(forKey: cacheKey) as? UIImage {
            imageView.image = cached
            return
        }

        guard attachmentStream.hasEncryptedFile else {
            imageView.image = self.tryToLoadMedia(
                viewItem: viewItem,
                loadMedia: {
                    if attachmentStream.isValidImage(), let data = attachmentStream.decryptedData() {
                        return YYImage(data: data)
                    }
                    return nil
                },
                mediaView: imageView,
                cache: self.mediaCache,
                cacheKey: attachmentId,
                shouldSkipCache: false
            )
            return
        }

        guard viewItem.cellMediaLoadFailureCount < Self.maxMediaLoadRetries else { return }

        // Register once per attachment and target view.
        let decodeToken = AnimatedDecodeToken(attachmentId: attachmentId, viewId: ObjectIdentifier(imageView))
        guard animatedDecodeInFlight != decodeToken else { return }
        animatedDecodeInFlight = decodeToken

        let mediaCache = self.mediaCache
        EncryptedAttachmentThumbnailLoader.load(
            attachmentId: "gif:\(attachmentId)",
            work: {
                guard let data = attachmentStream.decryptedData() else { return nil }
                return YYImage(data: data)
            },
            completion: { [weak self, weak imageView] image in
                guard let self else { return }
                if self.animatedDecodeInFlight == decodeToken {
                    self.animatedDecodeInFlight = nil
                }

                if let image {
                    viewItem.cellMediaLoadFailureCount = 0
                    mediaCache?.setObject(image, forKey: cacheKey)
                }

                guard viewItem.attachmentStream()?.uniqueId == attachmentId else { return }
                guard let imageView, imageView.image == nil else { return }
                guard let image else {
                    viewItem.cellMediaLoadFailureCount += 1
                    Logger.error("Failed to asynchronously load encrypted animated image (attempt \(viewItem.cellMediaLoadFailureCount)/\(Self.maxMediaLoadRetries))")
                    if viewItem.cellMediaLoadFailureCount >= Self.maxMediaLoadRetries {
                        self.showAttachmentErrorView(on: imageView)
                    }
                    return
                }
                imageView.image = image
            }
        )
    }

    private func createAnimatedImageView(viewItem: ConversationViewItem) -> UIView {
        let uniqueId = viewItem.attachmentStream()?.uniqueId

        // Reuse the SAME view within THIS cell when the attachment is unchanged. A message
        // status change (sending -> sent) or a neighbor's grouping change rebuilds this cell;
        // creating a fresh YYAnimatedImageView would restart the animation from frame 0 (the
        // flash). YYAnimatedImageView pauses when removed from window and resumes from its
        // current frame when re-added, so re-adding the kept instance is seamless.
        if let reused = reusableAnimatedView, let uniqueId, reusableAnimatedAttachmentId == uniqueId {
            // The upload/status overlay was torn down in prepareForReuse; re-add so a
            // sending -> sent transition still refreshes (overlay drops once uploaded).
            addAttachmentUploadViewIfNecessary(viewItem: viewItem)

            // Keep the current frame: only reload if the image was genuinely dropped (e.g.
            // cold media cache after leaving/re-entering the conversation). Never reset an
            // already-set image — that would reintroduce the restart.
            let reloadBlock: () -> Void = { [weak self, weak reused] in
                guard let self, let reused else { return }
                guard reused.image == nil else { return }
                self.loadAnimatedImage(viewItem: viewItem, into: reused)
            }
            self.loadCellContentBlock = reloadBlock
            // Do NOT nil the image on unload: keep the frame so re-adding resumes cleanly.
            self.unloadCellContentBlock = { }
            return reused
        }

        let animatedImageView = YYAnimatedImageView()
        animatedImageView.contentMode = .scaleAspectFill
        // Neutral placeholder while the GIF decodes (e.g. re-entering with a fresh
        // media cache) — not white (harsh) or clear (invisible/looks broken).
        animatedImageView.backgroundColor = Theme.isDarkThemeEnabled ? .ows_gray75 : .ows_gray05

        addAttachmentUploadViewIfNecessary(viewItem: viewItem)

        // A message update (upload state / read receipt) rebuilds this view. Show frame 0 immediately
        // (synchronous cache hit) and play from the start — do NOT seek to a saved frame index: for
        // animated WebP a mid-frame seek forces an inter-frame decode and flashes the placeholder.
        let loadBlock: () -> Void = { [weak self, weak animatedImageView] in
            guard let self, let animatedImageView else { return }
            guard animatedImageView.image == nil else { return }
            self.loadAnimatedImage(viewItem: viewItem, into: animatedImageView)
        }

        self.loadCellContentBlock = loadBlock

        // Keep the image on unload so the frame survives a reconfigure/off-screen cycle; the
        // decoded YYImage also lives in mediaCache (keyed by uniqueId) and live cells are bounded.
        self.unloadCellContentBlock = { }

        // Load now (image cache hit is instant) so a reconfigure shows the first frame
        // immediately instead of an empty/placeholder gap.
        loadBlock()

        // Remember this instance for seamless reuse within THIS cell. On recycle for a
        // different attachment the id mismatches, so we build fresh and overwrite here.
        reusableAnimatedView = animatedImageView
        reusableAnimatedAttachmentId = uniqueId

        return animatedImageView
    }
    
    private func createAudioView(viewItem: ConversationViewItem, style: ConversationStyle) -> UIView? {
        guard let attachmentStream = viewItem.attachmentStream() else {
            Logger.info("creare audio message attachmentStream failture")
            return nil
        }
        let isIncoming = viewItem.interaction.interactionType() == .incomingMessage
        let audioView = OWSAudioMessageView(
            attachment: attachmentStream,
            isIncoming: isIncoming,
            viewItem: viewItem,
            conversationStyle: style
        )
        viewItem.associateAudioMessageView(audioView)
        audioView.createContents()
        
        addAttachmentUploadViewIfNecessary(viewItem: viewItem)
        
        self.loadCellContentBlock = {
            // Do nothing.
        }
        self.unloadCellContentBlock = {
            // Do nothing.
        }
        
        return audioView
    }
    
    private func createVideoView(viewItem: ConversationViewItem) -> UIView {
        let stillImageView = UIImageView()
        // We need to specify a contentMode since the size of the image
        // might not match the aspect ratio of the view.
        stillImageView.contentMode = .scaleAspectFill
        // Use trilinear filters for better scaling quality at
        // some performance cost.
        stillImageView.layer.minificationFilter = CALayerContentsFilter.trilinear
        stillImageView.layer.magnificationFilter = CALayerContentsFilter.trilinear
        
        let playButton = makeVideoPlayButton()
        stillImageView.addSubview(playButton)
        playButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        // Same overlay the compression placeholder uses, driven by upload state
        // instead. The play button stays put underneath so the only thing that
        // changes on completion is the arc going away.
        //
        // Gated on the send still being live: a failed message never finishes
        // uploading, so the arc would spin forever. `ConversationViewItem` routes
        // failed placeholders here precisely so the standard failure UI can show.
        let isFailedSend = (viewItem.interaction as? TSOutgoingMessage)?.messageState == .failed
        let processingOverlay = makeVideoProcessingOverlay()
        processingOverlay.isHidden = true
        stillImageView.addSubview(processingOverlay)
        processingOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        addAttachmentUploadViewIfNecessary(viewItem: viewItem, suppressesProgressUI: true) { isAttachmentReady in
            processingOverlay.isHidden = isAttachmentReady || isFailedSend
        }
        
        var isVideoStillLoadInFlight = false
        var shouldDisplayVideoStill = false

        self.loadCellContentBlock = { [weak self] in
            guard let self else { return }
            shouldDisplayVideoStill = true
            guard stillImageView.image == nil else {
                return
            }
            guard let attachmentStream = viewItem.attachmentStream() else {
                return
            }
            let cacheKey = attachmentStream.uniqueId as NSString
            if let cachedImage = self.mediaCache?.object(forKey: cacheKey) as? UIImage {
                stillImageView.image = cachedImage
                return
            }
            guard viewItem.cellMediaLoadFailureCount < Self.maxMediaLoadRetries else {
                return
            }
            guard !isVideoStillLoadInFlight else {
                return
            }
            isVideoStillLoadInFlight = true

            attachmentStream.videoStillImage(withMaxSize: CGSize(width: 512, height: 512)) { [weak self, weak stillImageView] image in
                DispatchQueue.main.async {
                    isVideoStillLoadInFlight = false
                    guard let self, let stillImageView else { return }
                    guard shouldDisplayVideoStill else { return }
                    guard viewItem.attachmentStream()?.uniqueId == attachmentStream.uniqueId else { return }
                    guard stillImageView.image == nil else { return }

                    guard let image else {
                        viewItem.cellMediaLoadFailureCount += 1
                        Logger.error("Failed to asynchronously load video still (attempt \(viewItem.cellMediaLoadFailureCount)/\(Self.maxMediaLoadRetries))")
                        if viewItem.cellMediaLoadFailureCount >= Self.maxMediaLoadRetries {
                            self.showAttachmentErrorView(on: stillImageView)
                        }
                        return
                    }

                    viewItem.cellMediaLoadFailureCount = 0
                    self.mediaCache?.setObject(image, forKey: cacheKey)
                    stillImageView.image = image
                }
            }
        }

        self.unloadCellContentBlock = {
            shouldDisplayVideoStill = false
            stillImageView.image = nil
        }

        return stillImageView
    }

    /// Dim layer plus spinning arc, shown while a video is being processed. One
    /// treatment covers both compression and upload: they're separate phases
    /// internally, but the user has no reason to tell them apart, and switching
    /// visuals midway just looks like a glitch.
    private func makeVideoProcessingOverlay() -> UIView {
        let container = UIView()
        container.isUserInteractionEnabled = false

        let dim = UIView()
        dim.backgroundColor = UIColor(white: 0, alpha: 0.3)
        container.addSubview(dim)
        dim.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let arc = SpinningArcView(lineWidth: 2)
        container.addSubview(arc)
        arc.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(40)
        }

        return container
    }

    /// Translucent dark disc around a white play triangle. Shared with the
    /// transcoding placeholder so it doesn't change appearance when compression ends.
    private func makeVideoPlayButton() -> UIView {
        let diameter: CGFloat = 48
        let circle = UIView()
        circle.backgroundColor = .black.withAlphaComponent(0.7)
        circle.isUserInteractionEnabled = false
        circle.clipsToBounds = true
        circle.layer.cornerRadius = diameter / 2
        circle.snp.makeConstraints { make in
            make.size.equalTo(diameter)
        }

        let triangle = UIImageView(image: UIImage(named: "video_play_triangle"))
        triangle.contentMode = .scaleAspectFit
        circle.addSubview(triangle)
        triangle.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(24)
        }

        return circle
    }

    /// Placeholder counterpart to `createVideoView`, shown while the video is still
    /// compressing: the 512pt thumbnail, the same play button plus a spinning arc,
    /// and no upload progress view (uploads only start after preprocessing). The
    /// cell is rebuilt on every observer reload, so the arc goes away on its own
    /// once the op clears the placeholder state.
    private func createVideoTranscodingView(viewItem: ConversationViewItem) -> UIView {
        let stillImageView = UIImageView()
        stillImageView.contentMode = .scaleAspectFill
        stillImageView.layer.minificationFilter = CALayerContentsFilter.trilinear
        stillImageView.layer.magnificationFilter = CALayerContentsFilter.trilinear
        stillImageView.backgroundColor = .black

        // Same button and overlay as the playable cell, so the only visible
        // change when compression ends is the arc going away.
        let playButton = makeVideoPlayButton()
        stillImageView.addSubview(playButton)
        playButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        let processingOverlay = makeVideoProcessingOverlay()
        stillImageView.addSubview(processingOverlay)
        processingOverlay.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        self.loadCellContentBlock = {
            guard stillImageView.image == nil else {
                return
            }
            guard let attachmentStream = viewItem.attachmentStream() else {
                return
            }
            // Thumbnail only, never `image()` — that decodes a full-resolution still
            // off the uncompressed source on the main thread. Written
            // off-transaction, so early reloads may find it missing; the dark
            // backdrop stands in until the touch after generation. Not routed
            // through `tryToLoadMedia` (a nil there trips its retry counter into an
            // error view) and not cached (the swap keeps the same uniqueId, so a
            // low-res still would leak into the playable cell).
            stillImageView.image = attachmentStream.thumbnailImage()
        }

        self.unloadCellContentBlock = {
            stillImageView.image = nil
        }

        return stillImageView
    }

    private func createGenericAttachmentView(viewItem: ConversationViewItem, style: ConversationStyle) -> UIView? {
        guard let attachmentStream = viewItem.attachmentStream() else {
            return nil
        }
        let isIncoming = viewItem.interaction.interactionType() == .incomingMessage
        let attachmentView = OWSGenericAttachmentView(attachment: attachmentStream, isIncoming: isIncoming)
        attachmentView.createContents(with: style)
        
        addAttachmentUploadViewIfNecessary(viewItem: viewItem)
        
        self.loadCellContentBlock = {
            // Do nothing.
        }
        self.unloadCellContentBlock = {
            // Do nothing.
        }
        
        return attachmentView
    }
    
    private func createDownloadingAttachmentView(
        viewItem: ConversationViewItem,
        mediaItem: CVBodyMediaRenderItem,
        style: ConversationStyle
    ) -> UIView? {
        guard let attachmentPointer = viewItem.attachmentPointer() else {
            return nil
        }
        
        var downloadingView: UIView?
        if mediaItem.isDownloadingAttachmentWithThumbnail {
            downloadingView = DTImageDownloadingView(attachmentPointer: attachmentPointer)
        } else {
            let isIncoming = viewItem.interaction.interactionType() == .incomingMessage
            let downloadView = AttachmentPointerView(
                attachmentPointer: attachmentPointer,
                isIncoming: isIncoming,
                conversationStyle: style
            )
            
            let wrapper = UIView()
            wrapper.addSubview(downloadView)
            downloadView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            downloadingView = wrapper
        }
        
        self.loadCellContentBlock = { [weak self] in
            guard let self else { return }
            guard !viewItem.hadAutoDownloaded else { return }
            
            let contentType = attachmentPointer.contentType
            guard MIMETypeUtil.isImage(contentType) ||
                  MIMETypeUtil.isAnimated(contentType) ||
                  attachmentPointer.attachmentType == .voiceMessage else {
                return
            }
            guard attachmentPointer.state == .failed || attachmentPointer.state == .enqueued || attachmentPointer.state == .expired else {
                return
            }
            
            if let delegate = self.delegate {
                delegate.messageBubbleView?(
                    self,
                    didTapDownloadFailedAttachmentWith: viewItem,
                    autoRestart: true,
                    attachmentPointer: attachmentPointer
                )
                viewItem.hadAutoDownloaded = true
            }
        }
        
        self.unloadCellContentBlock = {
            // Do nothing.
        }
        
        return downloadingView
    }
    
    private func createContactShareView(viewItem: ConversationViewItem, style: ConversationStyle) -> UIView? {
        guard let contactShare = viewItem.contactShare else {
            return nil
        }
        let isIncoming = viewItem.interaction.interactionType() == .incomingMessage
        let contactShareView = OWSContactShareView(
            contactShare: contactShare,
            isIncoming: isIncoming,
            conversationStyle: style
        )
        contactShareView.createContents()
        
        self.loadCellContentBlock = {
            // Do nothing.
        }
        self.unloadCellContentBlock = {
            // Do nothing.
        }
        
        return contactShareView
    }
    
    private func addAttachmentUploadViewIfNecessary(
        viewItem: ConversationViewItem,
        suppressesProgressUI: Bool = false,
        stateCallback: ((Bool) -> Void)? = nil
    ) {
        guard viewItem.interaction.interactionType() == .outgoingMessage else { return }
        guard let attachmentStream = viewItem.attachmentStream(), !attachmentStream.isUploaded else {
            return
        }
        let attachmentUploadView = AttachmentUploadView(
            attachment: attachmentStream,
            attachmentStateCallback: stateCallback
        )
        attachmentUploadView.suppressesProgressUI = suppressesProgressUI
        bubbleView.addSubview(attachmentUploadView)
        attachmentUploadView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private static let maxMediaLoadRetries = 3

    private func tryToLoadMedia<T: AnyObject>(
        viewItem: ConversationViewItem,
        loadMedia: () -> T?,
        mediaView: UIView,
        cache: NSCache<AnyObject, AnyObject>?,
        cacheKey: String,
        shouldSkipCache: Bool
    ) -> T? {
        guard viewItem.cellMediaLoadFailureCount < Self.maxMediaLoadRetries else { return nil }
        if let cache, let mediaCache = cache.object(forKey: cacheKey as NSString) as? T {
            return mediaCache
        }
        let media = loadMedia()
        if let media {
            viewItem.cellMediaLoadFailureCount = 0
            if !shouldSkipCache, let cache {
                cache.setObject(media, forKey: cacheKey as NSString)
            }
        } else {
            viewItem.cellMediaLoadFailureCount += 1
            Logger.error("Failed to load cell media (attempt \(viewItem.cellMediaLoadFailureCount)/\(Self.maxMediaLoadRetries)), url: \(viewItem.attachmentStream()?.mediaURL()?.absoluteString ?? "")")
            if viewItem.cellMediaLoadFailureCount >= Self.maxMediaLoadRetries {
                showAttachmentErrorView(on: mediaView)
            }
        }
        return media
    }
    
    private func showAttachmentErrorView(on mediaView: UIView) {
        let errorView = UIView()
        errorView.backgroundColor = .init(white: 0.85, alpha: 1)
        errorView.isUserInteractionEnabled = false
        mediaView.addSubview(errorView)
        errorView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}
