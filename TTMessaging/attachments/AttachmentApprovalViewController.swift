//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation
import AVFoundation
import MediaPlayer
import SnapKit
import TTServiceKit

@objc
public protocol AttachmentApprovalViewControllerDelegate: AnyObject {
    func attachmentApproval(_ attachmentApproval: AttachmentApprovalViewController, didApproveAttachments attachments: [SignalAttachment])
    func attachmentApproval(_ attachmentApproval: AttachmentApprovalViewController, didCancelAttachments attachments: [SignalAttachment])
    func attachmentApprovalDidTapConfide(_ attachmentApproval: AttachmentApprovalViewController)
}

@objc
public class AttachmentApprovalViewController: OWSViewController, CaptioningToolbarDelegate {

    deinit {
        OWSLogger.info("dealloc")
    }
    
    let TAG = "[AttachmentApprovalViewController]"
    weak var delegate: AttachmentApprovalViewControllerDelegate?

    // We sometimes shrink the attachment view so that it remains somewhat visible
    // when the keyboard is presented.
    enum AttachmentViewScale {
        case fullsize, compact
    }

    // MARK: Properties

    let attachments: [SignalAttachment]
    private let initialIsConfidential: Bool

    public private(set) var bottomToolbar: UIView?
    private(set) var collectionView: UICollectionView?
    // MARK: Initializers

    @available(*, unavailable, message:"use attachment: constructor instead.")
    required public init?(coder aDecoder: NSCoder) {
        fatalError("unimplemented")
    }

    @objc
    required public convenience init(attachments: [SignalAttachment], delegate: AttachmentApprovalViewControllerDelegate) {
        self.init(attachments: attachments, isConfidential: false, delegate: delegate)
    }

    public init(attachments: [SignalAttachment], isConfidential: Bool, delegate: AttachmentApprovalViewControllerDelegate) {
        for attachment in attachments {
            assert(!attachment.hasError)
        }
        self.attachments = attachments
        self.initialIsConfidential = isConfidential
        self.delegate = delegate

        super.init()
    }

    // MARK: Autorotate
    
    public override var shouldAutorotate: Bool {
        false
    }
    
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }
    
    public override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .portrait
    }

    // MARK: View Lifecycle

    override public func viewDidLoad() {
        super.viewDidLoad()

        let cancelButton = RoundMediaButton(image: .init(named: "x-28"), backgroundStyle: .blur)
        cancelButton.addTarget(self, action: #selector(cancelPressed(sender:)), for: .touchUpInside)
        view.addSubview(cancelButton)
        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.equalToSuperview().offset(8)
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        (bottomToolbar as? CaptioningToolbar)?.dismissKeyboard()
    }

    @objc
    public class func wrappedInNavController(attachments: [SignalAttachment], delegate: AttachmentApprovalViewControllerDelegate) -> OWSNavigationController {
        return wrappedInNavController(attachments: attachments, isConfidential: false, delegate: delegate)
    }

    public class func wrappedInNavController(attachments: [SignalAttachment], isConfidential: Bool, delegate: AttachmentApprovalViewControllerDelegate) -> OWSNavigationController {
        let vc = AttachmentApprovalViewController(attachments: attachments, isConfidential: isConfidential, delegate: delegate)
        let navController = OWSNavigationController(rootViewController: vc)
        navController.modalPresentationStyle = .overFullScreen
        navController.navigationBar.isHidden = true

        return navController
    }

    override public func viewWillLayoutSubviews() {
        Logger.debug("\(logTag) in \(#function)")
        super.viewWillLayoutSubviews()

        // e.g. if flipping to/from landscape
        updateMinZoomScaleForSize(view.bounds.size)
    }

    override public func viewWillAppear(_ animated: Bool) {
        Logger.debug("\(logTag) in \(#function)")
        super.viewWillAppear(animated)

        CurrentAppContext().setStatusBarHidden(true, animated: animated)
    }

    override public func viewDidAppear(_ animated: Bool) {
        Logger.debug("\(logTag) in \(#function)")
        super.viewDidAppear(animated)
    }

    override public func viewWillDisappear(_ animated: Bool) {
        Logger.debug("\(logTag) in \(#function)")
        super.viewWillDisappear(animated)

        // Since this VC is being dismissed, the "show status bar" animation would feel like
        // it's occuring on the presenting view controller - it's better not to animate at all.
        CurrentAppContext().setStatusBarHidden(false, animated: false)
    }

    // MARK: - Create Views

    public override func loadView() {

        self.view = UIView()
        let backgroundColor = UIColor.black
        self.view.backgroundColor = backgroundColor

        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height)
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView?.backgroundColor = backgroundColor
        collectionView?.dataSource = self
        collectionView?.delegate = self
        collectionView?.showsVerticalScrollIndicator = false
        collectionView?.showsHorizontalScrollIndicator = false
        collectionView?.isPagingEnabled = true
        if let collectionView = collectionView {
            self.view.addSubview(collectionView)
            collectionView.autoPinEdgesToSuperviewEdges()
            collectionView.register(DFAttachmentApprovalCollectionCell.self, forCellWithReuseIdentifier: DFAttachmentApprovalCollectionCell.reuseIdentifier())
        }
        

//        if isZoomable {
            // Add top and bottom gradients to ensure toolbar controls are legible
            // when placed over image/video preview which may be a clashing color.
            let topGradient = GradientView(from: backgroundColor, to: UIColor.clear)
            self.view.addSubview(topGradient)
            topGradient.autoPinWidthToSuperview()
            topGradient.autoPinEdge(toSuperviewEdge: .top)
            topGradient.autoSetDimension(.height, toSize: ScaleFromIPhone5(60))
//        }

        // Bottom Toolbar
        let captioningToolbar = CaptioningToolbar()
        captioningToolbar.captioningToolbarDelegate = self
        captioningToolbar.isConfidential = initialIsConfidential
        self.bottomToolbar = captioningToolbar

        // Hide the play button embedded in the MediaView and replace it with our own.
        // This allows us to zoom in on the media view without zooming in on the button
    }

    override public var inputAccessoryView: UIView? {
        self.bottomToolbar?.layoutIfNeeded()
        return self.bottomToolbar
    }

    override public var canBecomeFirstResponder: Bool {
        return true
    }

