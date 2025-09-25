//
//  DTConfideMessageCell.swift
//  Signal
//
//  Created by hornet on 2023/2/9.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
import TTMessaging


@objc protocol ConfideMessageCellDelegate: NSObjectProtocol {
   /**
    Tap the item with index
    */
   func floatViewTapItemIndex(_ type: ActionFloatViewItemType)
   func floatViewDidRemoveFromSuperView()
}

class DTConfideMessageCell : UITableViewCell {
    
    private lazy  var privateLable = {
        let contentLabel = UILabel()
        contentLabel.textColor = Theme.primaryTextColor
        contentLabel.textAlignment = NSTextAlignment.left
        contentLabel.font = UIFont.systemFont(ofSize: 18)
        contentLabel.isUserInteractionEnabled = true
        contentLabel.numberOfLines = 1
        return contentLabel;
    }()
    
    private lazy  var effectMaskView = {
       let maskView = UIView()
        maskView.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xB7BDC6) : UIColor.color(rgbHex: 0x5E6673)
        maskView.layer.cornerRadius = 5
        maskView.clipsToBounds = true
        return maskView
    }()
    @objc weak var delegate: ConfideMessageCellDelegate?

    func reloadWithMessage(messageText: String?) {
        self.privateLable.text = messageText
    }
    
    static func confideMessageCellIdentifier() -> String {
        return "confideMessageCellIdentifier"
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        autolayout()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupUI()  {
        backgroundColor = UIColor.clear
        contentView.backgroundColor = UIColor.clear
        contentView.addSubview(privateLable)
        contentView.addSubview(effectMaskView)
    }
    
    func autolayout (){
        privateLable.autoVCenterInSuperview()
        privateLable.autoPinLeading(toEdgeOf: contentView, offset: 24)
        privateLable.autoPinTrailing(toEdgeOf: contentView, offset: -24)
        privateLable.autoSetDimension(ALDimension.height, toSize: 30)
        privateLable.backgroundColor = UIColor.clear

        effectMaskView.autoVCenterInSuperview()
        effectMaskView.autoPinLeading(toEdgeOf: contentView, offset: 24)
        effectMaskView.autoPinTrailing(toEdgeOf: contentView, offset: -24)
        effectMaskView.autoSetDimension(ALDimension.height, toSize: 30)
    }
    func showDetailMessage() {
        self.effectMaskView.isHidden = true
    }
    func hideDetailMessage() {
        self.effectMaskView.isHidden = false
    }
    @objc private func tapGestureEvent(tap: UITapGestureRecognizer) {
        if(tap.state == .ended){
            OWSLogger.debug("tapGestureEvent")
        }
    }
}
