//
//  ConversationCell.swift
//  Signal
//
//  Created by Jaymin on 2024/4/16.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit

protocol Themeable {
    func refreshTheme()
}

class ConversationCell: UICollectionViewCell, Themeable {
    
    var isCellVisible = false {
        didSet {
            guard isCellVisible != oldValue else {
                return
            }
            if isCellVisible {
                layoutIfNeeded()
            }
        }
    }
    
    func refreshTheme() {}
}

class ConversationUnknownCell: ConversationCell {
    @objc
    static let reuserIdentifier = "ConversationUnknownCell"
}