//    private func makeClearToolbar() -> UIToolbar {
//        let toolbar = UIToolbar()
//
//        toolbar.backgroundColor = UIColor.clear
//
//        // Making a toolbar transparent requires setting an empty uiimage
//        toolbar.setBackgroundImage(UIImage(), forToolbarPosition: .any, barMetrics: .default)
//
//        // hide 1px top-border
//        toolbar.clipsToBounds = true
//
//        return toolbar
//    }

    fileprivate func updateMinZoomScaleForSize(_ size: CGSize) {
        Logger.debug("\(logTag) in \(#function)")

//        // Ensure bounds have been computed
//        mediaMessageView.layoutIfNeeded()
//        guard mediaMessageView.bounds.width > 0, mediaMessageView.bounds.height > 0 else {
//            Logger.warn("\(logTag) bad bounds in \(#function)")
//            return
//        }
//
//        let widthScale = size.width / mediaMessageView.bounds.width
//        let heightScale = size.height / mediaMessageView.bounds.height
//        let minScale = min(widthScale, heightScale)
//        scrollView.maximumZoomScale = minScale * 5.0
//        scrollView.minimumZoomScale = minScale
//        scrollView.zoomScale = minScale
    }
    
    @objc func cancelPressed(sender: UIButton) {
        self.delegate?.attachmentApproval(self, didCancelAttachments: attachments)
    }

    // MARK: CaptioningToolbarDelegate

    public func captioningToolbarDidBeginEditing(_ captioningToolbar: CaptioningToolbar) {
        self.scaleAttachmentView(.compact)
    }

    public func captioningToolbarDidEndEditing(_ captioningToolbar: CaptioningToolbar) {
        self.scaleAttachmentView(.fullsize)
    }

    public func captioningToolbarDidTapSend(_ captioningToolbar: CaptioningToolbar, captionText: String?) {
        self.approveAttachment(captionText: captionText)
    }

    public func captioningToolbarDidTapConfide(_ captioningToolbar: CaptioningToolbar) {
        delegate?.attachmentApprovalDidTapConfide(self)
    }

    // MARK: Helpers

    private func approveAttachment(captionText: String?) {
        guard let captionText = captionText else {
            sendApproveAttachments(captionText: nil)
            return
        }
        
        guard let sensitiveWord = DTSensitiveWordsConfig.checkSensitiveWords(captionText) else {
            sendApproveAttachments(captionText: captionText)
            return
        }
        let warning = String(format: Localized("SENSITIVE_WORDS_WARNING_TEXT", comment: ""), sensitiveWord)
        showAlert(.alert, title: Localized("COMMON_WARNING_TITLE", comment: ""), msg: warning, cancelTitle: Localized("TXT_CANCEL_TITLE", comment: ""), confirmTitle: Localized("SEND_BUTTON_TITLE", comment: ""), confirmStyle: .destructive) {
            self.sendApproveAttachments(captionText: captionText)
        }
    }

    private func sendApproveAttachments(captionText: String?) {
        shouldAllowAttachmentViewResizing = false
        bottomToolbar?.isUserInteractionEnabled = false
        bottomToolbar?.isHidden = true

        guard let lastAttachment = attachments.last else { return }
        lastAttachment.captionText = captionText
        delegate?.attachmentApproval(self, didApproveAttachments: attachments)
    }
    
    // When the keyboard is popped, it can obscure the attachment view.
    // so we sometimes allow resizing the attachment.
    private var shouldAllowAttachmentViewResizing: Bool = true

    private func scaleAttachmentView(_ fit: AttachmentViewScale) {
        guard shouldAllowAttachmentViewResizing else {
            if let collectionView = self.collectionView, collectionView.transform != CGAffineTransform.identity {
                UIView.animate(withDuration: 0.2) {
                    collectionView.transform = CGAffineTransform.identity
                }
            }
            return
        }

        guard let collectionView = self.collectionView else { return }

        switch fit {
        case .fullsize:
            UIView.animate(withDuration: 0.2) {
                collectionView.transform = CGAffineTransform.identity
            }
        case .compact:
            UIView.animate(withDuration: 0.2) {
                let kScaleFactor: CGFloat = 0.7
                let scale = CGAffineTransform(scaleX: kScaleFactor, y: kScaleFactor)

                let originalHeight = collectionView.bounds.size.height

                // Position the new scaled item to be centered with respect
                // to it's new size.
                let heightDelta = originalHeight * (1 - kScaleFactor)
                let translate = CGAffineTransform(translationX: 0, y: -heightDelta / 2)

                collectionView.transform = scale.concatenating(translate)
            }
        }
    }
}

