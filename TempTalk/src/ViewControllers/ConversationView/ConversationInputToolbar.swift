//
// Copyright 2022 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import TTServiceKit

@objc protocol ConversationInputToolbarDelegate: AnyObject {

    func sendButtonPressed()

    func updateToolbarHeight()

    func isBlockedConversation() -> Bool

    func isGroup() -> Bool

    // MARK: mention
    
    func atIsActive(location: UInt)
    
    // MARK: Voice Memo

    func voiceMemoGestureDidStart()

    func voiceMemoGestureDidComplete()

    func voiceMemoGestureDidCancel()

    func voiceMemoGestureWasInterrupted()

    // MARK: Attachments
    
    func photosButtonPressed()

    func cameraButtonPressed()

    func voiceCallButtonPressed()
    
    func videoCallButtonPressed()
    
    func contactButtonPressed()

    func fileButtonPressed()
    
    func confideButtonPressed()
    
    func mentionButtonPressed()
    
    func expandButtonPressed(_ inputToolbar: ConversationInputToolbar)
    
}

@objc public enum InputToolbarState: Int {
    case normal
    case confidential
}

@objc public enum InputToolbarRelationship: Int {
    case normal
    case notFriend
    case bot
    case notetoself
}

@objc public enum InputToolbarThreadType: Int {
    case contact
    case group
}

@objc public class ConversationInputToolbar: UIView, DTInputReplyPreviewDelegate {
    
    public override class func logTag() -> String {
        "[inpoutbar][keyboard]"
    }
    
    @objc lazy var atCache: DTInputAtCache = {
        DTInputAtCache()
    }()

    private var conversationStyle: ConversationStyle
    
    @objc var inputToolbarState: InputToolbarState {
        didSet {
            guard oldValue != inputToolbarState else { return }
//            attachmentKeyboardIfLoaded?.inputToolbarState = inputToolbarState
            ensureButtonVisibility(withAnimation: true, doLayout: true)
        }
    }
    
    @objc var relationship: InputToolbarRelationship {
        didSet {
            guard oldValue != relationship else { return }
            attachmentKeyboardIfLoaded?.inputToolbarState = inputToolbarState
            ensureButtonVisibility(withAnimation: true, doLayout: true)
        }
    }
    
    var threadType: InputToolbarThreadType

    private weak var inputToolbarDelegate: ConversationInputToolbarDelegate?

