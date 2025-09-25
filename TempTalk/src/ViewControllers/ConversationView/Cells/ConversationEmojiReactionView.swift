//
//  ConversationEmojiReactionView.swift
//  Difft
//
//  Created by Jaymin on 2024/8/2.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

protocol ConversationEmojiReactionViewDelegate: AnyObject {
    func reactionView(_ reactionView: ConversationEmojiReactionView, didTapWith emoji: String)
    func reactionView(_ reactionView: ConversationEmojiReactionView, didLongPressWith emoji: String)
}

class ConversationEmojiReactionView: UIView, Themeable {
    
    private var emojiLabels: [UILabel] = []
    private var renderItem: CVEmojiReactionRenderItem?
    
    weak var delegate: ConversationEmojiReactionViewDelegate?
    
    func configure(renderItem: CVEmojiReactionRenderItem) {
        self.renderItem = renderItem
        
        subviews.forEach { $0.removeFromSuperview() }
        emojiLabels.removeAll()
        
        var labels: [UILabel] = []
        renderItem.emojiItems.enumerated().forEach { index, item in
            let label = DTReactionLabel.lable(withEmojiTitle: item.emoji)
            label.isHighlighted = item.isHighlighted
            label.font = item.isHighlighted ? .systemFont(ofSize: 12, weight: .medium) : .systemFont(ofSize: 12, weight: .regular)
            label.layer.borderWidth = item.isHighlighted ? 1 : 0
            label.tag = index
            
            addSubview(label)
            label.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(item.frame.origin.y)
                make.leading.equalToSuperview().offset(item.frame.origin.x)
                make.width.equalTo(item.frame.size.width)
                make.height.equalTo(item.frame.size.height)
            }
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(didTapEmoji(_:)))
            label.addGestureRecognizer(tap)
            
            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPressEmoji(_:)))
            label.addGestureRecognizer(longPress)
            
            labels.append(label)
        }
        emojiLabels = labels
        
        refreshTheme()
    }
    
    @objc
    private func didTapEmoji(_ sender: UITapGestureRecognizer) {
        guard let emojiItems = renderItem?.emojiItems else { return }
        guard let tag = sender.view?.tag else { return }
        guard let emojiItem = emojiItems[safe: tag] else { return }
        guard let emoji = emojiItem.emoji.components(separatedBy: " ").first else { return }
        
        delegate?.reactionView(self, didTapWith: emoji)
    }
    
    @objc
    private func didLongPressEmoji(_ sender: UILongPressGestureRecognizer) {
        guard let emojiItems = renderItem?.emojiItems else { return }
        guard let tag = sender.view?.tag else { return }
        guard let emojiItem = emojiItems[safe: tag] else { return }
        guard let emoji = emojiItem.emoji.components(separatedBy: " ").first else { return }
        
        delegate?.reactionView(self, didLongPressWith: emoji)
    }
    
    func refreshTheme() {
        emojiLabels.forEach {
            $0.textColor = Theme.primaryTextColor
            $0.layer.borderColor = (Theme.isDarkThemeEnabled ? UIColor(rgbHex: 0x82C1FC) : .ows_themeBlue).cgColor
            $0.backgroundColor = renderItem?.emojiBackgroundColor(isHighlighted: $0.isHighlighted)
        }
    }
}
