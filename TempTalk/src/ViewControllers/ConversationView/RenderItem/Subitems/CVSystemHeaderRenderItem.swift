//
//  CVSystemHeaderRenderItem.swift
//  Difft
//
//  Created by Jaymin on 2024/7/25.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit

class CVSystemHeaderRenderItem: ConversationRenderItem {
    
    static let strokeThickness: CGFloat = 1
    static let stackViewSpacing: CGFloat = 2
    
    var titleConfig: CVLabelConfig = .empty
    var subtitleConfig: CVLabelConfig? = nil
    
    override func configure() {
        let date = viewItem.interaction.dateForSorting()
        let dateString = DateUtil.formatDateForConversationHeader(date)
        
        guard let unreadIndicator = viewItem.unreadIndicator else {
            titleConfig = .unstyledText(
                dateString,
                font: .ows_dynamicTypeCaption1,
                textColor: .ows_lightGray01,
                numberOfLines: 1,
                lineBreakMode: .byTruncatingTail,
                textAlignment: .center
            )
            subtitleConfig = nil
            return
        }
        
        var title = Localized("MESSAGES_VIEW_UNREAD_INDICATOR")
        if (viewItem.shouldShowDate) {
            title = ((dateString as NSString).rtlSafeAppend(" \u{00B7} ") as NSString).rtlSafeAppend(title)
        }
        titleConfig = .unstyledText(
            title,
            font: .ows_dynamicTypeCaption1,
            textColor: .ows_black01,
            numberOfLines: 1,
            lineBreakMode: .byTruncatingTail,
            textAlignment: .center
        )
        
        if unreadIndicator.hasMoreUnseenMessages {
            let subtitle = unreadIndicator.missingUnseenSafetyNumberChangeCount > 0 ? Localized("MESSAGES_VIEW_UNREAD_INDICATOR_HAS_MORE_UNSEEN_MESSAGES") : Localized("MESSAGES_VIEW_UNREAD_INDICATOR_HAS_MORE_UNSEEN_MESSAGES_AND_SAFETY_NUMBER_CHANGES")
            subtitleConfig = .unstyledText(
                subtitle,
                font: .ows_dynamicTypeCaption1,
                textColor: .ows_black01,
                numberOfLines: 0,
                lineBreakMode: .byWordWrapping,
                textAlignment: .center
            )
        } else {
            subtitleConfig = nil
        }
        
        self.viewSize = measureSize()
    }
    
    func measureSize() -> CGSize {
        var height: CGFloat = 0
        let strokeThickness: CGFloat = 1.0
        height += strokeThickness
        
        let maxTextWidth = conversationStyle.viewWidth
        let titleHeight = titleConfig.measure(maxWidth: maxTextWidth).height
        height += titleHeight + Self.stackViewSpacing
        
        if let subtitleConfig {
            let subtitleHeight = subtitleConfig.measure(maxWidth: maxTextWidth).height
            height += subtitleHeight + Self.stackViewSpacing
        }
        
        height += OWSMessageHeaderViewDateHeaderVMargin
        
        return CGSizeCeil(CGSize(width: maxTextWidth, height: height))
    }
}
