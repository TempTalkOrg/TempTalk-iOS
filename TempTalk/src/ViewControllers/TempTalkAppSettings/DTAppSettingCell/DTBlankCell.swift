//
//  DTBlankCell.swift
//  Signal
//
//  Created by hornet on 2023/5/29.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation

class DTBlankCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.autoresizingMask = []
        self.prepareUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func applyTheme()  {
        backgroundColor = Theme.defaultBackgroundColor
        contentView.backgroundColor = Theme.defaultBackgroundColor
    }
    
    func prepareUI () {
        backgroundColor = Theme.defaultBackgroundColor
        contentView.backgroundColor = Theme.defaultBackgroundColor
    }
    
}
