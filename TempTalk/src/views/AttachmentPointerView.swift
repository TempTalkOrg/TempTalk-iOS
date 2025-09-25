//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation
import TTServiceKit
import TTMessaging
import UIKit

class AttachmentPointerView: UIStackView {

    let TAG = "[AttachmentPointerView]"

    let isIncoming: Bool
    let attachmentPointer: TSAttachmentPointer
    let conversationStyle: ConversationStyle

    let contentView = UIStackView()
    let progressView = OWSProgressView()
    let typeIcon = UIImageView()
    let fileTypeLabel = UILabel()
    let nameLabel = UILabel()
    let statusLabel = UILabel()
    let filename: String
    let genericFilename = Localized("ATTACHMENT_DEFAULT_FILENAME", comment: "Generic filename for an attachment with no known name")

    var progress: CGFloat = 0 {
        didSet {
            self.progressView.progress = progress
        }
    }

    @objc
    required init(attachmentPointer: TSAttachmentPointer, isIncoming: Bool, conversationStyle: ConversationStyle) {
        self.attachmentPointer = attachmentPointer
        self.isIncoming = isIncoming
        self.conversationStyle = conversationStyle

        let attachmentPointerFilename = attachmentPointer.sourceFilename
        if let filename = attachmentPointerFilename, !filename.isEmpty {
          self.filename = filename
        } else {
            self.filename = genericFilename
        }

        super.init(frame: CGRect.zero)
        alignment = .center
        createSubviews()
        updateViews()

        if attachmentPointer.state == .downloading {
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(attachmentDownloadProgress(_:)),
                                                   name: NSNotification.Name.attachmentDownloadProgress,
                                                   object: nil)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc internal func attachmentDownloadProgress(_ notification: Notification) {
        let attachmentId = attachmentPointer.uniqueId
        
        guard let progress = (notification as NSNotification).userInfo?[kAttachmentDownloadProgressKey] as? NSNumber else {
            owsFailDebug("Attachment download notification missing progress.")
            return
        }
        guard let notificationAttachmentId = (notification as NSNotification).userInfo?[kAttachmentDownloadAttachmentIDKey] as? String else {
            owsFailDebug("Attachment download notification missing attachment id.")
            return
        }
        guard notificationAttachmentId == attachmentId else {
            return
        }
        self.progress = CGFloat(progress.floatValue)
    }

    @available(*, unavailable, message: "use init(call:) constructor instead.")
    required init(coder aDecoder: NSCoder) {
        fatalError("Unimplemented")
    }

    private static var vSpacing: CGFloat = 5
    private static var iconWidth: CGFloat = 36.0
    private static var iconHeight: CGFloat = 48.0
    private class func nameFont() -> UIFont { return UIFont.ows_dynamicTypeBody }
    private class func statusFont() -> UIFont { return UIFont.ows_dynamicTypeCaption1 }
    private static var progressWidth: CGFloat = 80
    private static var progressHeight: CGFloat = 6

    func createSubviews() {
        progressView.autoSetDimension(.width, toSize: AttachmentPointerView.progressWidth)
//        progressView.autoSetDimension(.height, toSize: AttachmentPointerView.progressHeight)

        
        typeIcon.image = UIImage(named: "generic-attachment")
        typeIcon.contentMode = .scaleAspectFit
        typeIcon.setCompressionResistanceHorizontalHigh()
        
        fileTypeLabel.textColor = UIColor.ows_light90
        fileTypeLabel.lineBreakMode = NSLineBreakMode.byTruncatingTail
        fileTypeLabel.font = UIFont.ows_dynamicTypeCaption1.ows_semibold()
        fileTypeLabel.adjustsFontSizeToFitWidth = true;
        fileTypeLabel.textAlignment = NSTextAlignment.center;
        // Center on icon.
        typeIcon.addSubview(fileTypeLabel)
        fileTypeLabel.autoCenterInSuperview()
        fileTypeLabel.autoSetDimension(ALDimension.width, toSize: (36 - 20))

        
        // truncate middle to be sure we include file extension
        nameLabel.lineBreakMode = .byTruncatingMiddle
        nameLabel.textAlignment = .center
        nameLabel.textColor = self.textColor
        nameLabel.font = AttachmentPointerView.nameFont()

        statusLabel.textAlignment = .center
        statusLabel.adjustsFontSizeToFitWidth = true
        statusLabel.numberOfLines = 2
        statusLabel.textColor = self.textColor
        statusLabel.font = AttachmentPointerView.statusFont()

        self.axis = .horizontal
        self.spacing = AttachmentPointerView.vSpacing
        
        contentView.axis = .vertical
        contentView.spacing = 2.0
        contentView.alignment = .leading
        contentView.addArrangedSubview(nameLabel)
        contentView.addArrangedSubview(progressView)
        contentView.addArrangedSubview(statusLabel)
        
        addArrangedSubview(typeIcon)
        addArrangedSubview(contentView)
    }

    @objc func updateViews() {
//        let emoji = TSAttachment.emoji(forMimeType: self.attachmentPointer.contentType)
        nameLabel.text = self.filename
        
        let byteCount = attachmentPointer.byteCount
        var fileSizeString: String = ""
        if (byteCount > 0){
            fileSizeString = OWSFormat.formatFileSize(UInt(byteCount))
        }
        
        var fileExtension: String = URL(string:filename.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? "")?.pathExtension ?? "?"
        if (fileExtension.count < 1) {
            fileExtension = MIMETypeUtil.fileExtension(forMIMEType: attachmentPointer.contentType) ?? "?"
        }
        
        
        for (key, obj) in MIMETypeUtil.fileIconToMIMETypesMap() {
            if(obj.contains(fileExtension)){
                fileExtension = key;
            }
        }
        
        let attachmentTypeImage = UIImage(named: "attachment_" + fileExtension.lowercased())
        if((attachmentTypeImage) != nil){
            typeIcon.image = attachmentTypeImage;
        }else{
            fileTypeLabel.text = fileExtension.localizedLowercase
        }

        statusLabel.text = {
            switch self.attachmentPointer.state {
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

        if attachmentPointer.state == .downloading {
            progressView.isHidden = false
            progressView.autoSetDimension(.height, toSize: AttachmentPointerView.progressHeight)
        } else {
            progressView.isHidden = true
            progressView.autoSetDimension(.height, toSize: 0)
        }
    }

    var textColor: UIColor {
        return conversationStyle.bubbleTextColor(isIncoming: isIncoming)
    }

    @objc
    public class func measureHeight() -> CGFloat {
        return ceil(nameFont().lineHeight +
            statusFont().lineHeight +
            progressHeight +
            vSpacing * 2)
    }

    @objc
    public func measureSizeWidthWith(maxWidth: CGFloat, minWidth: CGFloat) -> CGFloat {
        let labelsWidth = max(nameLabel.sizeThatFits(CGSize.zero).width, statusLabel.sizeThatFits(.zero).width)
        let contentWidth = (AttachmentPointerView.iconWidth + labelsWidth + AttachmentPointerView.vSpacing * 2);
        return ceil(max(min(maxWidth, contentWidth + AttachmentPointerView.vSpacing * 3), minWidth))

    }

    
}