    @objc init(
        conversationStyle: ConversationStyle,
        messageDraft: String?,
        quotedReplyDraft: OWSQuotedReplyModel?,
        inputToolbarDelegate: ConversationInputToolbarDelegate,
        inputTextViewDelegate: ConversationInputTextViewDelegate,
        inputToolbarState: InputToolbarState,
        relationship: InputToolbarRelationship,
        threadType: InputToolbarThreadType
    ) {
        self.conversationStyle = conversationStyle
        self.inputToolbarDelegate = inputToolbarDelegate
        self.inputToolbarState = inputToolbarState
        self.relationship = relationship
        self.threadType = threadType
        
        super.init(frame: .zero)

        createContentsWithMessageDraft(
            messageDraft,
            quotedReplyDraft: quotedReplyDraft,
            inputTextViewDelegate: inputTextViewDelegate,
            inputToolbarState: inputToolbarState,
            relationship: relationship
        )
        
        recordingProcessor.delegate = self

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(notification:)),
            name: .OWSApplicationDidBecomeActive,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardFrameDidChange(notification:)),
            name: UIResponder.keyboardDidChangeFrameNotification,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Layout
    
    public override var intrinsicContentSize: CGSize {
        // Since we have `self.autoresizingMask = UIViewAutoresizingFlexibleHeight`, we must specify
        // an intrinsicContentSize. Specifying CGSize.zero causes the height to be determined by autolayout.
        .zero
    }

    public override var frame: CGRect {
        didSet {
            guard oldValue.size.height != frame.size.height else { return }

            inputToolbarDelegate?.updateToolbarHeight()
        }
    }

    public override var bounds: CGRect {
        didSet {
            guard abs(oldValue.size.height - bounds.size.height) > 1 else { return }

            // Compensate for autolayout frame/bounds changes when animating in/out the quoted reply view.
            // This logic ensures the input toolbar stays pinned to the keyboard visually
            if isAnimatingHeightChange && inputTextView.isFirstResponder {
                var frame = frame
                frame.origin.y = 0
                // In this conditional, bounds change is captured in an animation block, which we don't want here.
                UIView.performWithoutAnimation {
                    self.frame = frame
                }
            }

            inputToolbarDelegate?.updateToolbarHeight()
        }
    }

    func update(conversationStyle: ConversationStyle) {
        AssertIsOnMainThread()
        self.conversationStyle = conversationStyle
    }

    private var receivedSafeAreaInsets = UIEdgeInsets.zero

    private enum LayoutMetrics {
        static let minTextViewHeight: CGFloat = 40
        static let maxTextViewHeight: CGFloat = 118
        static let maxIPadTextViewHeight: CGFloat = 142
        static let minToolbarItemHeight: CGFloat = 52
    }
    
    private lazy var expandButton: UIButton = {
        let button = UIButton(type: .custom)
        button.tintColor = Theme.primaryIconColor
        button.addTarget(self, action: #selector(expandButtonPressed), for: .touchUpInside)
        button.setImage(UIImage(named: "input_expand"), for: .normal)
        button.autoSetDimensions(to: CGSize(square: LayoutMetrics.minToolbarItemHeight))
        return button
    }()
    
    private lazy var addOrCancelButton: AddOrCancelButton = {
        let button = AddOrCancelButton()
        button.accessibilityLabel = OWSLocalizedString(
            "ATTACHMENT_LABEL",
            comment: "Accessibility label for attaching photos"
        )
        button.accessibilityHint = OWSLocalizedString(
            "ATTACHMENT_HINT",
            comment: "Accessibility hint describing what you can do with the attachment button"
        )
        button.accessibilityIdentifier = UIView.accessibilityIdentifier(in: self, name: "attachmentButton")
        button.addTarget(self, action: #selector(addOrCancelButtonPressed), for: .touchUpInside)
        button.setContentHuggingHorizontalHigh()
        button.setCompressionResistanceHorizontalHigh()
        return button
    }()

    public lazy var inputTextView: ConversationInputTextView = {
        let inputTextView = ConversationInputTextView()
        inputTextView.textViewToolbarDelegate = self
        inputTextView.font = .preferredFont(forTextStyle: .body)
        inputTextView.setContentHuggingHigh()
        inputTextView.setCompressionResistanceHigh()
        inputTextView.accessibilityIdentifier = UIView.accessibilityIdentifier(in: self, name: "inputTextView")
        return inputTextView
    }()
    
    private lazy var confideButton: UIButton = {
        let button = UIButton(type: .custom)
        button.tintColor = Theme.primaryIconColor
        button.accessibilityLabel = OWSLocalizedString(
            "INPUT_TOOLBAR_CONFIDE_BUTTON_ACCESSIBILITY_LABEL",
            comment: "accessibility label for the button which switch input mode to confide"
        )
        button.accessibilityIdentifier = UIView.accessibilityIdentifier(in: self, name: "confideButton")
        button.addTarget(self, action: #selector(confideButtonPressed), for: .touchUpInside)
        button.setImage(UIImage(named: "input_attachment_confide"), for: .normal)
        button.setImage(UIImage(named: "input_attachment_confide_select"), for: .selected)
        button.autoSetDimensions(to: CGSize(square: LayoutMetrics.minToolbarItemHeight))
                    
        return button
    }()
    
    private lazy var voiceMemoView: VoiceMemoView = {
        let voiceMemoView = VoiceMemoView()
                    
        // We want to be permissive about the voice message gesture, so we hang
        // the long press GR on the button's wrapper, not the button itself.
        let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleVoiceMemoLongPress(gesture:)))
        longPressGestureRecognizer.minimumPressDuration = 0
        voiceMemoView.addGestureRecognizer(longPressGestureRecognizer)
        return voiceMemoView
    }()

    private lazy var quotedReplyWrapper: UIView = {
        let view = UIView.container()
        view.setContentHuggingHorizontalLow()
        view.setCompressionResistanceHorizontalLow()
        view.accessibilityIdentifier = UIView.accessibilityIdentifier(in: self, name: "quotedReplyWrapper")
        return view
    }()

    private lazy var rightEdgeControlsView: RightEdgeControlsView = {
        let view = RightEdgeControlsView()
        view.voiceButton.addTarget(self, action: #selector(voiceButtonPressed), for: .touchUpInside)
        view.keyboardButton.addTarget(self, action: #selector(keyboardButtonPressed), for: .touchUpInside)
        view.sendButton.addTarget(self, action: #selector(sendButtonPressed), for: .touchUpInside)
        
        return view
    }()

    private let messageContentView = UIView.container()
    
    private let vStackRoundingView = UIView.container()
    
    private var msgContentRConstraint: NSLayoutConstraint?
    
    private var lastNumberOflines = 0
    
    private let mainPanelView: UIView = {
        let view = UIView()
        // TODO: keyboard for tool duplicate
        view.layoutMargins = UIEdgeInsets(hMargin: (UIDevice.current.isPlusSizePhone ? 20 : 16) - 16, vMargin: 0)
        return view
    }()

    private let mainPanelWrapperView = UIView.container()
    
    private let topSepLine = UIView()

    private var isConfigurationComplete = false

    private var textViewHeight: CGFloat = 0
    private var textViewHeightConstraint: NSLayoutConstraint?
    class var heightChangeAnimationDuration: TimeInterval { 0.25 }
    private(set) var isAnimatingHeightChange = false

    private var layoutConstraints: [NSLayoutConstraint]?

    private func createContentsWithMessageDraft(
        _ messageDraft: String?,
        quotedReplyDraft: OWSQuotedReplyModel?,
        inputTextViewDelegate: ConversationInputTextViewDelegate,
        inputToolbarState: InputToolbarState,
        relationship: InputToolbarRelationship
    ) {
        // The input toolbar should *always* be laid out left-to-right, even when using
        // a right-to-left language. The convention for messaging apps is for the send
        // button to always be to the right of the input field, even in RTL layouts.
        // This means, in most places you'll want to pin deliberately to left/right
        // instead of leading/trailing. You'll also want to the semanticContentAttribute
        // to ensure horizontal stack views layout left-to-right.

        layoutMargins = .zero
        autoresizingMask = .flexibleHeight
        isUserInteractionEnabled = true

        // NOTE: Don't set inputTextViewDelegate until configuration is complete.
        inputTextView.inputTextViewDelegate = inputTextViewDelegate

        textViewHeightConstraint = inputTextView.autoSetDimension(.height, toSize: LayoutMetrics.minTextViewHeight)

        quotedReplyWrapper.isHidden = quotedReplyDraft == nil
        self.quotedReplyDraft = quotedReplyDraft

        // Vertical stack of message component views in the center: Link Preview, Reply Quote, Text Input View.
        let messageContentVStack = UIStackView(arrangedSubviews: [
            quotedReplyWrapper,
            inputTextView
        ])
        messageContentVStack.axis = .vertical
        messageContentVStack.alignment = .fill
        messageContentVStack.setContentHuggingHorizontalLow()
        messageContentVStack.setCompressionResistanceHorizontalLow()

        // Wrap vertical stack into a view with rounded corners.
        vStackRoundingView.backgroundColor = Theme.stickBackgroundColor
        vStackRoundingView.layer.cornerRadius = 8
        vStackRoundingView.clipsToBounds = true
        
        mainPanelView.addSubview(expandButton)
        expandButton.autoPinEdge(toSuperviewMargin: .left)
        expandButton.autoPinEdge(toSuperviewEdge: .top)
        expandButton.isHidden = false
        
        vStackRoundingView.addSubview(messageContentVStack)
        messageContentVStack.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .right)
        msgContentRConstraint = messageContentVStack.autoPinEdge(toSuperviewMargin: .right, withInset: 52)
        
        setupConfideButtonLayout(showExpand: false)
        
        
        // Voice Message UI is added to the same vertical stack, but not as arranged subview.
        // The view is constrained to text input view's edges.
        vStackRoundingView.addSubview(voiceMemoView)
        voiceMemoView.autoPinEdges(toEdgesOf: vStackRoundingView)
        
        messageContentView.addSubview(vStackRoundingView)
        // This margin defines amount of padding above and below visible text input box.
        let textViewVInset = 0.5 * (LayoutMetrics.minToolbarItemHeight - LayoutMetrics.minTextViewHeight)
        vStackRoundingView.autoPinWidthToSuperview()
        vStackRoundingView.autoPinHeightToSuperview(withMargin: textViewVInset)
        

        // Horizontal Stack: Attachment button, message components, Camera|VoiceNote|Send button.
        //
        // + Attachment button: pinned to the bottom left corner.
        mainPanelView.addSubview(addOrCancelButton)
        addOrCancelButton.autoPinEdge(toSuperviewMargin: .left)
        addOrCancelButton.autoPinEdge(toSuperviewEdge: .bottom)
        let isFriend = InputToolbarRelationship.notFriend != relationship
        let addOrCancelButtonSize = isFriend ? CGSize(square: LayoutMetrics.minToolbarItemHeight) : CGSizeMake(12, CGFLOAT_MIN)
        addOrCancelButton.autoSetDimensions(to: addOrCancelButtonSize)

        // Voice Message | Keyboard | Send: pinned to the bottom right corner.
        mainPanelView.addSubview(rightEdgeControlsView)
        rightEdgeControlsView.autoPinEdge(toSuperviewMargin: .right)
        rightEdgeControlsView.autoPinEdge(toSuperviewEdge: .bottom)

        // Message components view: pinned to attachment button on the left, Camera button on the right,
        // taking entire superview's height.
        mainPanelView.addSubview(messageContentView)
        messageContentView.autoPinHeightToSuperview()
        messageContentView.autoPinEdge(.right, to: .left, of: rightEdgeControlsView)
        messageContentView.autoPinEdge(.left, to: .right, of: addOrCancelButton)

        // Put main panel view into a wrapper view that would also contain background view.
        mainPanelWrapperView.addSubview(mainPanelView)
        mainPanelView.autoPinEdgesToSuperviewEdges()

        let outerVStack = UIStackView(arrangedSubviews: [ mainPanelWrapperView ] )
        outerVStack.axis = .vertical
        addSubview(outerVStack)
        outerVStack.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        outerVStack.autoPinEdge(toSuperviewSafeArea: .bottom)

        // When presenting or dismissing the keyboard, there may be a slight
        // gap between the keyboard and the bottom of the input bar during
        // the animation. Extend the background below the toolbar's bounds
        // by this much to mask that extra space.
        let backgroundExtension: CGFloat = 500
        let extendedBackgroundView = UIView()
        if UIAccessibility.isReduceTransparencyEnabled {
            extendedBackgroundView.backgroundColor = Theme.toolbarBackgroundColor
        } else {
            extendedBackgroundView.backgroundColor = Theme.toolbarBackgroundColor.withAlphaComponent(OWSNavigationBar.backgroundBlurMutingFactor)

            let blurEffectView = UIVisualEffectView(effect: Theme.barBlurEffect)
            // Alter the visual effect view's tint to match our background color
            // so the input bar, when over a solid color background matching `toolbarBackgroundColor`,
            // exactly matches the background color. This is brittle, but there is no way to get
            // this behavior from UIVisualEffectView otherwise.
            if let tintingView = blurEffectView.subviews.first(where: {
                String(describing: type(of: $0)) == "_UIVisualEffectSubview"
            }) {
                tintingView.backgroundColor = extendedBackgroundView.backgroundColor
            }
            extendedBackgroundView.addSubview(blurEffectView)
            blurEffectView.autoPinEdgesToSuperviewEdges()
        }
        mainPanelWrapperView.insertSubview(extendedBackgroundView, at: 0)
        extendedBackgroundView.autoPinWidthToSuperview()
        extendedBackgroundView.autoPinEdge(toSuperviewEdge: .top)
        extendedBackgroundView.autoPinEdge(toSuperviewEdge: .bottom, withInset: -backgroundExtension)

        //
        topSepLine.backgroundColor = .confidential == inputToolbarState ? .ows_themeBlue : Theme.stickBackgroundColor
        addSubview(topSepLine)
        topSepLine.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        topSepLine.autoSetDimension(.height, toSize: 0.5)
        let bottomSepLine = UIView()
        bottomSepLine.backgroundColor = Theme.stickBackgroundColor
        addSubview(bottomSepLine)
        bottomSepLine.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        bottomSepLine.autoSetDimension(.height, toSize: 0.5)
        
        
        // See comments on updateLayout(withSafeAreaInsets:).
        messageContentVStack.insetsLayoutMarginsFromSafeArea = false
        messageContentView.insetsLayoutMarginsFromSafeArea = false
        mainPanelWrapperView.insetsLayoutMarginsFromSafeArea = false
        outerVStack.insetsLayoutMarginsFromSafeArea = false
        insetsLayoutMarginsFromSafeArea = false

        messageContentVStack.preservesSuperviewLayoutMargins = false
        messageContentView.preservesSuperviewLayoutMargins = false
        mainPanelWrapperView.preservesSuperviewLayoutMargins = false
        preservesSuperviewLayoutMargins = false

        setMessageBody(messageDraft, animated: false, doLayout: false)

        isConfigurationComplete = true
    }
    
    func setupConfideButtonLayout(showExpand: Bool) {
                
        confideButton.removeFromSuperview()
        
        if showExpand {
            mainPanelView.addSubview(confideButton)
            confideButton.autoAlignAxis(.vertical, toSameAxisOf: rightEdgeControlsView.sendButton)
            confideButton.autoPinEdge(toSuperviewEdge: .top)
            confideButton.autoSetDimensions(to: CGSize(width: LayoutMetrics.minTextViewHeight, height: LayoutMetrics.minTextViewHeight))
            
            msgContentRConstraint?.constant = -6
            
        } else {
            vStackRoundingView.addSubview(confideButton)
            confideButton.autoPinEdge(toSuperviewEdge: .right)
            confideButton.autoPinEdge(toSuperviewEdge: .bottom)
            confideButton.autoSetDimensions(to: CGSize(width: LayoutMetrics.minTextViewHeight, height: LayoutMetrics.minTextViewHeight))
            
            msgContentRConstraint?.constant = -28
            
        }
    }

    @discardableResult
    class func setView(_ view: UIView, hidden isHidden: Bool, usingAnimator animator: UIViewPropertyAnimator?) -> Bool {
        let viewAlpha: CGFloat = isHidden ? 0 : 1

        guard viewAlpha != view.alpha else { return false }

        let viewUpdateBlock = {
            view.alpha = viewAlpha
            view.transform = isHidden ? .scale(0.1) : .identity
        }
        if let animator {
            animator.addAnimations(viewUpdateBlock)
        } else {
            viewUpdateBlock()
        }
        return true
    }

    private func ensureButtonVisibility(withAnimation isAnimated: Bool, doLayout: Bool) {

        var hasLayoutChanged = false
        var rightEdgeControlsState = rightEdgeControlsView.state

        if .voice != rightEdgeControlsState {
            
            let hasNonWhitespaceTextInput = !inputTextView.trimmedText().isEmpty
            
            if InputToolbarRelationship.notFriend == relationship {
                rightEdgeControlsState = hasNonWhitespaceTextInput ? .sendButton : .unavailable
            } else {
                rightEdgeControlsState = hasNonWhitespaceTextInput ? .sendButton : .keyboard
            }
        } else {
            // 转换为 attachment 键盘时 inputbar 还原为 keyboad 状态
            if .attachment == desiredKeyboardType {
                rightEdgeControlsState = .keyboard
            }
        }
        
        let isConfidentialMode = .confidential == inputToolbarState
        let placeholderText: String = isConfidentialMode ? OWSLocalizedString("Confidential_message", comment: "") : OWSLocalizedString("new_message", comment: "")
        if inputTextView.text.count == 0 {
            inputTextView.placeholder = placeholderText
        }
        confideButton.isSelected = isConfidentialMode
        topSepLine.backgroundColor = isConfidentialMode ? .ows_themeBlue : Theme.stickBackgroundColor

        let animator: UIViewPropertyAnimator?
        if isAnimated {
            animator = UIViewPropertyAnimator(duration: 0.25, springDamping: 0.645, springResponse: 0.25)
        } else {
            animator = nil
        }
        
        var memoGestureState = voiceMemoView.gestureState
        if .recording == voiceMemoRecordingState {
            memoGestureState = true == inCancleRecordCircle ? .releaseToCancel : .releaseToSend
        } else {
            memoGestureState = .holdToTalk
        }
        voiceMemoView.setGestureState(memoGestureState, usingAnimator: animator)

        // Attachment button has more complex animations and cannot be grouped with the rest.
        let addOrCancelButtonAppearance: AddOrCancelButton.Appearance = {
            return desiredKeyboardType == .attachment ? .close : .add
        }()
        addOrCancelButton.setAppearance(addOrCancelButtonAppearance, usingAnimator: animator)
        let isFriend = InputToolbarRelationship.notFriend != relationship
        let addOrCancelButtonSize = isFriend ? CGSize(square: LayoutMetrics.minToolbarItemHeight) : CGSizeMake(12, CGFLOAT_MIN)
        addOrCancelButton.autoSetDimensions(to: addOrCancelButtonSize)
        addOrCancelButton.isHidden = !isFriend

        // Hide text input field if Voice Message UI is presented or make it visible otherwise.
        // Do not change "isHidden" because that'll cause inputTextView to lose focus.
        let inputTextViewAlpha: CGFloat = rightEdgeControlsState == .voice ? 0 : 1
        let voiceMemoViewAlpha: CGFloat = 1 - inputTextViewAlpha
        if let animator {
            animator.addAnimations {
                self.inputTextView.alpha = inputTextViewAlpha
                self.confideButton.alpha = inputTextViewAlpha
                self.voiceMemoView.alpha = voiceMemoViewAlpha
            }
        } else {
            inputTextView.alpha = inputTextViewAlpha
            confideButton.alpha = inputTextViewAlpha
            voiceMemoView.alpha = voiceMemoViewAlpha
        }
        
        if rightEdgeControlsView.state != rightEdgeControlsState {
            hasLayoutChanged = true

            if let animator {
                // `state` in implicitly animatable.
                animator.addAnimations {
                    self.rightEdgeControlsView.state = rightEdgeControlsState
                }
            } else {
                rightEdgeControlsView.state = rightEdgeControlsState
            }
        }

        if let animator {
            if doLayout && hasLayoutChanged {
                animator.addAnimations {
                    self.mainPanelView.setNeedsLayout()
                    self.mainPanelView.layoutIfNeeded()
                }
            }

            animator.startAnimation()
        } else {
            if doLayout && hasLayoutChanged {
                self.mainPanelView.setNeedsLayout()
                self.mainPanelView.layoutIfNeeded()
            }
        }
    }

    func updateLayout(withSafeAreaInsets safeAreaInsets: UIEdgeInsets) -> Bool {
        let insetsChanged = receivedSafeAreaInsets != safeAreaInsets
        let needLayoutConstraints = layoutConstraints == nil
        guard insetsChanged || needLayoutConstraints else {
            return false
        }

        // iOS doesn't always update the safeAreaInsets correctly & in a timely
        // way for the inputAccessoryView after a orientation change.  The best
        // workaround appears to be to use the safeAreaInsets from
        // ConversationViewController's view.  ConversationViewController updates
        // this input toolbar using updateLayoutWithIsLandscape:.

        receivedSafeAreaInsets = safeAreaInsets
        return true
    }

    func scrollToBottom() {
        inputTextView.scrollToBottom()
    }

    @objc func updateFontSizes() {
        inputTextView.font = .ows_dynamicTypeBody
    }

    // MARK: hold to talk Button

    private class VoiceMemoView: UIView {

        enum GestureState {
            case holdToTalk
            case releaseToSend
            case releaseToCancel
        }
        
        private let waveView: WaveformView = {
            let view = WaveformView()
            view.backgroundColor = .clear
            view.autoSetDimensions(to: CGSizeMake(16, 16))
            view.isHidden = true
            return view
        }()

        private let tipLable: UILabel = {
            let tip = UILabel()
            tip.font = .systemFont(ofSize: 15)
            return tip
        }()

        private override init(frame: CGRect) {
            super.init(frame: frame)

            let containerStack = UIStackView()
            containerStack.axis = .horizontal
            containerStack.alignment = .center
            containerStack.distribution = .fill
            containerStack.spacing = 12
            
            containerStack.addArrangedSubviews([ waveView, tipLable ])
            
            addSubview(containerStack)
            containerStack.autoCenterInSuperview()
            updateImageColorAndBackground()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private var _gestureState: GestureState = .holdToTalk
        private var isAnimatingAppearance = false

        var gestureState: GestureState {
            get { _gestureState }
            set { setGestureState(newValue, usingAnimator: nil) }
        }

        func setGestureState(_ gestureState: GestureState, usingAnimator animator: UIViewPropertyAnimator?) {
            guard gestureState != _gestureState else { return }

            _gestureState = gestureState

            guard let animator else {
                updateImageColorAndBackground()
                return
            }

            isAnimatingAppearance = true
            animator.addAnimations({
                    self.updateImageColorAndBackground()
                },
                delayFactor: 0
            )
            animator.addCompletion { _ in
                self.isAnimatingAppearance = false
            }
        }

        private func updateImageColorAndBackground() {
            switch gestureState {
            case .holdToTalk:
                
                tipLable.textColor = ConversationStyle.bubbleTextColorIncoming
                tipLable.text = OWSLocalizedString("INPUTTOOL_VOICE_HOLD_TO_TALK", comment: "")
                
                waveView.stopAnimation()
                waveView.isHidden = true
                
                backgroundColor = Theme.hairlineColor
                
            case .releaseToSend:
                
                tipLable.textColor = .white
                tipLable.text = OWSLocalizedString("INPUTTOOL_VOICE_RELEASE_TO_SEND", comment: "")
                
                waveView.isHidden = false
                waveView.setBarColor(color: .white)
                waveView.startAnimation()
                
                backgroundColor = .ows_themeBlue
            case .releaseToCancel:
                
                tipLable.textColor = Theme.thirdTextAndIconColor
                tipLable.text = OWSLocalizedString("INPUTTOOL_VOICE_RELEASE_TO_SEND", comment: "")
                
                waveView.isHidden = false
                waveView.setBarColor(color: Theme.thirdTextAndIconColor)
//                waveView.stopAnimation()
//                waveView.startAnimation()
                
                backgroundColor = Theme.hairlineColor
                break
            }
        }
        
        func stopAnimation() {
            waveView.stopAnimation()
        }
    }
    
    // MARK: Right Edge Buttons

    private class RightEdgeControlsView: UIView {

        enum State {
            case voice // 语音 - mainPanel 为 Hold to talk Button
            case keyboard // mainPanel 为 inputTextView 键盘
            case sendButton // ⬆️
            case unavailable // 非好友, 默认全部隐藏
        }
        private var _state: State = .keyboard
        var state: State {
            get { _state }
            set {
                guard _state != newValue else { return }
                _state = newValue
                configureViewsForState(_state)
//                invalidateIntrinsicContentSize()
            }
        }

        lazy var voiceButton: UIButton = {
            let button = UIButton(type: .system)
            button.tintColor = Theme.primaryIconColor
            button.accessibilityLabel = OWSLocalizedString(
                "INPUT_TOOLBAR_VOICE_MEMO_BUTTON_ACCESSIBILITY_LABEL",
                comment: "accessibility label for the button which switch input mode to voice"
            )
            button.accessibilityHint = OWSLocalizedString(
                "INPUT_TOOLBAR_VOICE_MEMO_BUTTON_ACCESSIBILITY_HINT",
                comment: "accessibility hint for the button which switch input mode"
            )
            button.accessibilityIdentifier = UIView.accessibilityIdentifier(in: self, name: "voiceControlButton")
            button.setImage(UIImage(imageLiteralResourceName: "ic_inputbar_mic"), for: .normal)
            button.autoSetDimensions(to: CGSize(square: LayoutMetrics.minToolbarItemHeight))
                        
            return button
        }()
        
        lazy var keyboardButton: UIButton = {
            let button = UIButton(type: .system)
            button.tintColor = Theme.primaryIconColor
            button.accessibilityLabel = OWSLocalizedString(
                "INPUT_TOOLBAR_KEYBOARD_BUTTON_ACCESSIBILITY_LABEL",
                comment: "accessibility label for the button which shows the regular keyboard instead of sticker picker"
            )
            button.accessibilityIdentifier = UIView.accessibilityIdentifier(in: self, name: "keyboardButton")
            button.setImage(UIImage(named: "inputtoolbar_keyboard"), for: .normal)
            button.autoSetDimensions(to: CGSize(square: LayoutMetrics.minToolbarItemHeight))
            return button
        }()
        
        lazy var sendButton: UIButton = {
            let button = UIButton(type: .custom)
            button.accessibilityLabel = MessageStrings.sendButton()
            button.ows_adjustsImageWhenDisabled = true
            button.accessibilityIdentifier = UIView.accessibilityIdentifier(in: self, name: "sendButton")
            button.setImage(UIImage(named: "ic_inputbar_send"), for: .normal)
            button.bounds.size = CGSize(square: LayoutMetrics.minToolbarItemHeight)
            return button
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)

            for button in [ sendButton, keyboardButton, voiceButton ] {
                addSubview(button)
                button.autoPinEdgesToSuperviewEdges()
            }
            configureViewsForState(state)

            setContentHuggingHigh()
            setCompressionResistanceHigh()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func configureViewsForState(_ state: State) {
            switch state {
            case .voice:
                keyboardButton.transform = .identity
                keyboardButton.alpha = 1
                
                voiceButton.transform = .scale(0.1)
                voiceButton.alpha = 0
                sendButton.transform = .scale(0.1)
                sendButton.alpha = 0
            case .keyboard:
                voiceButton.transform = .identity
                voiceButton.alpha = 1
                
                keyboardButton.transform = .scale(0.1)
                keyboardButton.alpha = 0
                sendButton.transform = .scale(0.1)
                sendButton.alpha = 0
            case .sendButton:
                sendButton.transform = .identity
                sendButton.alpha = 1
                sendButton.isEnabled = true
                
                voiceButton.transform = .scale(0.1)
                voiceButton.alpha = 0
                keyboardButton.transform = .scale(0.1)
                keyboardButton.alpha = 0
            case .unavailable:
                sendButton.transform = .identity
                sendButton.alpha = 1
                sendButton.isEnabled = false
                
                voiceButton.transform = .scale(0.1)
                voiceButton.alpha = 0
                keyboardButton.transform = .scale(0.1)
                keyboardButton.alpha = 0
            }
        }
    }

    // MARK: Add/Cancel Button

    private class AddOrCancelButton: UIButton {

        private let roundedCornersBackground: UIView = {
            let view = UIView()
            view.backgroundColor = .init(rgbHex: 0x3B3B3B)
            view.clipsToBounds = true
            view.layer.cornerRadius = 14
            view.isUserInteractionEnabled = false
            return view
        }()

        private let iconImageView = UIImageView(image: UIImage(imageLiteralResourceName: "inputtoolbar_plus"))

        private override init(frame: CGRect) {
            super.init(frame: frame)

            addSubview(iconImageView)
            iconImageView.autoCenterInSuperview()
            updateImageTransform()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var isHighlighted: Bool {
            didSet {
                // When user releases their finger appearance change animations will be fired.
                // We don't want changes performed by this method to interfere with animations.
                guard !isAnimatingAppearance else { return }

                // Mimic behavior of a standard system button.
                let opacity: CGFloat = isHighlighted ? (Theme.isDarkThemeEnabled ? 0.4 : 0.2) : 1
                switch appearance {
                case .add:
                    iconImageView.alpha = opacity

                case .close:
                    roundedCornersBackground.alpha = opacity
                }
            }
        }

        enum Appearance {
            case add
            case close
        }

        private var _appearance: Appearance = .add
        private var isAnimatingAppearance = false

        var appearance: Appearance {
            get { _appearance }
            set { setAppearance(newValue, usingAnimator: nil) }
        }

        func setAppearance(_ appearance: Appearance, usingAnimator animator: UIViewPropertyAnimator?) {
            guard appearance != _appearance else { return }

            _appearance = appearance

            guard let animator else {
                updateImageColorAndBackground()
                updateImageTransform()
                return
            }

            isAnimatingAppearance = true
            animator.addAnimations({
                    self.updateImageColorAndBackground()
                },
                delayFactor: appearance == .add ? 0 : 0.2
            )
            animator.addAnimations {
                self.updateImageTransform()
            }
            animator.addCompletion { _ in
                self.isAnimatingAppearance = false
            }
        }

        private func updateImageColorAndBackground() {
            switch appearance {
            case .add:
                iconImageView.alpha = 1
                iconImageView.tintColor = Theme.primaryIconColor
                roundedCornersBackground.alpha = 0
                roundedCornersBackground.transform = .scale(0.05)

            case .close:
                iconImageView.alpha = 1
                iconImageView.tintColor = .white
                roundedCornersBackground.alpha = 1
                roundedCornersBackground.transform = .identity
            }
        }

        private func updateImageTransform() {
            switch appearance {
            case .add:
                iconImageView.transform = .identity

            case .close:
                iconImageView.transform = .rotate(1.5 * .halfPi)
            }
        }
    }

    // MARK: Message Body

    var hasUnsavedDraft: Bool {
        let currentDraft = messageBodyForSending ?? .empty

        return !currentDraft.isEmpty
    }

    @objc var messageBodyForSending: String? { inputTextView.trimmedText() }
    @objc var untrimmedMessageBody: String? { inputTextView.untrimmedText() }
    
    @objc var selectRange: NSRange { inputTextView.selectedRange }

    // recall re-edit 场景需要在外部调用
    @objc func setMessageBody(_ messageBody: String?, animated: Bool, doLayout: Bool = true) {
        setMessageBody(messageBody, selectRange: NSMakeRange(0, 0), animated: animated, doLayout: doLayout)
    }
    
    @objc func setMessageBody(_ messageBody: String?, selectRange: NSRange, animated: Bool, doLayout: Bool = true) {
        self.inputTextView.text = messageBody

        // It's important that we set the textViewHeight before
        // doing any animation in `ensureButtonVisibility(withAnimation:doLayout)`
        // Otherwise, the resultant keyboard frame posted in `keyboardWillChangeFrame`
        // could reflect the inputTextView height *before* the new text was set.
        //
        // This bug was surfaced to the user as:
        //  - have a quoted reply draft in the input toolbar
        //  - type a multiline message
        //  - hit send
        //  - quoted reply preview and message text is cleared
        //  - input toolbar is shrunk to it's expected empty-text height
        //  - *but* the conversation's bottom content inset was too large. Specifically, it was
        //    still sized as if the input textview was multiple lines.
        // Presumably this bug only surfaced when an animation coincides with more complicated layout
        // changes (in this case while simultaneous with removing quoted reply subviews, hiding the
        // wrapper view *and* changing the height of the input textView
        ensureTextViewHeight()

        if let text = messageBody, !text.isEmpty {
            clearDesiredKeyboard()
        }

        ensureButtonVisibility(withAnimation: animated, doLayout: doLayout)
        
        if selectRange.location > 0  {
            inputTextView.selectedRange = selectRange
        }
    }

    @objc func ensureTextViewHeight() {
        updateHeightWithTextView(inputTextView)
    }

    func acceptAutocorrectSuggestion() {
        inputTextView.acceptAutocorrectSuggestion()
    }

    @objc func clearTextMessage(animated: Bool) {
        setMessageBody(nil, animated: animated)
        inputTextView.undoManager?.removeAllActions()
    }

    // MARK: Quoted Reply

    @objc var quotedReplyDraft: OWSQuotedReplyModel? {
        didSet {
            guard oldValue != quotedReplyDraft else { return }

            layer.removeAllAnimations()

            let animateChanges = window != nil
            if quotedReplyDraft != nil {
                showQuotedReplyView(animated: animateChanges)
            } else {
                hideQuotedReplyView(animated: animateChanges)
            }
            // This would show / hide Stickers|Keyboard button.
            ensureButtonVisibility(withAnimation: true, doLayout: false)
            clearDesiredKeyboard()
        }
    }

    private func showQuotedReplyView(animated: Bool) {
        guard let quotedReplyDraft else {
            owsFailDebug("quotedReply == nil")
            return
        }

        let quotedMessagePreview = DTInputReplyPreview(quotedReply: quotedReplyDraft, conversationStyle: conversationStyle)

        quotedMessagePreview.delegate = self
        quotedMessagePreview.setContentHuggingHorizontalLow()
        quotedMessagePreview.setCompressionResistanceHorizontalLow()
        quotedMessagePreview.accessibilityIdentifier = UIView.accessibilityIdentifier(in: self, name: "quotedMessagePreview")
        quotedReplyWrapper.addSubview(quotedMessagePreview)
        quotedMessagePreview.autoPinEdgesToSuperviewEdges()

        toggleMessageComponentVisibility(hide: false, component: quotedReplyWrapper, animated: animated)
    }

    private func hideQuotedReplyView(animated: Bool) {
        owsAssertDebug(quotedReplyDraft == nil)
        toggleMessageComponentVisibility(hide: true, component: quotedReplyWrapper, animated: animated) { _ in
            self.quotedReplyWrapper.removeAllSubviews()
        }
    }

    private func toggleMessageComponentVisibility(
        hide: Bool,
        component: UIView,
        animated: Bool,
        completion: ((Bool) -> Void)? = nil
    ) {
        if animated, component.isHidden != hide {
            isAnimatingHeightChange = true

            UIView.animate(
                withDuration: ConversationInputToolbar.heightChangeAnimationDuration,
                animations: {
                    component.isHidden = hide
                },
                completion: { completed in
                    self.isAnimatingHeightChange = false
                    completion?(completed)
                }
            )
        } else {
            component.isHidden = hide
            completion?(true)
        }
    }

    func inputReplyPreviewDidPressCancel(_ preview: DTInputReplyPreview) {
        quotedReplyDraft = nil
    }

    // MARK: Voice Memo

    private enum VoiceMemoRecordingState {
        case idle
        case recording
    }

    private var voiceMemoRecordingState: VoiceMemoRecordingState = .idle {
        didSet {
            guard oldValue != voiceMemoRecordingState else { return }
            ensureButtonVisibility(withAnimation: true, doLayout: true)
        }
    }
    private var voiceMemoGestureStartLocation: CGPoint?

    private var isShowingVoiceMemoUI: Bool = false {
        didSet {
            guard isShowingVoiceMemoUI != oldValue else { return }
            ensureButtonVisibility(withAnimation: true, doLayout: true)
        }
    }

    private var inCancleRecordCircle: Bool? = false {
        didSet {
            guard oldValue != inCancleRecordCircle else { return }
            updateVoiceMemoTipState()
        }
    }
    
    private var inContainerView: Bool? = false

    private var voiceMemoCancelLabel: UILabel?
    private var voiceMemoCancleCircle: UIButton?
    private var voiceMemoGradientContainerView: UIView?
    
    private let countdownBubbleView = RecordingCountdownBubbleView()
    private let recordingProcessor = RecordingLimitProcessor()
    
    private let voiceMemoBGHeight: CGFloat = 196 + 20
    private let voiceMemoCancelBtnHeight: CGFloat = 72 + 10
    
    @objc func showVoiceMemoUI() {
        AssertIsOnMainThread()

        isShowingVoiceMemoUI = true

        voiceMemoCancleCircle?.removeFromSuperview()

        let gradientContainerView: UIView = {
            let gradientLayer = CAGradientLayer()
            if Theme.isDarkThemeEnabled {
                gradientLayer.colors = [
                    UIColor.black.withAlphaComponent(0).cgColor,
                    UIColor.black.cgColor
                ]
            } else {
                gradientLayer.colors = [
                    UIColor.white.withAlphaComponent(0).cgColor,
                    UIColor.white.cgColor
                ]
            }
            
            let view = OWSLayerView(frame: .zero) { view in
                gradientLayer.frame = view.bounds
            }
            view.layer.addSublayer(gradientLayer)
            return view
        }()
        addSubview(gradientContainerView)
        gradientContainerView.autoPinWidthToSuperview()
        gradientContainerView.autoPinEdge(.bottom, to: .top, of: self)
        gradientContainerView.autoSetDimension(.height, toSize: voiceMemoBGHeight)
                
        let cancelLabel = UILabel()
        cancelLabel.textColor = Theme.primaryTextColor
        cancelLabel.font = .systemFont(ofSize: 14)
        cancelLabel.text = OWSLocalizedString("Release to Cancel", comment: "")
        cancelLabel.numberOfLines = 1
        cancelLabel.alpha = 0
        self.voiceMemoCancelLabel = cancelLabel
        
        let redCircleView = UIButton()
        redCircleView.layer.cornerRadius = voiceMemoCancelBtnHeight / 2
        redCircleView.layer.masksToBounds = true
        redCircleView.setBackgroundColor(Theme.thirdTextAndIconColor, for: .normal)
        redCircleView.setImage((UIImage(named: "inputtoolbar_voice_close")), for: .normal)
        redCircleView.setBackgroundColor(Theme.redBgroundColor, for: .selected)
        redCircleView.setImage((UIImage(named: "inputtoolbar_voice_close")), for: .selected)
        redCircleView.autoSetDimensions(to: CGSize(square: voiceMemoCancelBtnHeight))
        self.voiceMemoCancleCircle = redCircleView
        
        let voicememoCancelVStack = UIStackView(arrangedSubviews: [
            cancelLabel,
            redCircleView
        ])
        voicememoCancelVStack.axis = .vertical
        voicememoCancelVStack.alignment = .center
        voicememoCancelVStack.distribution = .fill
        voicememoCancelVStack.spacing = 12 + 6
        gradientContainerView.addSubview(voicememoCancelVStack)
        voicememoCancelVStack.autoCenterInSuperview()
        
        addSubview(countdownBubbleView)
        countdownBubbleView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            countdownBubbleView.bottomAnchor.constraint(equalTo: cancelLabel.topAnchor, constant: -8),
            countdownBubbleView.centerXAnchor.constraint(equalTo: cancelLabel.centerXAnchor),
            countdownBubbleView.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            countdownBubbleView.heightAnchor.constraint(equalToConstant: 38)
        ])
        
        self.voiceMemoGradientContainerView = gradientContainerView
        
    }

    @objc func hideVoiceMemoUI(animated: Bool) {
        AssertIsOnMainThread()

        isShowingVoiceMemoUI = false

        voiceMemoRecordingState = .idle

        let oldVoiceMemoGradientContainerView = voiceMemoGradientContainerView
        let oldVoiceMemoRedRecordingCircle = voiceMemoCancleCircle

        voiceMemoCancelLabel = nil
        voiceMemoCancleCircle = nil

        if animated {
            UIView.animate(
                withDuration: 0.2,
                animations: {
                    oldVoiceMemoRedRecordingCircle?.alpha = 0
                    oldVoiceMemoGradientContainerView?.alpha = 0
                },
                completion: { _ in
                    oldVoiceMemoRedRecordingCircle?.removeFromSuperview()
                    oldVoiceMemoGradientContainerView?.removeFromSuperview()
                }
            )
        } else {
            oldVoiceMemoRedRecordingCircle?.removeFromSuperview()
            oldVoiceMemoGradientContainerView?.removeFromSuperview()
        }
    }
    
    class func makeView(_ animation: @escaping () -> Void) {
        let animator = UIViewPropertyAnimator(duration: 0.25, springDamping: 0.645, springResponse: 0.25)
        animator.addAnimations(animation)
        
        animator.startAnimation()
    }
    
    // 更新放大圆圈
    private func updateVoiceMemoTipState() {
        AssertIsOnMainThread()
                
        ConversationInputToolbar.makeView {
            self.voiceMemoCancleCircle?.transform = true == self.inCancleRecordCircle ? .scale(1.2) : .identity
            self.voiceMemoCancleCircle?.isSelected = self.inCancleRecordCircle!
            self.voiceMemoCancelLabel?.alpha = true == self.inCancleRecordCircle ? 1 : 0
        }
        
        ensureButtonVisibility(withAnimation: true, doLayout: true)
        
        Logger.debug("[keyboard] \(voiceMemoView.gestureState)")
    }

    @objc
    private func handleVoiceMemoLongPress(gesture: UILongPressGestureRecognizer) {
        
        switch gesture.state {
        case .possible, .cancelled, .failed:
            voiceMemoRecordingState = .idle
            break
        case .began:
            Logger.debug("[keyboard] gesture state: began.")
            voiceMemoRecordingState = .recording
            voiceMemoGestureStartLocation = gesture.location(in: self)
            
            ImpactHapticFeedback.impactOccurred(style: .light)
            inputToolbarDelegate?.voiceMemoGestureDidStart()
            recordingProcessor.start()
        case .changed:
            guard isShowingVoiceMemoUI else { return }
            guard voiceMemoGestureStartLocation != nil else {
                owsFailDebug("voiceMemoGestureStartLocation is nil")
                return
            }
            
            let point = gesture.location(in: voiceMemoCancleCircle)
            inCancleRecordCircle = voiceMemoCancleCircle?.point(inside: point, with: nil)
            
            Logger.debug("[keyboard] gesture state: changed, point: \(point), inCircle: \(inCancleRecordCircle!)")
        case .ended:
            
            switch voiceMemoRecordingState {
            case .idle:
                if inCancleRecordCircle == true {
                    cancelRecording()
                }
            case .recording:
                voiceMemoRecordingState = .idle
                if inCancleRecordCircle == true {
                    cancelRecording()
                } else {
                    stopRecording()
                }
            @unknown default: break
            }
            
            inCancleRecordCircle = false
            voiceMemoGestureStartLocation = nil
            Logger.debug("[keyboard] gesture state: end")
        @unknown default:
            Logger.debug("[keyboard] gesture state: default")
            break
        }
    }
    
    func cancelRecording() {
        recordingProcessor.stop()
        countdownBubbleView.hide()
        NotificationHapticFeedback().notificationOccurred(.warning)
        inputToolbarDelegate?.voiceMemoGestureDidCancel()
    }
    
    func stopRecording() {
        recordingProcessor.stop()
        countdownBubbleView.hide()
        ImpactHapticFeedback.impactOccurred(style: .medium)
        inputToolbarDelegate?.voiceMemoGestureDidComplete()
    }

    // MARK: Keyboards

    private(set) var isMeasuringKeyboardHeight = false
    private var hasMeasuredKeyboardHeight = false

    // Workaround for keyboard & chat flashing when switching between keyboards on iOS 17.
    // When swithing keyboards sometimes! we get "keyboard will show" notification
    // with keyboard frame being slightly (45 dp) shorter, immediately followed by another
    // notification with previous (correct) keyboard frame.
    //
    // Because this does not always happen and because this does not happen on a Simulator
    // I concluded this is an iOS 17 bug.
    //
    // In the future it might be better to implement different keyboard managing
    // by making UIViewController a first responder and vending input bar as `inputView`.
    private(set) var isSwitchingKeyboard = false

    private enum KeyboardType {
        case system
        case attachment
    }

    private var _desiredKeyboardType: KeyboardType = .system

    private var desiredKeyboardType: KeyboardType {
        get { _desiredKeyboardType }
        set { setDesiredKeyboardType(newValue, animated: false) }
    }

    private var _attachmentKeyboard: AttachmentKeyboard?

    private var attachmentKeyboard: AttachmentKeyboard {
        if let attachmentKeyboard = _attachmentKeyboard {
            return attachmentKeyboard
        }
        let keyboard = AttachmentKeyboard(inputToolbarState: inputToolbarState, relationship: relationship, threadType: threadType, delegate: self)
        keyboard.registerWithView(self)
        let height: CGFloat = 128*2 + 21*2
        keyboard.updateSystemKeyboardHeight(height)
        _attachmentKeyboard = keyboard
        return keyboard
    }

    private var attachmentKeyboardIfLoaded: AttachmentKeyboard? { _attachmentKeyboard }

    func showAttachmentKeyboard() {
        AssertIsOnMainThread()
        guard desiredKeyboardType != .attachment else { return }
        toggleKeyboardType(.attachment, animated: false)
    }

    private func toggleKeyboardType(_ keyboardType: KeyboardType, animated: Bool) {
        guard let inputToolbarDelegate = inputToolbarDelegate else {
            owsFailDebug("inputToolbarDelegate is nil")
            return
        }

        if desiredKeyboardType == keyboardType {
            setDesiredKeyboardType(.system, animated: animated)
        } else {
            // For switching to anything other than the system keyboard,
            // make sure this conversation isn't blocked before presenting it.
//            if inputToolbarDelegate.isBlockedConversation() {
//                inputToolbarDelegate.showUnblockConversationUI { [weak self] isBlocked in
//                    guard let self = self, !isBlocked else { return }
//                    self.toggleKeyboardType(keyboardType, animated: animated)
//                }
//                return
//            }

            setDesiredKeyboardType(keyboardType, animated: animated)
        }

        beginEditingMessage()
    }

    private func setDesiredKeyboardType(_ keyboardType: KeyboardType, animated: Bool) {
        Logger.debug("keyboardType: \(keyboardType) ")
        
        guard _desiredKeyboardType != keyboardType else { return }

        _desiredKeyboardType = keyboardType

        ensureButtonVisibility(withAnimation: animated, doLayout: true)

        if isInputViewFirstResponder {
            isSwitchingKeyboard = true
            // If any keyboard is presented, make sure the correct
            // keyboard is presented.
            beginEditingMessage()

            DispatchQueue.main.async {
                self.isSwitchingKeyboard = false
            }
        } else {
            // Make sure neither keyboard is presented.
            endEditingMessage()
        }
    }

    @objc func clearDesiredKeyboard() {
        AssertIsOnMainThread()
        desiredKeyboardType = .system
    }

    private func restoreDesiredKeyboardIfNecessary() {
        AssertIsOnMainThread()
        if desiredKeyboardType != .system && !desiredFirstResponder.isFirstResponder {
            desiredFirstResponder.becomeFirstResponder()
        }
    }

    private func cacheKeyboardIfNecessary() {
        // Preload the keyboard if we're not showing it already, this
        // allows us to calculate the appropriate initial height for
        // our custom inputViews and in general to present it faster
        // We disable animations so this preload is invisible to the
        // user.
        //
        // We only measure the keyboard if the toolbar isn't hidden.
        // If it's hidden, we're likely here from a peek interaction
        // and don't want to show the keyboard. We'll measure it later.
        guard !hasMeasuredKeyboardHeight && !inputTextView.isFirstResponder && !isHidden else { return }

        // Flag that we're measuring the system keyboard's height, so
        // even if though it won't be the first responder by the time
        // the notifications fire, we'll still read its measurement
        isMeasuringKeyboardHeight = true

        UIView.setAnimationsEnabled(false)

        _ = inputTextView.becomeFirstResponder()
        _ = inputTextView.resignFirstResponder()

        // TODO: keyboard mention
//        inputTextView.reloadMentionState()

        UIView.setAnimationsEnabled(true)
    }

    @objc var isInputViewFirstResponder: Bool {
        return inputTextView.isFirstResponder
        || attachmentKeyboardIfLoaded?.isFirstResponder ?? false
    }

    private func ensureFirstResponderState() {
        restoreDesiredKeyboardIfNecessary()
    }

    private var desiredFirstResponder: UIResponder {
        switch desiredKeyboardType {
        case .system: return inputTextView
        case .attachment: return attachmentKeyboard
        }
    }

    @objc func beginEditingMessage() {
        guard !desiredFirstResponder.isFirstResponder else { return }
        desiredFirstResponder.becomeFirstResponder()
    }

    @objc func endEditingMessage() {
        _ = inputTextView.resignFirstResponder()
        _ = attachmentKeyboardIfLoaded?.resignFirstResponder()
    }

    @objc func viewDidAppear() {
        ensureButtonVisibility(withAnimation: false, doLayout: false)
        cacheKeyboardIfNecessary()
    }

    @objc
    private func applicationDidBecomeActive(notification: Notification) {
        AssertIsOnMainThread()
        restoreDesiredKeyboardIfNecessary()
    }

    @objc
    private func keyboardFrameDidChange(notification: Notification) {
        guard let keyboardEndFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            owsFailDebug("keyboardEndFrame is nil")
            return
        }

        guard inputTextView.isFirstResponder || isMeasuringKeyboardHeight else { return }
        let newHeight = keyboardEndFrame.size.height - frame.size.height
        
//        Logger.debug("[keyboard] EndFrame: \(keyboardEndFrame)")
//        Logger.debug("[keyboard] toolbar: \(frame)")
//        Logger.debug("[keyboard] newHeight: \(newHeight)")
        
        guard newHeight > 0 else { return }
//        attachmentKeyboard.updateSystemKeyboardHeight(newHeight)
        if isMeasuringKeyboardHeight {
            isMeasuringKeyboardHeight = false
            hasMeasuredKeyboardHeight = true
        }
    }
    
    @objc func startGroupAt() {
        let inputText = inputTextView.untrimmedText();
        if var inputText = inputText, !inputText.isEmpty {
            if inputTextView.isFirstResponder {
                let location = inputTextView.selectedRange.location
                
                let index = inputText.index(inputText.startIndex, offsetBy: location)
                
                inputText.insert("@", at: index)
                
                inputTextView.text = inputText
                inputTextView.selectedRange = NSRange(location: location + 1, length: 0)
                inputToolbarDelegate?.atIsActive(location: UInt(location + 1))
            } else {
                inputTextView.text = inputText + "@"
                inputToolbarDelegate?.atIsActive(location: UInt(inputTextView.text.count))
            }
        } else {
            inputTextView.text = "@"
            inputToolbarDelegate?.atIsActive(location: 1)
        }

        self.ensureButtonVisibility(withAnimation: true, doLayout: true);
    }
}
    
// MARK: Button Actions

extension ConversationInputToolbar {

    @objc
    private func voiceButtonPressed() {
        ImpactHapticFeedback.impactOccurred(style: .light)
        
        rightEdgeControlsView.state = .voice
        endEditingMessage()
        clearDesiredKeyboard()
        
        // .voice .keyboard 对应的键盘类型都是 system, 需要主动更新视图
        ensureButtonVisibility(withAnimation: true, doLayout: true)
    }
    
    @objc
    private func keyboardButtonPressed() {
        ImpactHapticFeedback.impactOccurred(style: .light)
        
        rightEdgeControlsView.state = .keyboard
        toggleKeyboardType(.system, animated: true)
        
        // .voice .keyboard 对应的键盘类型都是 system, 需要主动更新视图
        ensureButtonVisibility(withAnimation: true, doLayout: true)
    }
    
    @objc
    private func cameraButtonPressed() {
        guard let inputToolbarDelegate = inputToolbarDelegate else {
            owsFailDebug("inputToolbarDelegate == nil")
            return
        }
        
        ImpactHapticFeedback.impactOccurred(style: .light)
        inputToolbarDelegate.cameraButtonPressed()
    }

    @objc
    private func addOrCancelButtonPressed() {
        ImpactHapticFeedback.impactOccurred(style: .light)
        
        toggleKeyboardType(.attachment, animated: true)
    }

    @objc
    private func confideButtonPressed() {
        ImpactHapticFeedback.impactOccurred(style: .light)
        
        inputToolbarDelegate?.confideButtonPressed()
    }
    
    @objc
    private func sendButtonPressed() {
        guard let inputToolbarDelegate = inputToolbarDelegate else {
            owsFailDebug("inputToolbarDelegate == nil")
            return
        }

        // TODO: keyboard 移除语音草稿模式
        guard !isShowingVoiceMemoUI else {
            voiceMemoRecordingState = .idle

            return
        }

        inputToolbarDelegate.sendButtonPressed()
    }
    
    @objc
    private func expandButtonPressed() {
        guard let inputToolbarDelegate = inputToolbarDelegate else {
            owsFailDebug("inputToolbarDelegate == nil")
            return
        }

        inputToolbarDelegate.expandButtonPressed(self)

    }
}

extension ConversationInputToolbar: ConversationTextViewToolbarDelegate {
    public func textViewDidBeginEditing(_ textView: UITextView) {
        
    }
    
    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        //是新增at就触发弹框
        if text == "@" {
            let range = textView.selectedRange
            inputToolbarDelegate?.atIsActive(location: UInt(range.location + 1))
        }
        
        return true
    }
    
    public func textViewWillBeginDragging(_ scrollView: UIScrollView) {
        
    }

    private func updateHeightWithTextView(_ textView: UITextView) {


        var maxLines = 4
        if !expandButton.isHidden {
            maxLines = 3
        }
        let currentLines = numberOfLines(in: textView)
        let showExpand = currentLines >= maxLines
        expandButton.isHidden = !showExpand
        if lastNumberOflines != currentLines {
            lastNumberOflines = currentLines
            setupConfideButtonLayout(showExpand: showExpand)
        }
        
        DispatchQueue.main.async {
            let contentSize = textView.sizeThatFits(CGSizeMake(textView.width, CGFLOAT_MAX))

            let newHeight = CGFloat.clamp(
                contentSize.height,
                min: LayoutMetrics.minTextViewHeight,
                max: UIDevice.current.isIPad ? LayoutMetrics.maxIPadTextViewHeight : LayoutMetrics.maxTextViewHeight
            )
            
            self.inputTextView.contentSize = CGSize(width: .zero, height: contentSize.height)
            
            Logger.debug("\(self.logTag) newHeight: \(newHeight)")

            guard newHeight != self.textViewHeight else { return }

            guard let textViewHeightConstraint = self.textViewHeightConstraint else {
                owsFailDebug("[keyboard] textViewHeightConstraint == nil")
                return
            }

            self.textViewHeight = newHeight
            textViewHeightConstraint.constant = newHeight

            self.invalidateIntrinsicContentSize()
        }
        
    }

    public func textViewDidChange(_ textView: UITextView) {
        owsAssertDebug(inputToolbarDelegate != nil)

        // Ignore change events during configuration.
        guard isConfigurationComplete else { return }

        updateHeightWithTextView(textView)
        ensureButtonVisibility(withAnimation: true, doLayout: true)
        
    }
    
    func numberOfLines(in textView: UITextView) -> Int {
        guard textView.font != nil else { return 0 }
        
        let textContainer = textView.textContainer
        let layoutManager = textView.layoutManager
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        
        var lineCount = 0
        var index = glyphRange.location
        while index < glyphRange.upperBound {
            var lineRange = NSRange()
            layoutManager.lineFragmentRect(forGlyphAt: index, effectiveRange: &lineRange)
            lineCount += 1
            index = NSMaxRange(lineRange)
        }
        
        return lineCount
    }

    func textViewDidChangeSelection(_ textView: UITextView) { }

    public func textViewDidBecomeFirstResponder(_ textView: UITextView) {
        setDesiredKeyboardType(.system, animated: true)
    }
}


