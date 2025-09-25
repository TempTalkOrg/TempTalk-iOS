//
//  DTMoreSearchResult.swift
//  Wea
//
//  Created by hornet on 2022/5/2.
//  Copyright © 2022 Difft. All rights reserved.
//

import UIKit
import PureLayout

class DTMoreSearchResultCell: UITableViewCell {
    static let reuseIdentifier = "DTMoreSearchResultCellIdentifier"
    
    private lazy var title: UILabel = {
        title = UILabel()
        title.font = UIFont.systemFont(ofSize: 16)
        title.textAlignment = .center
        title.textColor = UIColor.ows_darkSkyBlue
        title.numberOfLines = 3
        title.text = Localized("SEARCH_SECTION_VIEW_MORE", comment: "Format string when search returns no results. Embeds {{search term}}")
        return title
    }()
    
    private lazy var icon: UIImageView = {
        icon = UIImageView()
        let image = UIImage.init(named: "ic_search_more")
        icon.image = image?.withRenderingMode(.alwaysTemplate)
        icon.tintColor = UIColor.ows_darkSkyBlue
        return icon
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.backgroundColor = Theme.tableCellBackgroundColor
        contentView.backgroundColor = Theme.tableCellBackgroundColor
        self.backgroundColor = Theme.tableCellBackgroundColor
        self.accessoryType = UITableViewCell.AccessoryType.disclosureIndicator
        selectionStyle = .none
        addSubviews()
        configSubviewLayout()
    }
    
    func addSubviews(){
        contentView.addSubview(icon)
        contentView.addSubview(title)
    }
    
    func configSubviewLayout(){
        icon.autoSetDimension(.height, toSize: 14)
        icon.autoSetDimension(.width, toSize: 14)
        icon.autoPinEdge(toSuperviewMargin: .leading, relation: .greaterThanOrEqual)
        icon.autoVCenterInSuperview()
        
        title.autoSetDimension(.height, toSize: 25)
        title.autoPinEdge(ALEdge.left, to: ALEdge.right, of: icon, withOffset: 10)
        title.autoVCenterInSuperview()
        title.setContentHuggingHigh()
        title.setCompressionResistanceHigh()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func configure(searchText: String) {
        let format = Localized("HOME_VIEW_SEARCH_NO_RESULTS_FORMAT", comment: "Format string when search returns no results. Embeds {{search term}}")
        let messageText: String = NSString(format: format as NSString, searchText) as String
        self.title.text = searchText.count > 0 ? messageText : ""
    }
}

class ConversationSearchTableViewCell: UITableViewCell {
    public static let reuseIdentifier: String = "ConversationSearchTableViewCell"
    public static let cellHeight: CGFloat = 70.0

