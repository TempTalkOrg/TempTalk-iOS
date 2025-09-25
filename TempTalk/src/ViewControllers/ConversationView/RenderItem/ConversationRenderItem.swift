//
//  ConversationRenderItem.swift
//  Difft
//
//  Created by Jaymin on 2024/7/12.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

class ConversationRenderItem: NSObject {
    var uniqueId: String { viewItem.interaction.uniqueId }
    
    var viewItem: ConversationViewItem
    
    var conversationStyle: ConversationStyle
    
    var viewSize: CGSize = .zero
    
    var isIncomingMessage: Bool {
        viewItem.interaction.interactionType() == .incomingMessage
    }
    
    var isOutgoingMessage: Bool {
        viewItem.interaction.interactionType() == .outgoingMessage
    }
    
    init(viewItem: ConversationViewItem, conversationStyle: ConversationStyle) {
        self.viewItem = viewItem
        self.conversationStyle = conversationStyle
        
        super.init()
        
        configure()
    }
    
    // Need subclasses override.
    // Configure render properites, measure size.
    func configure() {}
}

class ConversationCellRenderItem: ConversationRenderItem {
    
    // Need Subclass Override
    func dequeueCell(for collectionView: UICollectionView, indexPath: IndexPath) -> UICollectionViewCell {
        collectionView.dequeueReusableCell(withReuseIdentifier: ConversationUnknownCell.reuserIdentifier, for: indexPath)
    }
    
}

extension ConversationCellRenderItem: ConversationViewLayoutItem {
    var interaction: TSInteraction { viewItem.interaction }
    
    var cellSize: CGSize {
        viewSize
    }
    
    func vSpacing(previousLayoutItem: any ConversationViewLayoutItem) -> CGFloat {
        if viewItem.hasCellHeader {
            return OWSMessageHeaderViewDateHeaderVMargin
        }
        
        // "Bubble Collapse".  Adjacent messages with the same author should be close together.
        if let currentMessage = interaction as? TSIncomingMessage,
           let previousMessage = previousLayoutItem.interaction as? TSIncomingMessage {
            if currentMessage.authorId == previousMessage.authorId {
                return 5
            }
            
        } else if let _ = interaction as? TSOutgoingMessage,
                  let _ = previousLayoutItem.interaction as? TSOutgoingMessage {
            return 5
        }
        
        return 12
    }
}
