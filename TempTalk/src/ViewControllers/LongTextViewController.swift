//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation
import TTServiceKit
import TTMessaging

@objc
public class LongTextViewController: OWSViewController {

    // MARK: Properties

    let viewItem: ConversationViewItem?

    let messageBody: String

    var messageTextView: UITextView?

    var footer: UIToolbar?

    static let kVisitingCardScheme = "personinfocard"

    // MARK: Initializers

    @available(*, unavailable, message:"use other constructor instead.")
    public required init?(coder aDecoder: NSCoder) {
        fatalError("\(#function) is unimplemented.")
    }

    @objc
    public required init(viewItem: ConversationViewItem) {
        self.viewItem = viewItem

        self.messageBody = LongTextViewController.displayableText(viewItem: viewItem)

        super.init()
    }
    
    @objc
    public required init(messageBody: String) {
        self.viewItem = nil
        self.messageBody = messageBody
        super.init()
    }

    private class func displayableText(viewItem: ConversationViewItem) -> String {
        guard viewItem.hasBodyText else {
            return ""
        }
        guard let displayableText = viewItem.displayableBodyText() else {
            return ""
        }
        let messageBody = displayableText.fullText
        return messageBody
    }

    // MARK: View Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = Localized("LONG_TEXT_VIEW_TITLE",
                                                      comment: "Title for the 'long text message' view.")

        createViews()
    }

    // MARK: - Create Views

    private func createViews() {

        let messageTextView = UITextView()
        self.messageTextView = messageTextView
        messageTextView.font = UIFont.ows_dynamicTypeBody
        messageTextView.isOpaque = true
        messageTextView.isEditable = false
        messageTextView.isSelectable = true
        messageTextView.isScrollEnabled = true
        messageTextView.dataDetectorTypes = .link
        messageTextView.showsHorizontalScrollIndicator = false
        messageTextView.showsVerticalScrollIndicator = true
        messageTextView.isUserInteractionEnabled = true
        messageTextView.textColor = UIColor.black
        messageTextView.delegate = self

        // Build attributed text with mentions support
        if let viewItem = self.viewItem {
            let attributedText = buildAttributedText(viewItem: viewItem)
            messageTextView.attributedText = attributedText
            messageTextView.linkTextAttributes = [.foregroundColor: Theme.tinfoColor]
        } else {
            messageTextView.text = messageBody
        }

        view.addSubview(messageTextView)
        messageTextView.autoPinEdge(toSuperviewEdge: .leading)
        messageTextView.autoPinEdge(toSuperviewEdge: .trailing)
//        messageTextView.textContainerInset = UIEdgeInsets(top: 0, left: view.layoutMargins.left, bottom: 0, right: view.layoutMargins.right)
        messageTextView.autoPinEdge(toSuperviewSafeArea: .top)

        DispatchQueue.main.async {
            messageTextView.contentOffset = .zero
        }

        let footer = UIToolbar()
        self.footer = footer
        view.addSubview(footer)
        footer.autoPinWidthToSuperview(withMargin: 0)
        footer.autoPinEdge(.top, to: .bottom, of: messageTextView)
        footer.autoPinEdge(toSuperviewSafeArea: .bottom)

        footer.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareButtonPressed)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        ]

        applyTheme()
    }

    private func buildAttributedText(viewItem: ConversationViewItem) -> NSAttributedString {
        guard let displayableBodyText = viewItem.displayableBodyText() else {
            return NSAttributedString(string: messageBody)
        }

        let text = displayableBodyText.fullText
        guard !text.isEmpty else {
            return NSAttributedString(string: messageBody)
        }

        let font = UIFont.ows_dynamicTypeBody
        let textColor = Theme.tprimaryColor
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 1

        let attributedString = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle
            ]
        )

        // Handle forward message source links
        DTPatternHelper.getForwardMessageSourceText(with: text, withCallBackCheckingResult: { resultArray in
            resultArray.forEach { result in
                let range = result.range(at: 0)
                if range.length > 0 {
                    let substring = text.substring(withRange: range)
                    let uid = DTPatternHelper.getForwardUidString(substring)
                    attributedString.addAttribute(
                        .link,
                        value: "\(Self.kVisitingCardScheme)://\(uid)",
                        range: range
                    )
                    attributedString.addAttribute(
                        .underlineStyle,
                        value: NSUnderlineStyle.single.rawValue,
                        range: range
                    )
                    attributedString.addAttribute(
                        .foregroundColor,
                        value: Theme.tprimaryColor,
                        range: range
                    )
                }
            }
        })

        // Handle mentions
        if let mentions = viewItem.mentions {
            mentions.forEach { mention in
                let range = NSMakeRange(Int(mention.start), Int(mention.length))
                if range.location + range.length > text.count {
                    Logger.error("[mention] range:\(range) out of bounds")
                    return
                }
                attributedString.addAttribute(
                    .foregroundColor,
                    value: Theme.tinfoColor,
                    range: range
                )
                attributedString.addAttribute(
                    .link,
                    value: "\(Self.kVisitingCardScheme)://\(mention.uid)",
                    range: range
                )
            }
        }

        return attributedString
    }
    
    public override func applyTheme() {
        super.applyTheme()
        
        messageTextView?.backgroundColor = Theme.bg1Color
        messageTextView?.textColor = Theme.tprimaryColor
        footer?.barTintColor = Theme.bg1Color
    }
    
    public override var canBecomeFirstResponder: Bool {
        return true
    }
    
    public override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
    }
    
    public override func resignFirstResponder() -> Bool {
        super.resignFirstResponder()
    }

    // MARK: - Actions

    @objc func shareButtonPressed() {
        AttachmentSharing.showShareUI(forText: messageBody)
    }
}

// MARK: - UITextViewDelegate

extension LongTextViewController: UITextViewDelegate {
    public func textView(
        _ textView: UITextView,
        shouldInteractWith URL: URL,
        in characterRange: NSRange,
        interaction: UITextItemInteraction
    ) -> Bool {
        // Handle all URLs with AppLinkManager (including personinfocard://, http://, etc.)
        _ = AppLinkManager.handle(url: URL, fromExternal: false, sourceVC: self)
        return false
    }
}
