//
//  DTSettingSwitchCell.swift
//  Signal
//
//  Created by hornet on 2023/5/29.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation

class DTSettingDescriptionCell : DTDefaultBaseStyleCell {
    private let  descriptionLabelLayoutConstraintValue : CGFloat = -12
    var descriptionLabelLayoutConstraint : NSLayoutConstraint?
    public lazy var descriptionLabel: UILabel = {
        let descriptionLabel = UILabel()
        descriptionLabel.font = UIFont.ows_dynamicTypeBody
        descriptionLabel.textColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x848E9C) : UIColor.color(rgbHex: 0x848E9C)
        descriptionLabel.textAlignment = .right
        descriptionLabel.numberOfLines = 1
        return descriptionLabel
    }()
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.autoresizingMask = []
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
  
    
    override func applyTheme()  {
        super.applyTheme()
        backgroundColor = Theme.defaultBackgroundColor
        contentView.backgroundColor = Theme.defaultTableCellBackgroundColor
        titleLable.textColor = Theme.primaryTextColor
        descriptionLabel.textColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x848E9C) : UIColor.color(rgbHex: 0x848E9C)
    }
    
    
    override func prepareUI() {
        super.prepareUI()
        contentView.addSubview(descriptionLabel)
    }
    
    override func prepareUILayout() {
        super.prepareUILayout()
        descriptionLabel.autoPinEdge(.left, to: .right, of: titleLable, withOffset: 10)
        descriptionLabelLayoutConstraint = descriptionLabel.autoPinEdge(.right, to: .left, of: accessoryImageView, withOffset: descriptionLabelLayoutConstraintValue)
        descriptionLabel.autoVCenterInSuperview()
    }
    
    override func reloadCell<T: DTSettingItem>(model: T) {
        super.reloadCell(model: model)
        if(model.cellStyle == .onlyDescription) {
            descriptionLabel.isHidden = false
            accessoryImageView.isHidden = true
        } else if(model.cellStyle == .accessoryAndDescription){
            descriptionLabel.isHidden = false
            accessoryImageView.isHidden = false
        } else if(model.cellStyle == .noAccessoryAndNoDescription) {
            descriptionLabel.isHidden = true
            accessoryImageView.isHidden = true
        }  else {
            descriptionLabel.isHidden = false
            accessoryImageView.isHidden = false
        }

        if(model.cellStyle == .onlyDescription){
            if let descriptionLabelLayoutConstraint_t = descriptionLabelLayoutConstraint{
                NSLayoutConstraint.deactivate([descriptionLabelLayoutConstraint_t])
                descriptionLabelLayoutConstraint = descriptionLabel.autoPinEdge(.right, to: .right, of: contentView, withOffset: defaultBaseStyleCellMargin)
                descriptionLabelLayoutConstraint?.isActive = true
            }
        } else {
            if let descriptionLabelLayoutConstraint_t = descriptionLabelLayoutConstraint{
                NSLayoutConstraint.deactivate([descriptionLabelLayoutConstraint_t])
                descriptionLabelLayoutConstraint = descriptionLabel.autoPinEdge(.right, to: .left, of: accessoryImageView, withOffset: descriptionLabelLayoutConstraintValue)
                descriptionLabelLayoutConstraint?.isActive = true
            }
        }
        titleLable.isHidden = false
        titleLable.text = model.title
        descriptionLabel.text = model.description
        applyTheme()
        guard let cellStyle = model.cellStyle else { return }
//        OWSLogger.info("\(String(describing: cellStyle))")
    }
    
}
