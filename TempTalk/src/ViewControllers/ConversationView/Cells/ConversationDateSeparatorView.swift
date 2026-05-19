//
//  ConversationDateSeparatorView.swift
//  Signal
//
//  Created by Jaymin on 2024/5/7.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit
import SnapKit
import TTMessaging

class ConversationDateSeparatorView: UIView {
    
    enum Constants {
        static let height: CGFloat = 28
        static let padding: CGFloat = 12
    }
    
    private lazy var dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        return label
    }()
    
    var showsBackground: Bool = true

    private lazy var containerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = Constants.height * 0.5
        return view
    }()
    
    private var viewItem: ConversationViewItem?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        addSubview(containerView)
        containerView.addSubview(dateLabel)
        
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(Constants.height)
        }
        
        dateLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(Constants.padding)
            make.trailing.equalToSuperview().offset(-Constants.padding)
            make.centerY.equalToSuperview()
        }
    }
    
    func configure(viewItem: ConversationViewItem) {
        if let oldViewItem = self.viewItem, oldViewItem.interaction.uniqueThreadId == viewItem.interaction.uniqueThreadId {
            return
        }
        let date = viewItem.interaction.dateForSorting()
        let dateString = DateUtil.formatDateForConversationHeader(date)
        dateLabel.text = dateString
    }
    
    func configure(dateText: String?) {
        dateLabel.text = dateText
    }
    
    func refreshTheme() {
        dateLabel.textColor = Theme.tprimaryColor
        containerView.backgroundColor = showsBackground ? Theme.bg2Color : .clear
        containerView.layer.cornerRadius = showsBackground ? Constants.height * 0.5 : 0
    }
}
