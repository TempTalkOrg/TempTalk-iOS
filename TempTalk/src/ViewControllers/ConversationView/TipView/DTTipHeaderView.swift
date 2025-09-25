//
//  DTTipHeaderView.swift
//  Signal
//
//  Created by hornet on 2022/7/7.
//  Copyright © 2022 Difft. All rights reserved.
//

import Foundation
import UIKit
import PureLayout
import TTMessaging
class DTRemindView : UIView {
    
    public var tipString: String = Localized("CONVERSATION_SETTINGS_STICKY_BLOCK_HEADER_TIP", comment: "")  {
        didSet {
            self.tipMessageLabel.text = tipString;
        }
    }
    
    public var icon: UIImage?  {
        didSet {
            self.iconView.image = icon;
        }
    }
    
     lazy var stackContainView: UIStackView = {
        let stackContainView = UIStackView.init()
        stackContainView.axis = .horizontal
        stackContainView.alignment = .top
        stackContainView.spacing = 5
        stackContainView.distribution = .fillProportionally
        return stackContainView
    }()
    
    lazy var iconView: UIImageView = {
        let iconView = UIImageView()
        return iconView
    }()
    
    lazy var iconLabel: UILabel = {
        let iconLabel = UILabel()
        iconLabel.text = commonString()
        iconLabel.font = UIFont.systemFont(ofSize: 12)
        iconLabel.sizeToFit()
        return iconLabel
    }()
    
    
    lazy var tipMessageLabel: UILabel = {
        let tipMessageLabel = UILabel()
        tipMessageLabel.textColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xEAECEF): UIColor.color(rgbHex: 0x1E2329)
        tipMessageLabel.font = UIFont.systemFont(ofSize: 12)
        tipMessageLabel.text = tipString
        tipMessageLabel.textAlignment = .left
        tipMessageLabel.numberOfLines = 0
        return tipMessageLabel
    }()
    @objc
     func applyTheme() {
        tipMessageLabel.textColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xEAECEF): UIColor.color(rgbHex: 0x1E2329)
        self.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x1E2329) : UIColor.color(rgbHex: 0xFAFAFA)
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        initCommonUI()
        configUILayout()
        self.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x1E2329) : UIColor.color(rgbHex: 0xFAFAFA)
        self.iconView.isHidden = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func initCommonUI() {
        addSubview(stackContainView)
        stackContainView.addArrangedSubview(iconView)
        stackContainView.addArrangedSubview(iconLabel)
        stackContainView.addArrangedSubview(tipMessageLabel)
    }
    
    func configUILayout() {
        iconLabel.autoSetDimension(ALDimension.height, toSize: 14)
        iconLabel.autoSetDimension(ALDimension.width, toSize: 16)
        iconLabel.setCompressionResistanceHigh()
        iconLabel.setContentHuggingHigh()
        
        stackContainView.autoPinEdge(ALEdge.top, to: ALEdge.top, of: self, withOffset: 12)
        stackContainView.autoPinEdge(ALEdge.left, to: ALEdge.left, of: self, withOffset: 16)
        stackContainView.autoPinEdge(ALEdge.right, to: ALEdge.right, of: self, withOffset: -16)
        stackContainView.autoPinEdge(ALEdge.bottom, to: ALEdge.bottom, of: self, withOffset: -12)
    }
    
    func commonString() -> String {
        return "🚫"
    }
}