public protocol CaptioningToolbarDelegate: AnyObject {
    func captioningToolbarDidTapSend(_ captioningToolbar: CaptioningToolbar, captionText: String?)
    func captioningToolbarDidTapConfide(_ captioningToolbar: CaptioningToolbar)
    func captioningToolbarDidBeginEditing(_ captioningToolbar: CaptioningToolbar)
    func captioningToolbarDidEndEditing(_ captioningToolbar: CaptioningToolbar)
}

public class CaptioningToolbar: UIView, UITextViewDelegate {

    weak var captioningToolbarDelegate: CaptioningToolbarDelegate?
    private let sendButton: UIButton
    private let confideButton: UIButton
    private let textView: UITextView
    private let lengthLimitLabel: UILabel
    private let backgroundView = UIView()
    private let topSepLine = CaptioningDashedLineView()

    public var isConfidential: Bool = false {
        didSet {
            confideButton.isSelected = isConfidential
            placeholderLabel.text = isConfidential
                ? Localized("Confidential_message", comment: "")
                : Localized("IMAGE_PREVIEW_ADD_MESSAGE")
            backgroundView.backgroundColor = isConfidential ? UIColor(rgbHex: 0x051732) : UIColor(rgbHex: 0x181A20)
            topSepLine.setDashed(isConfidential, color: isConfidential ? .ows_themeBlue : UIColor(rgbHex: 0x181A20))
        }
    }

    // Layout Constants

