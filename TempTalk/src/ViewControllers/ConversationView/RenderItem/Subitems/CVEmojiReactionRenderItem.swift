//
//  CVEmojiReactionRenderItem.swift
//  Difft
//
//  Created by Jaymin on 2024/8/1.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging

class CVEmojiReactionRenderItem: ConversationRenderItem {
    
    struct EmojiItem {
        let emoji: String
        let frame: CGRect
        let isHighlighted: Bool
    }
    
    var emojiItems: [EmojiItem] = []
    var selectedEmojis: [String] = []
    
    func emojiBackgroundColor(isHighlighted: Bool) -> UIColor {
        let isCardMessage = viewItem.card != nil
        if isCardMessage, !Theme.isDarkThemeEnabled {
            return UIColor(rgbHex: 0xFAFAFA)
        }
        if Theme.isDarkThemeEnabled {
            return .white.withAlphaComponent(isHighlighted ? 0.2 : 0.1)
        }
        return .white.withAlphaComponent(isHighlighted ? 1 : 0.7)
    }
    
    override func configure() {
        if let message = viewItem.interaction as? TSMessage {
            self.selectedEmojis = DTReactionHelper.selectedEmojis(message)
        }
    }
    
    func measureSize(bubbleWidth: CGFloat) -> CGSize {
        guard viewItem.hasEmojiReactionView else {
            emojiItems = []
            return .zero
        }
        
        var newEmojiItems: [EmojiItem] = []
        let emojiTitles = viewItem.emojiTitles
        let baseWidth = conversationStyle.maxMessageWidth - conversationStyle.textInsetHorizontal
        
        let HMargin: CGFloat = 10
        let VMargin: CGFloat = 10
        let lbHeight: CGFloat = 24
        var totalWidth: CGFloat = 0
        var finalWidth: CGFloat = 0
        var column: CGFloat = 0
        var row: CGFloat = 0
        
        emojiTitles.enumerated().forEach { index, emoji in
            let emojiSize = measureEmojiSize(emoji)
            let frame = CGRectMake(
                (column == 0 ? 0 : HMargin + totalWidth), 
                (lbHeight + 10) * row,
                emojiSize.width,
                lbHeight
            )
            totalWidth = CGRectGetMaxX(frame)
            
            let formattedEmoji = emoji.components(separatedBy: " ").first ?? emoji
            let isHighlighted = selectedEmojis.contains(formattedEmoji)
            let emojiItem = EmojiItem(emoji: emoji, frame: frame, isHighlighted: isHighlighted)
            newEmojiItems.append(emojiItem)
            
            column += 1
            var nextSize: CGSize = .zero
            if index < emojiTitles.count - 1 {
                nextSize = measureEmojiSize(emojiTitles[index+1])
            }
            let nextWidth = nextSize.width
            if totalWidth + HMargin + nextWidth > baseWidth {
                finalWidth = max(finalWidth, totalWidth)
                if nextWidth > 0 {
                    row += 1
                    column = 0
                    totalWidth = 0
                }
            } else {
                finalWidth = max(finalWidth, totalWidth)
            }
        }
        
        self.emojiItems = newEmojiItems
        
        finalWidth += conversationStyle.textInsetHorizontal * 2
        let finalHeight = row * (lbHeight + VMargin) + lbHeight
        
        return CGSizeMake(max(finalWidth, bubbleWidth), finalHeight)
    }
    
    private func measureEmojiSize(_ emoji: String) -> CGSize {
        let font = UIFont.systemFont(ofSize: 13)
        let pointSize = font.pointSize
        let lbHeight: CGFloat = 24
        var contentSize = (emoji as NSString).boundingRect(
            with: CGSizeMake(.infinity, lbHeight),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).size
        let finalWidth: CGFloat = min(contentSize.width, pointSize * 8)
        contentSize.width = finalWidth + 13
        return contentSize
    }
    
}
