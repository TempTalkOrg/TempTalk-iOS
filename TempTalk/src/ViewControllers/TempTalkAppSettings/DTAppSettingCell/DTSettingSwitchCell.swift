//
//  DTSettingSwitchCell.swift
//  Signal
//
//  Created by hornet on 2023/5/29.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation

@objc protocol DTSettingSwitchCellDelegate: AnyObject {
    @objc optional func switchValueChanged(isOn: Bool, cell: DTDefaultBaseStyleCell)
}

class DTSettingSwitchCell : DTDefaultBaseStyleCell {
    weak var delegate: DTSettingSwitchCellDelegate?
    public lazy var switchButton: UISwitch = {
        let switchButton = UISwitch()
        switchButton.sizeToFit()
        switchButton.addTarget(self, action: #selector(switchValueChanged), for: .valueChanged)
        return switchButton
    }()
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        showAccessoryImageView = false
        contentView.autoresizingMask = []
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func reloadCell<T: DTSettingItem>(model: T) {
        super.reloadCell(model: model)
        switchButton.isOn = model.openSwitch ?? false
        applyTheme()
        
    }
    
    override func applyTheme()  {
        super.applyTheme()
        
        backgroundColor = Theme.defaultBackgroundColor
        contentView.backgroundColor = Theme.defaultTableCellBackgroundColor
    }
    
    
    override func prepareUI() {
        super.prepareUI()
        contentView.addSubview(switchButton)
    }
    
    override func prepareUILayout() {
        super.prepareUILayout()
        switchButton.autoPinEdge(.right, to: .right, of: contentView, withOffset: -14)
        switchButton.autoVCenterInSuperview()
    }
    
    @objc func switchValueChanged() {
        delegate?.switchValueChanged?(isOn: switchButton.isOn, cell: self)
    }
}