    let kMinTextViewHeight: CGFloat = 36
    var maxTextViewHeight: CGFloat {
        // About ~4 lines in portrait and ~3 lines in landscape.
        // Otherwise we risk obscuring too much of the content.
        return UIDevice.current.orientation.isPortrait ? 160 : 100
    }
    var textViewHeightConstraint: NSLayoutConstraint?
    var textViewHeight: CGFloat

    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.ows_dynamicTypeBody
        label.text = Localized("IMAGE_PREVIEW_ADD_MESSAGE")
        label.textColor = UIColor(rgbHex: 0x848484)
        return label
    }()

    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    class MessageTextView: UITextView {
        // When creating new lines, contentOffset is animated, but because because
        // we are simultaneously resizing the text view, this can cause the
        // text in the textview to be "too high" in the text view.
        // Solution is to disable animation for setting content offset.
        override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
            super.setContentOffset(contentOffset, animated: false)
        }
    }

    public override var intrinsicContentSize: CGSize {
        get {
            // Since we have `self.autoresizingMask = UIViewAutoresizingFlexibleHeight`, we must specify
            // an intrinsicContentSize. Specifying CGSize.zero causes the height to be determined by autolayout.
            return CGSize.zero
        }
    }

    public init() {
        self.sendButton = UIButton(type: .system)
        self.confideButton = UIButton(type: .custom)
        self.textView =  MessageTextView()
        self.textViewHeight = kMinTextViewHeight
        self.lengthLimitLabel = UILabel()

        super.init(frame: CGRect.zero)

        // Specifying autorsizing mask and an intrinsic content size allows proper
        // sizing when used as an input accessory view.
        self.autoresizingMask = .flexibleHeight
        self.translatesAutoresizingMaskIntoConstraints = false
        self.backgroundColor = UIColor.clear

        textView.delegate = self
        textView.backgroundColor = .clear
        textView.textColor = .white
        textView.font = UIFont.ows_dynamicTypeBody
        textView.returnKeyType = .default
        textView.textContainerInset = UIEdgeInsets(top: 7, left: 8, bottom: 7, right: 8)
        textView.scrollIndicatorInsets = UIEdgeInsets(top: 5, left: 0, bottom: 5, right: 3)
        textView.tintColor = .white
        textView.addSubview(placeholderLabel)

        sendButton.addTarget(self, action: #selector(didTapSend), for: .touchUpInside)
        sendButton.tintColor = UIColor.white
        sendButton.backgroundColor = UIColor.clear
        sendButton.setBackgroundImage(UIImage(named: "ic_inputbar_send"), for: .normal)
        // UI automation: icon-only button — without an id it is unaddressable from
        // XCUITest/Maestro. Literal (not DTConversationAccessibilityID) because that enum
        // lives in the app target and TTMessaging cannot import it.
        sendButton.accessibilityIdentifier = "approval.btn.send"
        sendButton.layer.cornerRadius = 4
        sendButton.layer.masksToBounds = true

        confideButton.setImage(UIImage(named: "input_attachment_confide"), for: .normal)
        confideButton.setImage(UIImage(named: "input_attachment_confide_select"), for: .selected)
        confideButton.addTarget(self, action: #selector(didTapConfide), for: .touchUpInside)

        lengthLimitLabel.textColor = .white
        lengthLimitLabel.text = Localized("ATTACHMENT_APPROVAL_CAPTION_LENGTH_LIMIT_REACHED", comment: "One line label indicating the user can add no more text to the attachment caption.")
        lengthLimitLabel.textAlignment = .center
        lengthLimitLabel.layer.shadowColor = UIColor.black.cgColor
        lengthLimitLabel.layer.shadowOffset = CGSize(width: 0.0, height: 0.0)
        lengthLimitLabel.layer.shadowOpacity = 0.8
        self.lengthLimitLabel.isHidden = true

        // inputContainer: textView + confideButton share the same background/border
        let inputContainer = UIView()
        inputContainer.backgroundColor = UIColor(rgbHex: 0x1E2329)
        inputContainer.layer.cornerRadius = 5
        inputContainer.addBorder(with: UIColor.ows_black.withAlphaComponent(0.12))
        inputContainer.addSubview(textView)
        inputContainer.addSubview(confideButton)

        backgroundView.backgroundColor = UIColor(rgbHex: 0x181A20)
        addSubview(backgroundView)
        backgroundView.autoPinEdgesToSuperviewEdges()

        topSepLine.setDashed(false, color: Theme.bg2Color)
        addSubview(topSepLine)
        topSepLine.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        topSepLine.autoSetDimension(.height, toSize: 0.5)

        backgroundView.addSubview(inputContainer)
        backgroundView.addSubview(sendButton)
        backgroundView.addSubview(lengthLimitLabel)

        let kMargin: CGFloat = 8
        let kButtonSize: CGFloat = 36

        backgroundView.layoutMargins = UIEdgeInsets(top: kMargin, left: kMargin, bottom: kMargin, right: kMargin)

        // inputContainer: left-aligned, stretches to fill space left of sendButton
        inputContainer.autoPinEdge(toSuperviewMargin: .top)
        inputContainer.autoPinEdge(toSuperviewMargin: .left)
        inputContainer.autoPinEdge(toSuperviewMargin: .bottom)
        inputContainer.autoPinEdge(.right, to: .left, of: sendButton, withOffset: -kMargin)

        // textView fills the container, leaving room for confideButton on the right
        self.textViewHeightConstraint = textView.autoSetDimension(.height, toSize: kMinTextViewHeight)
        textView.autoPinEdge(toSuperviewEdge: .top)
        textView.autoPinEdge(toSuperviewEdge: .left)
        textView.autoPinEdge(toSuperviewEdge: .bottom)
        textView.autoPinEdge(.right, to: .left, of: confideButton)

        // confideButton pinned to right edge of container, vertically centered
        confideButton.autoPinEdge(toSuperviewEdge: .right)
        confideButton.autoAlignAxis(toSuperviewAxis: .horizontal)
        confideButton.autoSetDimensions(to: CGSize(width: kButtonSize, height: kButtonSize))

        // sendButton: fixed to the right margin, bottom-aligned with inputContainer
        sendButton.autoPinEdge(toSuperviewMargin: .right)
        sendButton.autoPinEdge(.bottom, to: .bottom, of: inputContainer)
        sendButton.autoSetDimensions(to: CGSize(width: kButtonSize, height: kButtonSize))

        lengthLimitLabel.autoPinEdge(toSuperviewMargin: .left)
        lengthLimitLabel.autoPinEdge(toSuperviewMargin: .right)
        lengthLimitLabel.autoPinEdge(.bottom, to: .top, of: inputContainer, withOffset: -6)
        lengthLimitLabel.setContentHuggingHigh()
        lengthLimitLabel.setCompressionResistanceHigh()

        updatePlaceholder()
    }

    @objc func didTapSend() {
        self.captioningToolbarDelegate?.captioningToolbarDidTapSend(self, captionText: self.textView.text)
    }

    func dismissKeyboard() {
        textView.resignFirstResponder()
    }

    @objc func didTapConfide() {
        self.captioningToolbarDelegate?.captioningToolbarDidTapConfide(self)
    }

    // MARK: - UITextViewDelegate

    public func textViewDidChange(_ textView: UITextView) {
        updateHeight(textView: textView)
        
        updatePlaceholder()
    }
    
    func updatePlaceholder() {
        
        placeholderLabel.isHidden = !textView.text.isEmpty
        
        guard let beginTextRange = textView.textRange(from: textView.beginningOfDocument, to: textView.beginningOfDocument) else {
            return
        }
        
        let textContainerInset = textView.textContainerInset
        let lineFragmentPadding = textView.textContainer.lineFragmentPadding

        let leftInset = textContainerInset.left + lineFragmentPadding;
        let topInset = textContainerInset.top;
        
        let beginTextRect = textView.firstRect(for: beginTextRange)
        placeholderLabel.snp.remakeConstraints { make in
            make.top.equalToSuperview().offset(topInset)
            make.leading.equalToSuperview().offset(leftInset)
        }
    }

    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {

        let existingText: String = textView.text ?? ""
        let proposedText: String = (existingText as NSString).replacingCharacters(in: range, with: text)

        guard proposedText.utf8.count <= kOversizeTextMessageSizeThreshold else {
            Logger.debug("\(self.logTag) in \(#function) long text was truncated")
            self.lengthLimitLabel.isHidden = false

            // `range` represents the section of the existing text we will replace. We can re-use that space.
            // Range is in units of NSStrings's standard UTF-16 characters. Since some of those chars could be
            // represented as single bytes in utf-8, while others may be 8 or more, the only way to be sure is
            // to just measure the utf8 encoded bytes of the replaced substring.
            let bytesAfterDelete: Int = (existingText as NSString).replacingCharacters(in: range, with: "").utf8.count

            // Accept as much of the input as we can
            let byteBudget: Int = Int(kOversizeTextMessageSizeThreshold) - bytesAfterDelete
            if byteBudget >= 0, let acceptableNewText = text.truncated(toByteCount: UInt(byteBudget)) {
                textView.text = (existingText as NSString).replacingCharacters(in: range, with: acceptableNewText)
            }

            return false
        }
        self.lengthLimitLabel.isHidden = true

        // Though we can wrap the text, we don't want to encourage multline captions, plus a "done" button
        // allows the user to get the keyboard out of the way while in the attachment approval view.
//        if text == "\n" {
//            textView.resignFirstResponder()
//            return false
//        } else {
            return true
//        }
    }

    public func textViewDidBeginEditing(_ textView: UITextView) {
        self.captioningToolbarDelegate?.captioningToolbarDidBeginEditing(self)
    }

    public func textViewDidEndEditing(_ textView: UITextView) {
        self.captioningToolbarDelegate?.captioningToolbarDidEndEditing(self)
    }

    // MARK: - Helpers

    private func updateHeight(textView: UITextView) {
        // compute new height assuming width is unchanged
        let currentSize = textView.frame.size
        let newHeight = clampedTextViewHeight(fixedWidth: currentSize.width)
        if newHeight != self.textViewHeight {
            Logger.debug("\(self.logTag) TextView height changed: \(self.textViewHeight) -> \(newHeight)")
            self.textViewHeight = newHeight
            self.textViewHeightConstraint?.constant = textViewHeight
            self.invalidateIntrinsicContentSize()
        }
    }

    private func clampedTextViewHeight(fixedWidth: CGFloat) -> CGFloat {
        let contentSize = textView.sizeThatFits(CGSize(width: fixedWidth, height: CGFloat.greatestFiniteMagnitude))
        return CGFloatClamp(contentSize.height, kMinTextViewHeight, maxTextViewHeight)
    }
}

extension AttachmentApprovalViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        self.attachments.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DFAttachmentApprovalCollectionCell.reuseIdentifier(), for: indexPath) as! DFAttachmentApprovalCollectionCell
        
