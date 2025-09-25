//
//  ConversationJoinCallView.swift
//  Difft
//
//  Created by Henry on 2025/8/19.
//  Copyright © 2025 Difft. All rights reserved.
//

import UIKit
import PureLayout

class ConversationJoinCallView: UIView {
    
    let avatarView = AvatarImageView()
    let textLabel = UILabel()
    let joinButton = UIButton(type: .system)
    private let separatorLine = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
        setupConstraints()
    }
    
    private func setupViews() {
        self.backgroundColor = UIColor(rgbHex: Theme.isDarkThemeEnabled ? 0x181A20 : 0xFFFFFF)
        
        // 头像
        avatarView.layer.cornerRadius = 14
        avatarView.clipsToBounds = true
        avatarView.contentMode = .scaleAspectFill
        addSubview(avatarView)
        
        // 文本
        textLabel.font = UIFont.systemFont(ofSize: 14)
        textLabel.textColor = UIColor(rgbHex: Theme.isDarkThemeEnabled ? 0xEAECEF : 0x1E2329)
        textLabel.numberOfLines = 1
        textLabel.lineBreakMode = .byTruncatingTail
        addSubview(textLabel)
        
        // Join 按钮
        joinButton.setTitle("Join", for: .normal)
        joinButton.titleLabel?.font = UIFont.regularFont(ofSize: 12)
        joinButton.backgroundColor = UIColor.color(rgbHex: 0x056FFA)
        joinButton.setTitleColor(.white, for: .normal)
        joinButton.layer.cornerRadius = 4
        joinButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        addSubview(joinButton)
        
        // 分割线
        separatorLine.backgroundColor = UIColor(rgbHex: Theme.isDarkThemeEnabled ? 0x2B3139 : 0xEAECEF)
        addSubview(separatorLine)
    }
    
    private func setupConstraints() {
        // 头像
        avatarView.autoPinEdge(toSuperviewEdge: .left, withInset: 16)
        avatarView.autoAlignAxis(toSuperviewAxis: .horizontal)
        avatarView.autoSetDimensions(to: CGSize(width: 28, height: 28))
        
        // Join 按钮
        joinButton.autoPinEdge(toSuperviewEdge: .right, withInset: 16)
        joinButton.autoAlignAxis(toSuperviewAxis: .horizontal)
        joinButton.autoSetDimensions(to: CGSize(width: 40, height: 24))
        
        // 文本
        textLabel.autoPinEdge(.left, to: .right, of: avatarView, withOffset: 12)
        textLabel.autoPinEdge(.right, to: .left, of: joinButton, withOffset: -12)
        textLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        // 分割线
        separatorLine.autoPinEdge(toSuperviewEdge: .left)
        separatorLine.autoPinEdge(toSuperviewEdge: .right)
        separatorLine.autoPinEdge(toSuperviewEdge: .bottom)
        separatorLine.autoSetDimension(.height, toSize: 0.5) // 细线
    }
}
