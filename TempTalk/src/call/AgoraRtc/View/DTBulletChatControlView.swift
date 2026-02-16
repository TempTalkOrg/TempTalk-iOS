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

        let tap = UITapGestureRecognizer(target: self, action: #selector(startInputAction))
        addGestureRecognizer(tap)

        chatIcon.autoCenterInSuperview()
        chatIcon.autoSetDimensions(to: CGSize(width: 20, height: 20))
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: 40, height: 40)
    }
    
    private let chatIcon: UIImageView = {
        let chatIcon = UIImageView(image: UIImage(named: "ic_meeting_smile"))

        return chatIcon
    }()
    
    @objc func startInputAction() {

        guard let delegate = delegate else {
            return
        }
        guard delegate.responds(to: #selector(DTBulletChatControlDelegate.bulletChatControlDidClickInput(draft:))) else {
            return
        }

        delegate.bulletChatControlDidClickInput(draft: nil)
    }
    
}
