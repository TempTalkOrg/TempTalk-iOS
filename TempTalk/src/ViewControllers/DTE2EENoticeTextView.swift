//
//  DTE2EENoticeTextView.swift
//  TempTalk
//

import UIKit
import TTMessaging
import TTServiceKit

@objc enum DTE2EENoticeStyle: Int {
    case chatList
    case conversation
}

@objcMembers
final class DTE2EENoticeTextView: UIView {

    var didTapLearnMore: (() -> Void)?

    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            updateContentInsets()
            invalidateIntrinsicContentSize()
        }
    }

    private let style: DTE2EENoticeStyle
    private var contentConstraints: [NSLayoutConstraint] = []
    private var lastLayoutWidth: CGFloat = 0

    private lazy var textView: UITextView = {
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.isSelectable = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textAlignment = .center
        textView.delegate = self
        return textView
    }()

    init(style: DTE2EENoticeStyle) {
        self.style = style
        super.init(frame: .zero)
        setupView()
        applyTheme()
    }

    override convenience init(frame: CGRect) {
        self.init(style: .chatList)
        self.frame = frame
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func applyTheme() {
        backgroundColor = .clear
        textView.backgroundColor = .clear
        textView.linkTextAttributes = [
            .foregroundColor: Theme.tinfoColor,
            .underlineStyle: 0
        ]
        textView.attributedText = makeAttributedText()
        invalidateIntrinsicContentSize()
    }

    func height(fittingWidth width: CGFloat) -> CGFloat {
        let textWidth = max(0, width - contentInsets.left - contentInsets.right)
        let textHeight = textView.sizeThatFits(
            CGSize(width: textWidth, height: .greatestFiniteMagnitude)
        ).height
        return ceil(textHeight) + contentInsets.top + contentInsets.bottom
    }

    override var intrinsicContentSize: CGSize {
        let width = bounds.width > 0 ? bounds.width : UIScreen.main.bounds.width
        return CGSize(width: UIView.noIntrinsicMetric, height: height(fittingWidth: width))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard abs(bounds.width - lastLayoutWidth) > 0.5 else { return }
        lastLayoutWidth = bounds.width
        invalidateIntrinsicContentSize()
    }

    private func setupView() {
        addSubview(textView)
        updateContentInsets()
    }

    private func updateContentInsets() {
        NSLayoutConstraint.deactivate(contentConstraints)
        contentConstraints = [
            textView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: contentInsets.left),
            textView.topAnchor.constraint(equalTo: topAnchor, constant: contentInsets.top),
            textView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -contentInsets.right),
            textView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -contentInsets.bottom)
        ]
        NSLayoutConstraint.activate(contentConstraints)
    }

    private func makeAttributedText() -> NSAttributedString {
        let fullText: String
        switch style {
        case .chatList:
            fullText = Localized(
                "CHAT_LIST_E2EE_FOOTER",
                comment: "Messages and calls are end-to-end encrypted. Learn more"
            )
        case .conversation:
            fullText = Localized(
                "CONVERSATION_E2EE_HEADER",
                comment: "Messages and calls are end-to-end encrypted — only people in this chat can access them. Learn more"
            )
        }

        let learnMoreText = Localized("CONVERSATION_E2EE_LEARN_MORE", comment: "Learn more")
        let attributedText = NSMutableAttributedString()

        if let icon = UIImage(named: "ic_e2ee_lock")?.withTintColor(
            Theme.tthirdColor,
            renderingMode: .alwaysOriginal
        ) {
            let attachment = NSTextAttachment()
            attachment.image = icon
            attachment.bounds = CGRect(x: 0, y: -2, width: 12, height: 12)
            attributedText.append(NSAttributedString(attachment: attachment))
            attributedText.append(NSAttributedString(string: " "))
        }

        let textStartLocation = attributedText.length
        attributedText.append(NSAttributedString(string: fullText, attributes: [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: Theme.tthirdColor
        ]))

        if let range = fullText.range(of: learnMoreText, options: .backwards) {
            let textRange = NSRange(range, in: fullText)
            attributedText.addAttributes([
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: Theme.tinfoColor,
                .link: URL(string: "quicall-e2ee://info") as Any
            ], range: NSRange(
                location: textStartLocation + textRange.location,
                length: textRange.length
            ))
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.minimumLineHeight = 16
        paragraphStyle.maximumLineHeight = 16
        attributedText.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: attributedText.length)
        )
        return attributedText
    }
}

extension DTE2EENoticeTextView: UITextViewDelegate {
    func textView(
        _ textView: UITextView,
        shouldInteractWith URL: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        guard URL.scheme == "quicall-e2ee" else { return true }
        didTapLearnMore?()
        return false
    }
}
