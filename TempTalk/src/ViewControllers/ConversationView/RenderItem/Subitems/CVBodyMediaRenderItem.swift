//
//  CVBodyMediaRenderItem.swift
//  Difft
//
//  Created by Jaymin on 2024/7/31.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit

class CVBodyMediaRenderItem: ConversationRenderItem {
    
    static let contactShareVSpacing: CGFloat = 12
    let audioAttachmentFileNameHeight: CGFloat = 24
    
    private let signleForwardTitleWidth: CGFloat
    
    var hasBodyMediaWithThumbnail: Bool {
        switch viewItem.messageCellType() {
        case .stillImage, .animatedImage, .video:
            return true
        default:
            return false
        }
    }
    
    var hasFullWidthMediaView: Bool {
        let cellType = viewItem.messageCellType()
        return hasBodyMediaWithThumbnail || cellType == .contactShare
    }
    
    init(viewItem: any ConversationViewItem, conversationStyle: ConversationStyle, signleForwardTitleWidth: CGFloat) {
        self.signleForwardTitleWidth = signleForwardTitleWidth
        
        super.init(viewItem: viewItem, conversationStyle: conversationStyle)
    }
    
    override func configure() {
        self.viewSize = measureSize()
    }
    
    private func measureSize() -> CGSize {
        var maxMessageWidth = conversationStyle.maxMessageWidth
        let minMessageWidth = signleForwardTitleWidth + Self.contactShareVSpacing * 2 - 5
        if !hasFullWidthMediaView {
            let hMargins = conversationStyle.textInsetHorizontal * 2
            maxMessageWidth -= hMargins
        }
        
        var result: CGSize = .zero
        switch viewItem.messageCellType() {
        case .stillImage, .animatedImage, .video:
            result = measureSizeForThumbnailMedia(maxMessageWidth: maxMessageWidth, minMessageWidth: minMessageWidth)
        case .audio:
            result = measureSizeForAudio(maxMessageWidth: maxMessageWidth)
        case .genericAttachment:
            result = measureSizeForGenericAttachment(minMessageWidth: minMessageWidth)
        case .downloadingAttachment:
            result = measureSizeForDownloadingAttachment(minMessageWidth: minMessageWidth)
        case .contactShare:
            result = measureSizeForContactShare()
        default:
            break
        }
        
        result.width = min(result.width, maxMessageWidth)
        
        return CGSizeCeil(result)
    }
    
    private func measureSizeForThumbnailMedia(maxMessageWidth: CGFloat, minMessageWidth: CGFloat) -> CGSize {
        let mediaSize = viewItem.mediaSize()
        var ratio = mediaSize.height > 0 ? mediaSize.width / mediaSize.height : 0
        // Clamp the aspect ratio so that very thin/wide content is presented
        // in a reasonable way.
        let minAspectRatio: CGFloat = 0.35
        let maxAspectRatio: CGFloat = 1 / minAspectRatio
        ratio = max(minAspectRatio, min(maxAspectRatio, ratio))
        
        let maxMediaWidth = maxMessageWidth
        let maxMediaHeight = maxMessageWidth
        var mediaWidth = maxMediaHeight * ratio
        var mediaHeight = maxMediaHeight
        
        if signleForwardTitleWidth > 0 {
            if mediaWidth < minMessageWidth {
                mediaWidth = minMessageWidth
            }
            mediaHeight = min(maxMediaHeight, ratio > 0 ? maxMediaWidth / ratio : 0)
        } else {
            if mediaWidth > maxMediaWidth {
                mediaWidth = maxMediaWidth
                mediaHeight = ratio > 0 ? maxMediaWidth / ratio : 0
            }
        }
        
        // We don't want to blow up small images unnecessarily.
        let kMinimumSize: CGFloat = 150
        let shortSrcDimension = min(mediaSize.width, mediaSize.height)
        let shortDstDimension = min(mediaWidth, mediaHeight)
        if shortDstDimension > kMinimumSize, shortDstDimension > shortSrcDimension {
            let factor = kMinimumSize / shortDstDimension
            mediaWidth *= factor
            mediaHeight *= factor
        }
        
        return CGSizeRound(.init(width: mediaWidth, height: mediaHeight))
    }
    
    private func measureSizeForAudio(maxMessageWidth: CGFloat) -> CGSize {
        let iconSize: CGFloat = 32
        let labelFont: UIFont = .ows_dynamicTypeCaption2
        let audioProgressViewHeight: CGFloat = iconSize
        let labelsHeight = labelFont.lineHeight
        let contentHeight = max(iconSize, labelsHeight)
        let vMargin: CGFloat = 0
        var height = contentHeight + vMargin * 2
        
        if let attachmentStream = viewItem.attachmentStream() {
            if attachmentStream.isAudio() && !attachmentStream.isVoiceMessage() {
                height += audioAttachmentFileNameHeight
            }
        }
        
        return .init(width: maxMessageWidth, height: height)
    }
    