//        cell.attachment = self.attachments[indexPath.item]
        
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        
        if let cell = cell as? DFAttachmentApprovalCollectionCell {
            cell.resetCellSubviews()
            cell.attachment = self.attachments[indexPath.item]
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if let cell = cell as? DFAttachmentApprovalCollectionCell {
            cell.resetVideo()
        }
    }
}

class DFAttachmentApprovalCollectionCell: UICollectionViewCell {
    
    let TAG = "[DFAttachmentApprovalCollectionCell]"
    
    private var _attachment: SignalAttachment?
    var attachment: SignalAttachment? {

        get {
            _attachment
        }

        set {
            _attachment = newValue
            guard let newValue = newValue else { return }
            self.mediaMessageView = MediaMessageView(attachment: newValue, mode: .attachmentApproval)
            if let mediaMessageView = mediaMessageView {
                containerView?.addSubview(mediaMessageView)
                mediaMessageView.autoPinEdgesToSuperviewEdges()
            }

            if attachment == nil {
                return
            }
            if newValue.isVideo {

                guard let attachment = attachment, let videoURL = attachment.dataUrl else {
                    owsFailDebug("Missing videoURL")
                    return
                }

                let player = OWSVideoPlayer(url: videoURL)
                self.videoPlayer = player
                player.delegate = self

                let playerView = VideoPlayerView()
                playerView.player = player.avPlayer
                self.mediaMessageView?.addSubview(playerView)
                playerView.autoPinEdgesToSuperviewEdges()

                let pauseGesture = UITapGestureRecognizer(target: self, action: #selector(didTapPlayerView(_:)))
                playerView.addGestureRecognizer(pauseGesture)

                let progressBar = PlayerProgressBar()
                progressBar.player = player.avPlayer
                progressBar.delegate = self

                // we don't want the progress bar to zoom during "pinch-to-zoom"
                // but we do want it to shrink with the media content when the user
                // pops the keyboard.
                contentView.addSubview(progressBar)

                progressBar.autoPinTopToSuperviewMargin(withInset: 60)
                progressBar.autoPinWidthToSuperview()
                progressBar.autoSetDimension(.height, toSize: 44)

                self.mediaMessageView?.videoPlayButton?.isHidden = true
                let playButton = UIButton()
                self.playVideoButton = playButton
                playButton.accessibilityLabel = Localized("PLAY_BUTTON_ACCESSABILITY_LABEL", comment: "Accessibility label for button to start media playback")
                playButton.setBackgroundImage(#imageLiteral(resourceName: "play_button"), for: .normal)
                playButton.contentMode = .scaleAspectFit

                let playButtonWidth = ScaleFromIPhone5(70)
                playButton.autoSetDimensions(to: CGSize(width: playButtonWidth, height: playButtonWidth))
                contentView.addSubview(playButton)

                playButton.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
                playButton.autoCenterInSuperview()
            }
        }
    }

    private var videoPlayer: OWSVideoPlayer?

    private(set) var mediaMessageView: MediaMessageView?
    private(set) var scrollView: UIScrollView?
    private(set) var containerView: UIView?
    private(set) var playVideoButton: UIView?

    override init(frame: CGRect) {

        super.init(frame: frame)

        // Scroll View - used to zoom/pan on images and video
        let scroll = UIScrollView()
        scrollView = scroll
        contentView.addSubview(scroll)
        scroll.delegate = self
        scroll.isScrollEnabled = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        // Panning should stop pretty soon after the user stops scrolling
        scroll.decelerationRate = UIScrollView.DecelerationRate.fast
        scroll.autoPinEdgesToSuperviewEdges()


        // Create full screen container view so the scrollView
        // can compute an appropriate content size in which to center
        // our media view.
        let container = UIView.container()
        containerView = container
        scroll.addSubview(container)
        container.autoPinEdgesToSuperviewEdges()
        container.autoMatch(.height, to: .height, of: contentView)
        container.autoMatch(.width, to: .width, of: contentView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    class func reuseIdentifier() -> String {
        "DFAttachmentApprovalCollectionCell"
    }

    func resetVideo() {
        guard let attachment = attachment, attachment.isVideo else { return }
        let scale: CMTimeScale = 100
        videoPlayer?.stop()
        videoPlayer?.seek(to: CMTime(value: 0, timescale: scale))
    }
        
    func resetCellSubviews() {
        
        for subview in contentView.subviews {
            if subview.isKind(of: UIButton.self) || subview.isKind(of: PlayerProgressBar.self) {
                subview.removeFromSuperview()
            }
        }
        
        if let containerView = containerView {
            for subview in containerView.subviews {
                subview.removeFromSuperview()
            }
        }

    }

    var isZoomable: Bool {
        guard let attachment = attachment else {
            return false
        }

        return attachment.isImage || attachment.isVideo
    }
    
    @objc public func didTapPlayerView(_ gestureRecognizer: UIGestureRecognizer) {
        assert(self.videoPlayer != nil)
        self.pauseVideo()
    }
    
    // MARK: Video
    
    @objc
    public func playButtonTapped() {
        self.playVideo()
    }

    private func playVideo() {
        Logger.info("\(TAG) in \(#function)")

        guard let videoPlayer = self.videoPlayer else {
            owsFailDebug("\(TAG) video player was unexpectedly nil")
            return
        }

        guard let playVideoButton = self.playVideoButton else {
            owsFailDebug("\(TAG) playVideoButton was unexpectedly nil")
            return
        }
        UIView.animate(withDuration: 0.1) {
            playVideoButton.alpha = 0.0
        }
        videoPlayer.play()
    }

    private func pauseVideo() {
        guard let videoPlayer = self.videoPlayer else {
            owsFailDebug("\(TAG) video player was unexpectedly nil")
            return
        }

        videoPlayer.pause()
        guard let playVideoButton = self.playVideoButton else {
            owsFailDebug("\(TAG) playVideoButton was unexpectedly nil")
            return
        }
        UIView.animate(withDuration: 0.1) {
            playVideoButton.alpha = 1.0
        }
    }

}

extension DFAttachmentApprovalCollectionCell: UIScrollViewDelegate {
    
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        if isZoomable {
            return mediaMessageView
        } else {
            // don't zoom for audio or generic attachments.
            return nil
        }
    }

    // Keep the media view centered within the scroll view as you zoom
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // The scroll view has zoomed, so you need to re-center the contents
        let scrollViewSize = self.scrollViewVisibleSize

        // First assume that mediaMessageView center coincides with the contents center
        // This is correct when the mediaMessageView is bigger than scrollView due to zoom
        var contentCenter = CGPoint(x: (scrollView.contentSize.width / 2), y: (scrollView.contentSize.height / 2))

        let scrollViewCenter = self.scrollViewCenter

        // if mediaMessageView is smaller than the scrollView visible size - fix the content center accordingly
        if self.scrollView?.contentSize.width ?? 0 < scrollViewSize.width {
            contentCenter.x = scrollViewCenter.x
        }

        if self.scrollView?.contentSize.height ?? 0 < scrollViewSize.height {
            contentCenter.y = scrollViewCenter.y
        }

        self.mediaMessageView?.center = contentCenter
    }

    // return the scroll view center
    private var scrollViewCenter: CGPoint {
        let size = scrollViewVisibleSize
        return CGPoint(x: (size.width / 2), y: (size.height / 2))
    }

    // Return scrollview size without the area overlapping with tab and nav bar.
    private var scrollViewVisibleSize: CGSize {
        guard let scrollView = scrollView else { return .zero }
        let contentInset = scrollView.contentInset
        let scrollViewSize = scrollView.bounds.standardized.size
        let width = scrollViewSize.width - (contentInset.left + contentInset.right)
        let height = scrollViewSize.height - (contentInset.top + contentInset.bottom)
        return CGSize(width: width, height: height)
    }

}

extension DFAttachmentApprovalCollectionCell: PlayerProgressBarDelegate, OWSVideoPlayerDelegate {
    
    @objc
    public func videoPlayerDidPlayToCompletion(_ videoPlayer: OWSVideoPlayer) {
        guard let playVideoButton = self.playVideoButton else {
            owsFailDebug("\(TAG) playVideoButton was unexpectedly nil")
            return
        }

        UIView.animate(withDuration: 0.1) {
            playVideoButton.alpha = 1.0
        }
    }

    public func playerProgressBarDidStartScrubbing(_ playerProgressBar: PlayerProgressBar) {
        guard let videoPlayer = self.videoPlayer else {
            owsFailDebug("\(TAG) video player was unexpectedly nil")
            return
        }
        videoPlayer.pause()
    }

    public func playerProgressBar(_ playerProgressBar: PlayerProgressBar, scrubbedToTime time: CMTime) {
        guard let videoPlayer = self.videoPlayer else {
            owsFailDebug("\(TAG) video player was unexpectedly nil")
            return
        }

        videoPlayer.seek(to: time)
    }

    public func playerProgressBar(_ playerProgressBar: PlayerProgressBar, didFinishScrubbingAtTime time: CMTime, shouldResumePlayback: Bool) {
        guard let videoPlayer = self.videoPlayer else {
            owsFailDebug("\(TAG) video player was unexpectedly nil")
            return
        }

        videoPlayer.seek(to: time)
        if (shouldResumePlayback) {
            videoPlayer.play()
        }
    }

}

// MARK: - CaptioningDashedLineView

private class CaptioningDashedLineView: UIView {
    private let dashLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(dashLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setDashed(_ dashed: Bool, color: UIColor) {
        backgroundColor = dashed ? .clear : color
        dashLayer.isHidden = !dashed
        if dashed {
            dashLayer.strokeColor = color.cgColor
            dashLayer.fillColor = UIColor.clear.cgColor
            dashLayer.lineWidth = 0.5
            dashLayer.lineDashPattern = [4, 4]
            setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !dashLayer.isHidden else { return }
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: bounds.midY))
        path.addLine(to: CGPoint(x: bounds.width, y: bounds.midY))
        dashLayer.path = path.cgPath
        dashLayer.frame = bounds
    }
}
