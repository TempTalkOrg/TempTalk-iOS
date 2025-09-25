//
//  ConversationMessageFooterView.swift
//  Signal
//
//  Created by Jaymin on 2024/5/8.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit
import SnapKit
import TTMessaging

class ConversationMessageFooterView: UIView {
    
    enum Alignment {
        case leading
        case trailing
    }
    
    var alignment: Alignment = .leading {
        didSet {
            guard oldValue != alignment else { return }
            isNeedForceRefreshLayout = true
        }
    }
    
    private var isNeedForceRefreshLayout = false
    
    private lazy var replyButton: UIButton = {
        let button = UIButton()
        button.isHidden = true
        button.titleLabel?.font = .ows_dynamicTypeCaption1
        button.setTitle(Localized("CONVERSATION_THREAD_CONTEXY_REPLAY"), for: .normal)
        button.addTarget(self, action: #selector(replyButtonDidClick), for: .touchUpInside)
        return button
    }()
    
    private lazy var footerTimeLabel: UILabel = {
        let label = UILabel()
        label.font = .ows_dynamicTypeCaption2
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        addSubview(replyButton)
        addSubview(footerTimeLabel)
        
        replyButton.snp.makeConstraints { make in
            make.top.bottom.leading.equalToSuperview()
        }
        
        footerTimeLabel.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview()
            make.leading.greaterThanOrEqualTo(replyButton.snp.trailing).offset(12)
        }
    }
    
    private func refreshLayout() {
        isNeedForceRefreshLayout = false
        
        switch (replyButton.isHidden, footerTimeLabel.isHidden, alignment) {
        case (false, false, _):
            replyButton.snp.remakeConstraints { make in
                make.top.bottom.leading.equalToSuperview()
            }
            footerTimeLabel.snp.remakeConstraints { make in
                make.top.bottom.trailing.equalToSuperview()
                make.leading.greaterThanOrEqualTo(replyButton.snp.trailing).offset(12)
            }
        case (true, false, .leading):
            footerTimeLabel.snp.remakeConstraints { make in
                make.top.bottom.leading.equalToSuperview()
            }
        case (true, false, .trailing):
            footerTimeLabel.snp.remakeConstraints { make in
                make.top.bottom.trailing.equalToSuperview()
            }
        case (false, true, .leading):
            replyButton.snp.remakeConstraints { make in
                make.top.bottom.leading.equalToSuperview()
            }
        case (false, true, .trailing):
            replyButton.snp.remakeConstraints { make in
                make.top.bottom.trailing.equalToSuperview()
            }
        case (true, true, _):
            break
        }
    }
    
    // TODO: topic reply
    @objc private func replyButtonDidClick() {
        
    }
    
    // TODO: Jaymin 需要和 UED 确认下 replyButton 和 footerTimeLabel 布局逻辑
    func configure(showReplyButton: Bool, footerTime: String?) {
        var showFooterTimeLabel = false
        if let footerTime, !footerTime.isEmpty {
            showFooterTimeLabel = true
        }
//        let needRefreshLayout = replyButton.isHidden == showReplyButton || footerTimeLabel.isHidden == showFooterTimeLabel
        
        replyButton.isHidden = !showReplyButton
        footerTimeLabel.text = footerTime
        footerTimeLabel.isHidden = !showFooterTimeLabel
        
//        if needRefreshLayout || isNeedForceRefreshLayout {
//            refreshLayout()
//        }
    }
    
    func refreshTheme() {
        if !replyButton.isHidden {
            replyButton.setTitleColor(Theme.themeBlueColor, for: .normal)
        }
        if !footerTimeLabel.isHidden {
            footerTimeLabel.textColor = Theme.ternaryTextColor
        }
    }
}
