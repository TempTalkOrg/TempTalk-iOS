//
//  DTSettingCheckCell.swift
//  Signal
//
//  Created by hornet on 2023/6/1.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

class DTSettingCheckBoxCell : DTDefaultBaseStyleCell {
    let checkBoxImageViewSize : CGFloat = 20
    public lazy var checkBoxImageView: UIImageView = {
        let checkBoxImageView = UIImageView()
        checkBoxImageView.image = UIImage(named: "check_box_selected")
        return checkBoxImageView
    }()
    var showCheckBox: Bool = false {
        didSet {
            
        }
    }
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.autoresizingMask = []
        self.accessoryImageView.isHidden = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func applyTheme()  {
        super.applyTheme()
        backgroundColor = Theme.defaultBackgroundColor
        contentView.backgroundColor = Theme.defaultTableCellBackgroundColor
        titleLable.textColor = Theme.primaryTextColor
    }
    
    
    override func prepareUI() {
        super.prepareUI()
        contentView.addSubview(checkBoxImageView)
    }
    
    override func prepareUILayout() {
        super.prepareUILayout()
        
        checkBoxImageView.autoPinEdge(.right, to: .right, of: contentView , withOffset: defaultBaseStyleCellMargin)
        checkBoxImageView.autoSetDimension(.width, toSize: checkBoxImageViewSize)
        checkBoxImageView.autoSetDimension(.height, toSize: checkBoxImageViewSize)
        checkBoxImageView.autoVCenterInSuperview()
    }
    
    override func reloadCell<T: DTSettingItem>(model: T) {
        super.reloadCell(model: model)
        ///目前这个地方没有能够与与业务层解耦合，待调整
        if let model_t = model as? DTThemeSettingItem , Theme.getOrFetchCurrentTheme() == model_t.themeMode {
            checkBoxImageView.isHidden = false
            
        } else if let model_t = model as? DTLanguageSettingItem  {
            let userPreferenceLanguage = Localize.userPreferenceLanguage()
            if let languageType = model_t.languageType?.rawValue as? String {
                if(userPreferenceLanguage.hasPrefix(languageType)){
                    checkBoxImageView.isHidden = false
                } else {
                    checkBoxImageView.isHidden = true
                }
            }else {
                checkBoxImageView.isHidden = true
            }
        } else {
            
            checkBoxImageView.isHidden = true
        }
        applyTheme()
    }
    
}
