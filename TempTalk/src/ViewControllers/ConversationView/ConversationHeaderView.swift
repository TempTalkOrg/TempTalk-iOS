//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation
import UIKit
import TTServiceKit
import TTMessaging

@objc
public protocol ConversationHeaderViewDelegate {
    func didTapConversationHeaderView(_ conversationHeaderView: ConversationHeaderView)
}

@objc
public class ConversationHeaderView: UIStackView {

    @objc
    public weak var delegate: ConversationHeaderViewDelegate?

    @objc
    public var attributedTitle: NSAttributedString? {
        get {
            return self.nameView.attributeName
        }
        set {
            self.nameView.attributeName = newValue
        }
    }
    
    @objc
    public var isExternal: Bool {
        get {
            return self.nameView.isExternal
        }
        set {
            self.nameView.isExternal = newValue
        }
    }


    @objc
    public var attributedSubtitle: NSAttributedString? {
        get {
            return self.subtitleLabel.attributedText
        }
        set {
            self.subtitleLabel.attributedText = newValue
        }
    }
    

    @objc
    public let titlePrimaryFont: UIFont =  UIFont.ows_regularFont(withSize: 17)
    @objc
    public let titleSecondaryFont: UIFont =  UIFont.ows_regularFont(withSize: 9)
    @objc
    public let subtitleFont: UIFont = UIFont.ows_regularFont(withSize: 12)

    private let nameView: DTConversationNameView

    private let subtitleLabel: UILabel
    @objc
    public required init(thread: TSThread, contactsManager: OWSContactsManager) {

        nameView = DTConversationNameView()
        nameView.nameColor = Theme.primaryTextColor
        nameView.lineBreakMode = .byTruncatingMiddle
        nameView.nameFont = titlePrimaryFont
        nameView.setContentHuggingHigh()
        nameView.setCompressionResistanceHorizontalLow()
        nameView.setCompressionResistanceVerticalHigh()
        
        subtitleLabel = UILabel()
        subtitleLabel.textColor = Theme.ternaryTextColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.font = subtitleFont
        subtitleLabel.setContentHuggingHigh()

        let textRows = UIStackView(arrangedSubviews: [nameView, subtitleLabel])
        textRows.axis = .vertical
        textRows.alignment = .leading
        textRows.distribution = .equalCentering

        textRows.layoutMargins = UIEdgeInsets(top: 0, left: -15, bottom: 0, right: 5)
        textRows.isLayoutMarginsRelativeArrangement = true

        // low content hugging so that the text rows push container to the right bar button item(s)
        textRows.setContentHuggingLow()
        
        super.init(frame: .zero)

        self.layoutMargins = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        self.isLayoutMarginsRelativeArrangement = true

        self.axis = .horizontal
        self.alignment = .center
        self.spacing = 0
//        self.addArrangedSubview(avatarContentView)
        self.distribution = .fill
        self.addArrangedSubview(textRows)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapView))
        self.addGestureRecognizer(tapGesture)
    }
    
    @objc
    public func applyTheme() {
        nameView.nameColor = Theme.primaryTextColor
        subtitleLabel.textColor = Theme.ternaryTextColor
    }
    
    
    required public init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    required public override init(frame: CGRect) {
        fatalError("init(frame:) has not been implemented")
    }

    public override var intrinsicContentSize: CGSize {
        // Grow to fill as much of the navbar as possible.
        return UIView.layoutFittingExpandedSize
    }


    // MARK: Delegate Methods

    @objc func didTapView(tapGesture: UITapGestureRecognizer) {
        guard tapGesture.state == .recognized else {
            return
        }

        self.delegate?.didTapConversationHeaderView(self)
    }
}
