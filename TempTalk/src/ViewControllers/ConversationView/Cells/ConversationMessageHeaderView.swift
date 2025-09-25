//
//  ConversationMessageHeaderView.swift
//  Signal
//
//  Created by Jaymin on 2024/5/7.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit
import SnapKit

class ConversationMessageHeaderView: UIView {
    
    private lazy var dateSeparatorView = ConversationDateSeparatorView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        addSubview(dateSeparatorView)
        
        dateSeparatorView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.bottom.equalToSuperview().offset(-CVMessageHeaderRenderItem.bottomPadding)
            make.centerX.equalToSuperview()
        }
    }
    
    func configure(renderItem: CVMessageHeaderRenderItem) {
        dateSeparatorView.configure(dateText: renderItem.dateText)
    }
    
    func refreshTheme() {
        dateSeparatorView.refreshTheme()
    }
}
