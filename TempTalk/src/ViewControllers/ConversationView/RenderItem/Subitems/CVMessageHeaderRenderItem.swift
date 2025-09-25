//
//  CVMessageHeaderRenderItem.swift
//  Difft
//
//  Created by Jaymin on 2024/7/30.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging

class CVMessageHeaderRenderItem: ConversationRenderItem {
    
    static let bottomPadding: CGFloat = 16
    
    var dateText: String?
    
    override func configure() {
        let date = viewItem.interaction.dateForSorting()
        self.dateText = DateUtil.formatDateForConversationHeader(date)
        
        let dateLabelHeight: CGFloat = 28
        let height = Self.bottomPadding + dateLabelHeight
        self.viewSize = CGSizeCeil(CGSize(
            width: conversationStyle.viewWidth,
            height: height
        ))
    }
}
