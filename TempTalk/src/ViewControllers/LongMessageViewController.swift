//
//  LongMessageViewController.swift
//  Difft
//
//  Created by henry on 2025/11/19.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import TTServiceKit
import TTMessaging

@objc
public class LongMessageViewController: OWSViewController {

    private let viewItem: ConversationViewItem?

    private let messageBody: String

    private var messageTextView: UITextView?

    @available(*, unavailable, message:"use other constructor instead.")
    public required init?(coder aDecoder: NSCoder) {
        fatalError("\(#function) is unimplemented.")
    }

    @objc
    public required init(viewItem: ConversationViewItem) {
        self.viewItem = viewItem

        self.messageBody = LongMessageViewController.displayableText(viewItem: viewItem)

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

    public override func viewDidLoad() {
        super.viewDidLoad()
        DTToastHelper.showHud(in: self.view)
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
        messageTextView.dataDetectorTypes = []
        messageTextView.showsHorizontalScrollIndicator = false
        messageTextView.showsVerticalScrollIndicator = true
        messageTextView.isUserInteractionEnabled = true
        messageTextView.textColor = UIColor.black
        messageTextView.textContainer.lineBreakMode = .byWordWrapping
        messageTextView.layoutManager.allowsNonContiguousLayout = true
        messageTextView.layoutManager.usesFontLeading = false
        messageTextView.textContainerInset = .zero

        view.addSubview(messageTextView)
        messageTextView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.equalToSuperview()
            make.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }
        
        DispatchQueue.main.async {
            messageTextView.text = self.messageBody
            messageTextView.contentOffset = .zero
            
            DTToastHelper.hide()
        }
 
        applyTheme()
    }
    
    public override func applyTheme() {
        super.applyTheme()
        
        messageTextView?.backgroundColor = Theme.backgroundColor
        messageTextView?.textColor = Theme.primaryTextColor
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
}
