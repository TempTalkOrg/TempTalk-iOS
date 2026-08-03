//
//  DTSearchExtension.swift
//  Wea
//
//  Created by hornet on 2022/5/3.
//  Copyright © 2022 Difft. All rights reserved.
//


let kDefaultShowMoreNum : Int = 4
enum DTSearchViewState : Int{
    case defaultState
    case noResults
}

enum SearchSection: Int {
    case noResults
    case recent //联系人
    case contacts //联系人
    case conversations //会话（仅包含群组会话）
    case messages //消息
}

@objc
protocol ConversationSearchViewDelegate: AnyObject {
    func conversationSearchViewWillBeginDragging()
}


class EmptySearchResultCell: UITableViewCell {
    static let reuseIdentifier = "EmptySearchResultCell"

    let messageLabel: UILabel
    private let iconView: UIImageView
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        self.messageLabel = UILabel()
        self.iconView = UIImageView()
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.backgroundColor = Theme.bgpagePrimaryColor
        contentView.backgroundColor = Theme.bgpagePrimaryColor

        selectionStyle = .none
        messageLabel.font = UIFont.ows_dynamicTypeBody
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 3
        messageLabel.textColor = Theme.tprimaryColor

        iconView.contentMode = .scaleAspectFit
        iconView.isHidden = true

        let stackView = UIStackView(arrangedSubviews: [iconView, messageLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 12
        contentView.addSubview(stackView)

        iconView.autoSetDimensions(to: CGSize(width: 96, height: 96))

        messageLabel.setContentHuggingHigh()
        messageLabel.setCompressionResistanceHigh()
        messageLabel.autoMatch(.width, to: .width, of: contentView, withOffset: -40, relation: .lessThanOrEqual)

        stackView.autoHCenterInSuperview()
        stackView.autoPinEdge(toSuperviewEdge: .top, withInset: 80)
        stackView.autoPinEdge(toSuperviewEdge: .leading, withInset: 20, relation: .greaterThanOrEqual)
        stackView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 20, relation: .greaterThanOrEqual)
        stackView.autoPinEdge(toSuperviewEdge: .bottom, withInset: 20, relation: .greaterThanOrEqual)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func configure(searchState: DTSearchViewState) {
        self.backgroundColor = Theme.bgpagePrimaryColor
        self.contentView.backgroundColor = Theme.bgpagePrimaryColor
        switch searchState {
        case .defaultState:
            self.messageLabel.text = Localized("ENTER_KEYWORDS_TO_SEARCH", comment: "Hint shown on the search page before any keyword is entered")
            self.messageLabel.isHidden = false
            self.iconView.image = UIImage(named: Theme.isDarkThemeEnabled ? "not-found-data-dark" : "not-found-data-light")
            self.iconView.isHidden = false
        case .noResults:
            self.messageLabel.text = Localized("HOME_VIEW_SEARCH_NO_RESULTS_FORMAT", comment: "Format string when search returns no results. Embeds {{search term}}")
            self.messageLabel.isHidden = false
            self.iconView.isHidden = true
        }
    }
    public func configure(searchText: String) {
        self.backgroundColor = Theme.bgpagePrimaryColor
        self.contentView.backgroundColor = Theme.bgpagePrimaryColor
        self.iconView.isHidden = true
        self.messageLabel.isHidden = false
        let format = Localized("HOME_VIEW_SEARCH_NO_RESULTS_FORMAT", comment: "Format string when search returns no results. Embeds {{search term}}")
        let messageText: String = NSString(format: format as NSString, searchText) as String
        self.messageLabel.text = searchText.count > 0 ? messageText : ""
    }
}


