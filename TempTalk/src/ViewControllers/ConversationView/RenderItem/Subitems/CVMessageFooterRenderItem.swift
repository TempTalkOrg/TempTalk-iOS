//
//  CVMessageFooterRenderItem.swift
//  Difft
//
//  Created by Jaymin on 2024/7/30.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

class CVMessageFooterRenderItem: ConversationRenderItem {
    
    static let footerViewHeight: CGFloat = 20
    static let footerViewSpace: CGFloat = 10
    
    var footerViewTitle: String?
    
    override func configure() {
        self.footerViewTitle = {
            guard viewItem.isLastInCluster else {
                return nil
            }
            // 3.1.1 replace timestamp with timestampForSorting
            let timestampText = DateUtil.formatTimestampForConversationMessage(viewItem.interaction.timestampForSorting())
            return timestampText
        }()
        self.viewSize = CGSize(width: conversationStyle.viewWidth, height: Self.footerViewHeight)
    }
    
    static func footerWidth(viewItem: ConversationViewItem, footerViewTitle: String?) -> CGFloat {
        
        var titleWidth = 0.0
        var elementCount = 0
        if viewItem.interaction is TSOutgoingMessage {
            titleWidth += 12
            elementCount += 1
        }
        if viewItem.isLastInCluster,
            let footerViewTitle {
            titleWidth += calculateTextWidth(text: footerViewTitle, font: UIFont.systemFont(ofSize: 12.0))
            elementCount += 1
        }
        if elementCount == 0 {
            return 0
        } else if elementCount == 1 {
            return titleWidth + 2 * footerViewSpace
        } else if elementCount == 2 {
            return titleWidth + 2 * footerViewSpace + 4
        }
        return 0
    }
    
    static func calculateTextWidth(text: String, font: UIFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        
        let textSize = (text as NSString).boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            attributes: attributes,
            context: nil
        ).size
        
        return textSize.width
    }
    
}