    private func measureSizeForGenericAttachment(minMessageWidth: CGFloat) -> CGSize {
        guard let attachmentStream = viewItem.attachmentStream() else {
            return .zero
        }
        
        var size: CGSize = .zero
        let maxAttachmentWidth: CGFloat = 200
        let minAttachmentWidth: CGFloat = minMessageWidth
        
        let topLabelFont = UIFont.ows_dynamicTypeBody
        let bottomLabelFont = UIFont.ows_dynamicTypeCaption1
        let labelVSpacing: CGFloat = 2
        let labelsHeight = topLabelFont.lineHeight + bottomLabelFont.lineHeight + labelVSpacing
        
        let iconHeight: CGFloat = 48
        let vMargin: CGFloat = 5
        let contentHeight = max(iconHeight, labelsHeight)
        size.height = contentHeight + vMargin * 2
        
        let topText = {
            if let text = attachmentStream.sourceFilename?.stripped, !text.isEmpty {
                return text
            }
            if let text = MIMETypeUtil.fileExtension(forMIMEType: attachmentStream.contentType), !text.isEmpty {
                return text
            }
            return Localized("GENERIC_ATTACHMENT_LABEL")
        }()
        let topTextConfig: CVLabelConfig = .unstyledText(
            topText,
            font: topLabelFont,
            numberOfLines: 1,
            lineBreakMode: .byTruncatingMiddle
        )
        let topTextSize = topTextConfig.measure(maxWidth: maxAttachmentWidth)
        
        let bottomText = {
            guard let filePath = attachmentStream.filePath() else {
                return ""
            }
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: filePath) else {
                return ""
            }
            let fileSize = (attributes as NSDictionary).fileSize()
            return OWSFormat.formatFileSize(UInt(fileSize))
        }()
        let bottomTextConfig: CVLabelConfig = .unstyledText(
            bottomText,
            font: bottomLabelFont,
            numberOfLines: 1,
            lineBreakMode: .byTruncatingMiddle
        )
        let bottomTextSize = bottomTextConfig.measure(maxWidth: maxAttachmentWidth)
        
        let labelsWidth = max(topTextSize.width, bottomTextSize.width)
        let iconWidth: CGFloat = 36
        let hSpacing: CGFloat = 8
        let contentWidth = iconWidth + labelsWidth + hSpacing
        size.width = max(min(maxAttachmentWidth, contentWidth), minAttachmentWidth)
        
        return CGSizeCeil(size)
    }
    
    private func measureSizeForDownloadingAttachment(minMessageWidth: CGFloat) -> CGSize {
        guard let attachmentPointer = viewItem.attachmentPointer() else {
            return .zero
        }
        
        let fileName = {
            if let name = attachmentPointer.sourceFilename, !name.isEmpty {
                return name
            }
            return Localized("ATTACHMENT_DEFAULT_FILENAME")
        }()
        let fileNameFont = UIFont.ows_dynamicTypeBody
        let fileNameConfig: CVLabelConfig = .unstyledText(
            fileName,
            font: fileNameFont,
            numberOfLines: 1,
            lineBreakMode: .byTruncatingMiddle,
            textAlignment: .center
        )
        let maxWidth: CGFloat = 200
        let minWidth: CGFloat = minMessageWidth
        let fileNameSize = fileNameConfig.measure(maxWidth: maxWidth)
        
        let byteCount = attachmentPointer.byteCount
        var fileSizeString: String = ""
        if (byteCount > 0){
            fileSizeString = OWSFormat.formatFileSize(UInt(byteCount))
        }
        let status = {
            switch attachmentPointer.state {
            case .enqueued:
                return fileSizeString + " " +  Localized("ATTACHMENT_DOWNLOADING_STATUS_QUEUED", comment: "Status label when an attachment is enqueued, but hasn't yet started downloading")
            case .downloading:
                return Localized("ATTACHMENT_DOWNLOADING_STATUS_IN_PROGRESS", comment: "Status label when an attachment is currently downloading")
            case .failed:
                return Localized("ATTACHMENT_DOWNLOADING_STATUS_FAILED", comment: "Status label when an attachment download has failed.")
            @unknown default:
                return ""
            }
        }()
        let statusFont = UIFont.ows_dynamicTypeCaption1
        let statusConfig: CVLabelConfig = .unstyledText(
            status,
            font: statusFont,
            numberOfLines: 2,
            lineBreakMode: .byTruncatingTail,
            textAlignment: .center
        )
        let statusSize = statusConfig.measure(maxWidth: maxWidth)
        
        let iconWidth: CGFloat = 36.0
        let spacing: CGFloat = 5
        let labelsWidth = max(fileNameSize.width, statusSize.width)
        let contentWidth = iconWidth + labelsWidth + spacing * 2
        let sizeWidth = ceil(max(min(maxWidth, contentWidth + spacing * 3), minWidth))
        
        let progressHeight: CGFloat = 6
        let sizeHeight = ceil(fileNameFont.lineHeight + statusFont.lineHeight + progressHeight + spacing * 2)
        
        return .init(width: sizeWidth, height: sizeHeight)
    }
    
    private func measureSizeForContactShare() -> CGSize {
        return .init(width: 254, height: 120)
    }
    
}