extension ConversationInputToolbar: AttachmentKeyboardDelegate {

    var isGroup: Bool {
        inputToolbarDelegate?.isGroup() ?? false
    }

//    func didSelectRecentPhoto(asset: PHAsset, attachment: SignalAttachment) {
//        inputToolbarDelegate?.didSelectRecentPhoto(asset: asset, attachment: attachment)
//    }

    func didTapPhotos() {
        inputToolbarDelegate?.photosButtonPressed()
    }

    func didTapCamera() {
        inputToolbarDelegate?.cameraButtonPressed()
    }

    func didTapVoiceCall() {
        inputToolbarDelegate?.voiceCallButtonPressed()
    }
    
    func didTapVideoCall() {
        inputToolbarDelegate?.videoCallButtonPressed()
    }

    func didTapFile() {
        inputToolbarDelegate?.fileButtonPressed()
    }

    func didTapContact() {
        inputToolbarDelegate?.contactButtonPressed()
    }
    
    func didTapConfidentialMode() {
        inputToolbarDelegate?.confideButtonPressed()
    }
    
    func didTapMention() {
        inputToolbarDelegate?.mentionButtonPressed()
    }
}


extension ConversationInputToolbar: RecordingLimitProcessorDelegate {
    func recordingLimitProcessorShouldShowCountdown(secondsLeft: Int) {
        countdownBubbleView.updateText("Recording will stop in \(secondsLeft) seconds")
        countdownBubbleView.show()
    }

    func recordingLimitProcessorDidReachLimit() {
        stopRecording()
    }
}
