//
//  DTBulletChatControlView.swift
//  Wea
//
//  Created by Ethan on 2022/8/2.
//  Copyright © 2022 Difft. All rights reserved.
//

import UIKit

@objc protocol DTBulletChatControlDelegate: NSObjectProtocol {
    
    func bulletChatControlDidClickInput(draft: String?)
}

@objcMembers
class DTBulletChatControlView: UIView {
    
    @objc weak var delegate: DTBulletChatControlDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupUI() {
        
        backgroundColor = UIColor(rgbHex: 0x1E2329).withAlphaComponent(0.9)
        layer.cornerRadius = 8.0
        layer.masksToBounds = true
        layer.borderWidth = 1.0
        layer.borderColor = UIColor.color(rgbHex: 0x32363E).cgColor
        
        addSubview(chatIcon)
        addSubview(lbMessage)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(startInputAction))
        lbMessage.addGestureRecognizer(tap)
        
        chatIcon.autoAlignAxis(toSuperviewAxis: .horizontal)
        chatIcon.autoPinEdge(toSuperviewEdge: .leading, withInset: 12)
        chatIcon.autoSetDimensions(to: CGSize(width: 20, height: 20))
        
        lbMessage.autoPinEdge(toSuperviewEdge: .top)
        lbMessage.autoPinEdge(toSuperviewEdge: .bottom)
        lbMessage.autoPinEdge(.leading, to: .trailing, of: chatIcon, withOffset: 8)
        lbMessage.autoPinEdge(toSuperviewEdge: .trailing, withInset: 16)
    }
    
    private let chatIcon: UIImageView = {
        let chatIcon = UIImageView(image: UIImage(named: "ic_meeting_chat1"))
        
        return chatIcon
    }()
    
    private let lbMessage: UILabel = {
        let lbMessage = UILabel()
        lbMessage.text = Localized("MEETING_SEND_ALL")
        lbMessage.textColor = UIColor(rgbHex: 0x5E6673)
        lbMessage.font = .systemFont(ofSize: 14.0, weight: .medium)
        lbMessage.isUserInteractionEnabled = true
        
        return lbMessage
    }()
    
    @objc func startInputAction() {
        
        guard let delegate = delegate else {
            return
        }
        guard delegate.responds(to: #selector(DTBulletChatControlDelegate.bulletChatControlDidClickInput(draft:))) else {
            return
        }
        
        delegate.bulletChatControlDidClickInput(draft: lbMessage.text?.stripped)
    }
    
}
