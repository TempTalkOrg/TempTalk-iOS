//
//  DTSettingPlanTextCell.swift
//  Signal
//
//  Created by hornet on 2023/7/27.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
class DTSettingPlanTextCell: UITableViewCell {
    var inset: CGFloat = 16.5
    public lazy var planTextLabel: UILabel = {
        let planTextLabel = UILabel()
        planTextLabel.text = "Passkeys enables you to securely and smoothly sign in to your account with Touch ID, Face ID, or hardware security key. To change the passkey, turn it off and turn it on again."
        planTextLabel.numberOfLines = 0
        planTextLabel.textAlignment = .left
        planTextLabel.font = UIFont.systemFont(ofSize: 12)
        return planTextLabel
    }()
    
    override func layoutSubviews() {
        super.layoutSubviews()
//        contentView.frame = contentView.frame.inset(by: UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset))
    }
    var settingItem : DTSettingItem?
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.autoresizingMask = []
        self.prepareUI()
        self.prepareUILayout()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func applyTheme()  {
        backgroundColor = Theme.defaultBackgroundColor
        contentView.backgroundColor = Theme.defaultBackgroundColor
        planTextLabel.textColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xB7BDC6) : UIColor.color(rgbHex: 0x848E9C)
    }
    
    
    func prepareUI() {
        contentView.addSubview(planTextLabel)
    }
    
    func prepareUILayout() {
        planTextLabel.autoPinEdge(toSuperviewMargin: .top)
        planTextLabel.autoPinEdge(toSuperviewMargin: .bottom)
        planTextLabel.autoPinEdge(toSuperviewEdge: .left ,withInset: 16 + inset)
        planTextLabel.autoPinEdge(.right, to: .right, of: contentView, withOffset: -14 - inset)
    }
    
    func reloadCell<T: DTSettingItem>(model: T) {
        self.settingItem = model
        self.planTextLabel.text = model.plainText
        applyTheme()
    }
}
