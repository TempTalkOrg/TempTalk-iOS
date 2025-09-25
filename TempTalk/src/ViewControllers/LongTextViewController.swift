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
        messageTextView.text = messageBody

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
    
    public override func applyTheme() {
        super.applyTheme()
        
        messageTextView?.backgroundColor = Theme.backgroundColor
        messageTextView?.textColor = Theme.primaryTextColor
        footer?.barTintColor = Theme.navbarBackgroundColor
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
