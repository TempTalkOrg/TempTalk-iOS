//
//  DTHandupGuestHeader.swift
//  Difft
//
//  Created by Ethan on 25/07/2024.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit
import TTMessaging

@objcMembers
class DTHandupGuestHeader: UICollectionReusableView {
        
    static let reuseIdentifier = "DTHandupGuestHeader"
    
    var lbTitle: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupUI() {
       
        layer.cornerRadius = 8
        layer.masksToBounds = true
        layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        backgroundColor = .ows_tabbarNormal
        
        lbTitle = UILabel()
        lbTitle.text = "✋ Speak Request (1)"
        lbTitle.textAlignment = .left
        lbTitle.font = .systemFont(ofSize: 14)
        lbTitle.textColor = .ows_alertCancelDark
        addSubview(lbTitle)
        
        lbTitle.autoPinEdge(toSuperviewEdge: .top, withInset: 12)
        lbTitle.autoPinEdge(toSuperviewEdge: .bottom)
        lbTitle.autoPinEdge(toSuperviewEdge: .leading, withInset: 8)
    }
    
    func updateGuestCount(_ count: UInt) {
        
        var countText = ""
        if count > 999 {
            countText = "999+"
        } else {
            countText = "\(count)"
        }
        
        lbTitle.text = "✋ Speak Request (\(countText))"
    }
    
}


@objcMembers
class DTHandupGuestFooter: UICollectionReusableView {
    
    static let reuseIdentifier = "DTHandupGuestFooter"
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
