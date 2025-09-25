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
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        self.messageLabel = UILabel()
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.backgroundColor = Theme.tableCellBackgroundColor
        contentView.backgroundColor = Theme.backgroundColor
        
        selectionStyle = .none
        messageLabel.font = UIFont.ows_dynamicTypeBody
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 3
        messageLabel.textColor = Theme.primaryTextColor

        contentView.addSubview(messageLabel)

        messageLabel.autoSetDimension(.height, toSize: 150)

        messageLabel.autoPinEdge(toSuperviewMargin: .top, relation: .greaterThanOrEqual)
        messageLabel.autoPinEdge(toSuperviewMargin: .leading, relation: .greaterThanOrEqual)
        messageLabel.autoPinEdge(toSuperviewMargin: .bottom, relation: .greaterThanOrEqual)
        messageLabel.autoPinEdge(toSuperviewMargin: .trailing, relation: .greaterThanOrEqual)

        messageLabel.autoVCenterInSuperview()
        messageLabel.autoHCenterInSuperview()

        messageLabel.setContentHuggingHigh()
        messageLabel.setCompressionResistanceHigh()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func configure(searchState: DTSearchViewState) {
        self.backgroundColor = Theme.backgroundColor
        self.contentView.backgroundColor = Theme.backgroundColor
        switch searchState {
        case .defaultState:
            self.messageLabel.text = Localized("ENTER_KEYWORDS_TO_SEARCH", comment: "Format string when search returns no results. Embeds {{search term}}")
        case .noResults:
            self.messageLabel.text = Localized("HOME_VIEW_SEARCH_NO_RESULTS_FORMAT", comment: "Format string when search returns no results. Embeds {{search term}}")

        }
    }
    public func configure(searchText: String) {
//        cell.backgroundColor = Theme.tableCellBackgroundColor
//        cell.contentView.backgroundColor = Theme.tableCellBackgroundColor
        self.backgroundColor = Theme.tableCellBackgroundColor
        self.contentView.backgroundColor = Theme.tableCellBackgroundColor
           let format = Localized("HOME_VIEW_SEARCH_NO_RESULTS_FORMAT", comment: "Format string when search returns no results. Embeds {{search term}}")
           let messageText: String = NSString(format: format as NSString, searchText) as String
           self.messageLabel.text = searchText.count > 0 ? messageText : ""
       }
}


