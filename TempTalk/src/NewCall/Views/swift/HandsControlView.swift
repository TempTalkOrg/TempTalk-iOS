//
//  HandsControlView.swift
//  Difft
//
//  Created by Henry on 2025/7/2.
//  Copyright © 2025 Difft. All rights reserved.
//

import PanModal

@objcMembers
class HandsControlView: UIView {
    
    var onTap: (() -> Void)?
    
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
        chatIcon.autoSetDimensions(to: CGSize(width: 16, height: 16))
        
        lbMessage.autoPinEdge(toSuperviewEdge: .top)
        lbMessage.autoPinEdge(toSuperviewEdge: .bottom)
        lbMessage.autoPinEdge(.leading, to: .trailing, of: chatIcon, withOffset: 8)
        lbMessage.autoPinEdge(toSuperviewEdge: .trailing, withInset: 8)
    }
    
    private let chatIcon: UIImageView = {
        let chatIcon = UIImageView(image: UIImage(named: "tabler_hand_lower"))
        return chatIcon
    }()
    
    private let lbMessage: UILabel = {
        let lbMessage = UILabel()
        lbMessage.textColor = UIColor(rgbHex: 0xEAECEF)
        lbMessage.font = .systemFont(ofSize: 15.0, weight: .medium)
        lbMessage.isUserInteractionEnabled = true
        lbMessage.numberOfLines = 1;
        
        return lbMessage
    }()
    
    public func updateContents() {
        let participantIds = RoomDataManager.shared.handsData
        let contactsManager = Environment.shared.contactsManager
        let names = participantIds.compactMap { pid in
            contactsManager?.displayName(forPhoneIdentifier: pid)
        }
        lbMessage.text = names.joined(separator: ", ")
    }
    
    @objc func startInputAction() {
        // 点击举手的视图
        if DTMeetingManager.shared.isPresentedShare() {
            onTap?() // 回调传出
        } else {
            DTMeetingManager.shared.presentRaiseHandVC()
        }
    }
    
}
