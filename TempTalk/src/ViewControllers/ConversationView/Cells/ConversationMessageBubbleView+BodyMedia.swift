//
//  ConversationMessageBubbleView+BodyMedia.swift
//  Signal
//
//  Created by Jaymin on 2024/4/20.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit
import SnapKit
import TTMessaging
import TTServiceKit

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
        guard let bodyMediaView = createBodyMediaView(viewItem: viewItem, style: style) else {
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
    private func createBodyMediaView(viewItem: ConversationViewItem, style: ConversationStyle) -> UIView? {
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
        case .genericAttachment:
            bodyMediaView = createGenericAttachmentView(viewItem: viewItem, style: style)
        case .downloadingAttachment:
            bodyMediaView = createDownloadingAttachmentView(viewItem: viewItem, style: style)
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
        
        self.loadCellContentBlock = { [weak self] in
            guard let self else { return }
            guard stillImageView.image == nil else { return }
            guard let attachmentStream = viewItem.attachmentStream(),
                  let thumbnailPath = attachmentStream.thumbnailPath() else {
                return
            }
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
            stillImageView.image = nil
        }
        
        return stillImageView
    }
    
    private func createAnimatedImageView(viewItem: ConversationViewItem) -> UIView {
        let animatedImageView = YYAnimatedImageView()
        animatedImageView.contentMode = .scaleAspectFill
        animatedImageView.backgroundColor = .white
        
        addAttachmentUploadViewIfNecessary(viewItem: viewItem)
        
        self.loadCellContentBlock = { [weak self] in
            guard let self else { return }
            guard animatedImageView.image == nil else { return }
            guard let attachmentStream = viewItem.attachmentStream(),
                  let filePath = attachmentStream.filePath() else {
                return
            }
            animatedImageView.image = self.tryToLoadMedia(
                viewItem: viewItem,
                loadMedia: {
                    if attachmentStream.isValidImage() {
                        return YYImage(contentsOfFile: filePath)
                    }
                    return nil
                },
                mediaView: animatedImageView,
                cache: self.mediaCache,
                cacheKey: attachmentStream.uniqueId,
                shouldSkipCache: false
            )
        }
        
        self.unloadCellContentBlock = {
            animatedImageView.image = nil
        }
        
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
        
        let playIcon = UIImage(named: "play_button")
        let playImageView = UIImageView(image: playIcon)
        stillImageView.addSubview(playImageView)
        playImageView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        addAttachmentUploadViewIfNecessary(viewItem: viewItem) { isAttachmentReady in
            playImageView.isHidden = !isAttachmentReady
        }
        
        self.loadCellContentBlock = { [weak self] in
            guard let self else { return }
            guard stillImageView.image == nil else {
                return
            }
            guard let attachmentStream = viewItem.attachmentStream() else {
                return
            }
            stillImageView.image = self.tryToLoadMedia(
                viewItem: viewItem,
                loadMedia: {
                    return attachmentStream.image()
                },
                mediaView: stillImageView,
                cache: self.mediaCache,
                cacheKey: attachmentStream.uniqueId,
                shouldSkipCache: false
            )
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
    
    private func createDownloadingAttachmentView(viewItem: ConversationViewItem, style: ConversationStyle) -> UIView? {
        guard let attachmentPointer = viewItem.attachmentPointer() else {
            return nil
        }
        let isIncoming = viewItem.interaction.interactionType() == .incomingMessage
        let downloadView = AttachmentPointerView(
            attachmentPointer: attachmentPointer,
            isIncoming: isIncoming,
            conversationStyle: style
        )
        self.downloadView = downloadView
        
        let wrapper = UIView()
        wrapper.addSubview(downloadView)
        downloadView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.loadCellContentBlock = { [weak self] in
            guard let self else { return }
            guard !viewItem.hadAutoDownloaded else { return }
            
            let contentType = attachmentPointer.contentType
            guard MIMETypeUtil.isImage(contentType) || MIMETypeUtil.isAnimated(contentType) else {
                return
            }
            guard attachmentPointer.state == .failed || attachmentPointer.state == .enqueued else {
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
        
        return wrapper
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
        bubbleView.addSubview(attachmentUploadView)
        attachmentUploadView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func tryToLoadMedia<T: AnyObject>(
        viewItem: ConversationViewItem,
        loadMedia: () -> T?,
        mediaView: UIView,
        cache: NSCache<AnyObject, AnyObject>?,
        cacheKey: String,
        shouldSkipCache: Bool
    ) -> T? {
        guard !viewItem.didCellMediaFailToLoad else { return nil }
        if let cache, let mediaCache = cache.object(forKey: cacheKey as NSString) as? T {
            return mediaCache
        }
        let media = loadMedia()
        if let media {
            if !shouldSkipCache, let cache {
                cache.setObject(media, forKey: cacheKey as NSString)
            }
        } else {
            Logger.error("Failed to load cell media, url: \(viewItem.attachmentStream()?.mediaURL()?.absoluteString ?? "")")
            viewItem.didCellMediaFailToLoad = true
            showAttachmentErrorView(on: mediaView)
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
