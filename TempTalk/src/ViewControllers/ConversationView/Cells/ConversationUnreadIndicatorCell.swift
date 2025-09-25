//
//  ConversationUnreadIndicatorCell.swift
//  Signal
//
//  Created by Jaymin on 2024/4/17.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit
import SnapKit
import TTMessaging

class ConversationUnreadIndicatorCell: ConversationCell {
    
    @objc
    static let reuserIdentifier = "ConversationUnreadIndicatorCell"
    
    @available(*, unavailable, message:"use other constructor instead.")
    @objc
    public required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.contentView.layoutMargins = .zero

        // Intercept touches.
        // Date breaks and unread indicators are not interactive.
        self.isUserInteractionEnabled = true

        stackView.addArrangedSubviews([lineView, titleLabel])
        lineView.snp.makeConstraints { make in
            make.height.equalTo(ConversationUnreadRenderItem.lineHeight)
        }
        
        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.equalToSuperview().offset(8)
            make.trailing.equalToSuperview().offset(-8)
        }
    }
    
    func configure(renderItem: ConversationUnreadRenderItem) {
        renderItem.titleConfig.applyForRendering(label: titleLabel)
        contentView.layoutMargins = renderItem.contentLayoutMargins
    }
    
    override func refreshTheme() {
        titleLabel.textColor = Theme.indicatorLineColor
        lineView.backgroundColor = Theme.indicatorLineColor
    }
    
    // MARK: - Lazy Load
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 2
        return stackView
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.font = .systemFont(ofSize: 12)
        return label
    }()

    private lazy var lineView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = ConversationUnreadRenderItem.lineHeight / 2
        return view
    }()
}
