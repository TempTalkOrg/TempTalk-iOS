//
//  ConversationUnreadRenderItem.swift
//  Difft
//
//  Created by Jaymin on 2024/7/12.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit

class ConversationUnreadRenderItem: ConversationCellRenderItem {
    static let lineHeight: CGFloat = 1
    static let stackViewSpacing: CGFloat = 2
    
    var titleConfig: CVLabelConfig = .empty
    var contentLayoutMargins: UIEdgeInsets = .zero
    
    override func configure() {
        var title = Localized(
            "MESSAGES_VIEW_UNREAD_INDICATOR",
            comment: "Indicator that separates read from unread messages."
        )
        if (viewItem.shouldShowDate) {
            let date = viewItem.interaction.receivedAtDate()
            let dateString = DateUtil.formatDateHeaderForCVC(date)
            title = dateString.appending(" \u{00B7} ").appending(title)
        }
        titleConfig = .unstyledText(
            title.localizedUppercase,
            font: .systemFont(ofSize: 12),
            numberOfLines: 1,
            lineBreakMode: .byTruncatingTail,
            textAlignment: .center
        )
        
        contentLayoutMargins = UIEdgeInsets(
            top: conversationStyle.headerViewDateHeaderVMargin / 2,
            leading: conversationStyle.headerGutterLeading,
            bottom: conversationStyle.headerViewDateHeaderVMargin / 2,
            trailing: conversationStyle.headerGutterTrailing
        )
        
        self.viewSize = measureSize()
    }
    
    override func dequeueCell(for collectionView: UICollectionView, indexPath: IndexPath) -> UICollectionViewCell {
        collectionView.dequeueReusableCell(withReuseIdentifier: ConversationUnreadIndicatorCell.reuserIdentifier, for: indexPath)
    }
    
    private func measureSize() -> CGSize {
        let viewWidth = conversationStyle.viewWidth
        var height: CGFloat = Self.lineHeight
        height += contentLayoutMargins.top + contentLayoutMargins.bottom

        let availableWidth = viewWidth - contentLayoutMargins.left - contentLayoutMargins.right
        let labelSize = titleConfig.measure(maxWidth: availableWidth)
        if labelSize.height > 0 {
            height += labelSize.height + Self.stackViewSpacing
        }

        return CGSizeCeil(CGSize(width: viewWidth, height: height))
    }
}
