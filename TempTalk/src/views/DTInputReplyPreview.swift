//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation

@objc
protocol DTInputReplyPreviewDelegate: AnyObject {
    func inputReplyPreviewDidPressCancel(_ preview: DTInputReplyPreview)
}

@objc
class DTInputReplyPreview: UIView {
    @objc
    public weak var delegate: DTInputReplyPreviewDelegate?

    private let replyModel: DTReplyModel
    private let conversationStyle: ConversationStyle
    private var quotedMessageView: DTInputMessagePreView?
    private var heightConstraint: NSLayoutConstraint!

    @objc
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc
    init(quotedReply: DTReplyModel, conversationStyle: ConversationStyle) {
        self.replyModel = quotedReply
        self.conversationStyle = conversationStyle

        super.init(frame: .zero)

        self.heightConstraint = self.autoSetDimension(.height, toSize: 0)

        updateContents()

        NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)
    }
    
    @objc
    func applyTheme() {
        quotedMessageView?.applyTheme()
    }

    func updateContents() {
        subviews.forEach { $0.removeFromSuperview() }

        // We instantiate quotedMessageView late to ensure that it is updated
        // every time contentSizeCategoryDidChange (i.e. when dynamic type
        // sizes changes).
        
        if replyModel is OWSQuotedReplyModel {
            let quotedMessageView  = OWSQuotedMessageView.replyMessageView(forPreview: replyModel, conversationStyle: conversationStyle) as? OWSQuotedMessageView;
            self.quotedMessageView = quotedMessageView
        }
        guard let quotedMessageView = self.quotedMessageView else { return  }
        quotedMessageView.backgroundColor = .clear

        let cancelButton: UIButton = UIButton(type: .custom)

        let buttonImage: UIImage = #imageLiteral(resourceName: "quoted-message-cancel").withRenderingMode(.alwaysTemplate)
        cancelButton.setImage(buttonImage, for: .normal)
        cancelButton.imageView?.tintColor = .darkGray
        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)

        self.layoutMargins = .zero

        self.addSubview(quotedMessageView)
       
//        if quotedReply.quotedType == .reply {
//            quotedMessageView.autoPinEdgesToSuperviewMargins()
//        }else {
            self.addSubview(cancelButton)
            quotedMessageView.autoPinEdges(toSuperviewMarginsExcludingEdge: .trailing)
            cancelButton.autoPinEdges(toSuperviewMarginsExcludingEdge: .leading)
            cancelButton.autoPinEdge(.leading, to: .trailing, of: quotedMessageView)

            cancelButton.autoSetDimensions(to: CGSize(width: 40, height: 40))
//        }
        

        updateHeight()
    }

    // MARK: Actions

    @objc
    func didTapCancel(_ sender: Any) {
        self.delegate?.inputReplyPreviewDidPressCancel(self)
    }

    // MARK: Sizing

    func updateHeight() {
        guard let quotedMessageView = quotedMessageView else {
            owsFailDebug("\(logTag) missing quotedMessageView")
            return
        }
        let size = quotedMessageView.size(forMaxWidth: CGFloat.infinity)
        self.heightConstraint.constant = size.height
    }

    @objc func contentSizeCategoryDidChange(_ notification: Notification) {
        Logger.debug("\(self.logTag) in \(#function)")

        updateContents()
    }
}
