//
//  DTCheckbox.swift
//  TTMessaging
//
//  Created by Ethan on 29/08/2023.
//  Copyright © 2023 Difft. All rights reserved.
//

import UIKit

public class DTCheckbox: UIView {
    
    public var isSelected: Bool = false {
        willSet {
            isUserInteractionEnabled = true
            button.isSelected = newValue
            if newValue == true {
                icon.image = UIImage(named: "ic_checkbox_selected")
            } else {
                icon.image = UIImage(named: "ic_checkbox_unselected")
            }
        }
    }
    
    public var isUnselectedDisabled: Bool = false {
        willSet {
            isUserInteractionEnabled = !newValue
            if newValue == true {
                let disableImage = UIImage(named: "ic_checkbox_disable")?.withRenderingMode(.alwaysTemplate)
                icon.image = disableImage
            }
        }
    }
    
    public var isSelectedDisabled: Bool = false {
        willSet {
            isUserInteractionEnabled = !newValue
            if newValue == true {
                let disableImage = Theme.isDarkThemeEnabled ? UIImage(named: "ic_checkbox_selected_disable_dark") : UIImage(named: "ic_checkbox_selected_disable")
                icon.image = disableImage
            }
        }
    }
    
    private weak var _target: AnyObject?
    private var _action: Selector?
    private var icon: UIImageView!
    private var button: UIButton!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func applyTheme() {
        icon.tintColor = Theme.hairlineColor
    }
    
    func setupUI() {
        
        icon = UIImageView(image: #imageLiteral(resourceName: "ic_checkbox_unselected"))
        addSubview(icon!)
        
        button = UIButton(type: .custom)
        button.addTarget(self, action: #selector(buttonAction(_:)), for: .touchUpInside)
        addSubview(button)
        
        icon.autoCenterInSuperview()
        icon.autoSetDimensions(to: CGSize(square: 16))
        button.autoPinEdgesToSuperviewEdges()
        
        applyTheme()
    }
    
    @objc
    func buttonAction(_ button: UIButton) {
        
        button.isSelected = !button.isSelected
        isSelected = button.isSelected
        guard let _target, let _action else {
            return
        }
        _ = (_target as AnyObject).perform(_action)
    }
        
    public func addTarget(_ target: AnyObject, action: Selector) {
        
        _target = target
        _action = action
    }
    
}