    override func prepareForReuse() {
        super.prepareForReuse()
        
        refreshTheme()
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        selectionStyle = .none
        
        setupUI()
        refreshTheme()
        
        separatorInset = UIEdgeInsets(top: 0, left: 75, bottom: 0, right: 0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(iconImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(signLabel)
        contentView.addSubview(lastLabel)
        contentView.addSubview(dateLabel)
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20.0),
//            iconImageView.widthAnchor.constraint(equalToConstant: 48),
//            iconImageView.heightAnchor.constraint(equalToConstant: 48),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    // MARK: - Public Setting
    func set(icon render: IconRender) -> Self {
        switch render {
        case .note(let recipientId):
            iconImageView.dt_setImage(with: nil, placeholderImage: UIImage(named: "icon_note_to_self"), recipientId: recipientId)
        case let .group(thread, contactsManager):
            iconImageView.setImageWith(thread: thread, contactsManager: contactsManager)
        case let .account(avatar, recipientId):
            if let localNumber = TSAccountManager.localNumber(), localNumber == recipientId {
                iconImageView.dt_setImage(with: nil, placeholderImage: UIImage(named: "icon_note_to_self"), recipientId: recipientId)
            } else {
                iconImageView.setImageWithRecipientId(avatar: avatar, recipientId: recipientId)
            }
        }
        return self
    }
    
    func set(name render: RenderText) -> Self {
        self.render(target: nameLabel, with: render)
        return self
    }
    
    func set(sign render: RenderText) -> Self {
        self.render(target: signLabel, with: render)
        return self
    }
    
    func hidden(sign flag: Bool) -> Self {
        signLabel.isHidden = flag
        return self
    }
    
    func set(last render: RenderText) -> Self {
        self.render(target: lastLabel, with: render)
        return self
    }
    
    func hidden(last flag: Bool) -> Self {
        lastLabel.isHidden = flag
        return self
    }
    
    func set(date text: String) -> Self {
        dateLabel.text = text
        return self
    }
    
    func hidden(date flag: Bool) -> Self {
        dateLabel.isHidden = flag
        return self
    }
    
    func layout() -> Self {
        
        var nRect = CGRect.zero
        switch (signLabel.isHidden, lastLabel.isHidden) {
        case (true, true):
            if dateLabel.isHidden {
                nRect.origin.x = 78.0
                nRect.size.height = nameLabel.sizeThatFits(bounds.size).height
                nRect.origin.y = (contentView.bounds.height - nRect.height) * 0.5
                nRect.size.width = bounds.width - 10.0 - nRect.origin.x
                nameLabel.frame = nRect
            } else {
                nRect.size.height = nameLabel.sizeThatFits(bounds.size).height
                nRect.origin.y = (contentView.bounds.height - nRect.height) * 0.5
                nRect.size.width = dateLabel.sizeThatFits(bounds.size).width
                nRect.origin.x = bounds.width - 15.0 - nRect.width
                dateLabel.frame = nRect
                
                nRect.origin.x = 78.0
                nRect.size.width = dateLabel.frame.minX - 15.0 - nRect.origin.x
                nameLabel.frame = nRect
            }
        case (false, true):
            if dateLabel.isHidden {
                nRect.origin.x = 78.0
                nRect.origin.y = 14.0
                nRect.size.width = bounds.width - 10.0 - nRect.origin.x
                nRect.size.height = nameLabel.sizeThatFits(bounds.size).height
                nameLabel.frame = nRect
            } else {
                nRect.size.height = nameLabel.sizeThatFits(bounds.size).height
                nRect.origin.y = 14.0
                nRect.size.width = dateLabel.sizeThatFits(bounds.size).width
                nRect.origin.x = bounds.width - 15.0 - nRect.width
                dateLabel.frame = nRect
                
                nRect.origin.x = 78.0
                nRect.size.width = dateLabel.frame.minX - 15.0 - nRect.origin.x
                nameLabel.frame = nRect
                
                nRect.size.width = bounds.width - 10.0 - nRect.origin.x
            }
            
            nRect.size.height = signLabel.sizeThatFits(bounds.size).height
            nRect.origin.y = bounds.height - nRect.height - 14.0
            signLabel.frame = nRect
        case (true, false):
            if dateLabel.isHidden {
                nRect.origin.x = 78.0
                nRect.origin.y = 14.0
                nRect.size.width = bounds.width - 10.0 - nRect.origin.x
                nRect.size.height = nameLabel.sizeThatFits(bounds.size).height
                nameLabel.frame = nRect
            } else {
                nRect.size.height = nameLabel.sizeThatFits(bounds.size).height
                nRect.origin.y = 14.0
                nRect.size.width = dateLabel.sizeThatFits(bounds.size).width
                nRect.origin.x = bounds.width - 15.0 - nRect.width
                dateLabel.frame = nRect
                
                nRect.origin.x = 78.0
                nRect.size.width = dateLabel.frame.minX - 15.0 - nRect.origin.x
                nameLabel.frame = nRect
                
                nRect.size.width = bounds.width - 10.0 - nRect.origin.x
            }
            
            nRect.size.height = lastLabel.sizeThatFits(bounds.size).height
            nRect.origin.y = bounds.height - nRect.height - 14.0
            lastLabel.frame = nRect
        case (false, false):
            let padding: CGFloat = 8.0
            if dateLabel.isHidden {
                nRect.origin.x = 78.0
                nRect.origin.y = padding
                nRect.size.width = bounds.width - 10.0 - nRect.origin.x
                nRect.size.height = nameLabel.sizeThatFits(bounds.size).height
                nameLabel.frame = nRect
            } else {
                nRect.size.height = nameLabel.sizeThatFits(bounds.size).height
                nRect.origin.y = padding
                nRect.size.width = dateLabel.sizeThatFits(bounds.size).width
                nRect.origin.x = bounds.width - 15.0 - nRect.width
                dateLabel.frame = nRect
                
                nRect.origin.x = 78.0
                nRect.size.width = dateLabel.frame.minX - 15.0 - nRect.origin.x
                nameLabel.frame = nRect
                
                nRect.size.width = bounds.width - 10.0 - nRect.origin.x
            }
            
            nRect.size.height = lastLabel.sizeThatFits(bounds.size).height
            nRect.origin.y = bounds.height - padding - nRect.height
            lastLabel.frame = nRect
            
            nRect.size.height = signLabel.sizeThatFits(bounds.size).height
            let spacing = (lastLabel.frame.minY - nRect.height - nameLabel.frame.maxY) * 0.5
            nRect.origin.y = nameLabel.frame.maxY + spacing
            signLabel.frame = nRect
        }
        return self
    }
    
    private func render(target label: UILabel, with render: RenderText) {
        switch render {
        case .attribute(let nSAttributedString):
            guard label.attributedText != nSAttributedString else { return }
            label.attributedText = nSAttributedString
        case .normal(let string):
            guard label.text != string else { return }
            label.text = string
        }
    }
    
    func refreshTheme() {
        backgroundColor = Theme.tableCellBackgroundColor
        contentView.backgroundColor = Theme.tableCellBackgroundColor
        nameLabel.textColor = Theme.primaryTextColor
        signLabel.textColor = Theme.ternaryTextColor
        lastLabel.textColor = Theme.ternaryTextColor
        dateLabel.textColor = Theme.ternaryTextColor
    }
    
    // MARK: - lazy
    private lazy var iconImageView: DTAvatarImageView = {
        let imageView = DTAvatarImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.autoSetDimensions(to: CGSize(width: 48, height: 48))
        return imageView
    }()
    
    private lazy var nameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.ows_dynamicTypeBody
        return label
    }()
    
    private lazy var signLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 11)
        return label
    }()
    
    private lazy var lastLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 11)
        return label
    }()
    
    private lazy var dateLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 11)
        return label
    }()
}

extension ConversationSearchTableViewCell {
    enum RenderText: Equatable {
        case attribute(NSAttributedString)
        case normal(String)
        
        var isEmpty: Bool {
            switch self {
            case .attribute(let nSAttributedString):
                return nSAttributedString.string.isEmpty
            case .normal(let string):
                return string.isEmpty
            }
        }
    }
    
    enum IconRender {
        case note(recipientId: String)
        case group(thread: TSGroupThread, contactsManager: OWSContactsManager)
        case account(avatar: [String : Any], recipientId: String)
    }
}



