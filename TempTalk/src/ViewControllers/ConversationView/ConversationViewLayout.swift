//
//  ConversationViewLayout.swift
//  Difft
//
//  Created by Jaymin on 2024/7/12.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit

protocol ConversationViewLayoutItem {
    
    var cellSize: CGSize { get }
    
    var interaction: TSInteraction { get }
    
    func vSpacing(previousLayoutItem: ConversationViewLayoutItem) -> CGFloat
}

protocol ConversationViewLayoutDelegate: AnyObject {
    
    var layoutItems: [ConversationViewLayoutItem] { get }
    
    var layoutHeaderHeight: CGFloat { get }
    var layoutFooterHeight: CGFloat { get }
}

class ConversationViewLayout: UICollectionViewLayout {
    
    private var conversationStyle: ConversationStyle
    
    private var hasLayout = false
    
    private var contentSize: CGSize = .zero
    private var lastViewWidth: CGFloat = .zero
    
    private var itemAttributesMap: [Int: UICollectionViewLayoutAttributes] = [:]
    private var headerLayoutAttributes: UICollectionViewLayoutAttributes?
    private var footerLayoutAttributes: UICollectionViewLayoutAttributes?
    
    weak var delegate: ConversationViewLayoutDelegate?
    
    init(conversationStyle: ConversationStyle) {
        self.conversationStyle = conversationStyle
        
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func invalidateLayout() {
        super.invalidateLayout()
        
        clearState()
    }
    
    override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
        super.invalidateLayout(with: context)
        
        clearState()
    }
    
    override func prepare() {
        super.prepare()
        
        guard let delegate else {
            owsFailDebug("ConversationViewLayout missing delegate")
            clearState()
            return
        }
        
        guard let collectionView, collectionView.width > 0, collectionView.height > 0 else {
            owsFailDebug("CollectionView has invalid size: \(collectionView?.bounds ?? CGRect.zero)")
            clearState()
            return
        }
        
        guard !hasLayout else {
            return
        }
        clearState()
        hasLayout = true
        
        prepareLayoutOfItems()
    }
    
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        
        var result: [UICollectionViewLayoutAttributes] = []
        
        if let headerLayoutAttributes, CGRectIntersectsRect(rect, headerLayoutAttributes.frame) {
            result.append(headerLayoutAttributes)
        }
        itemAttributesMap.forEach { _, itemAttributes in
            if CGRectIntersectsRect(rect, itemAttributes.frame) {
                result.append(itemAttributes)
            }
        }
        if let footerLayoutAttributes, CGRectIntersectsRect(rect, footerLayoutAttributes.frame) {
            result.append(footerLayoutAttributes)
        }
        
        return result
    }
    
    override func layoutAttributesForSupplementaryView(ofKind elementKind: String, at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        switch elementKind {
        case UICollectionView.elementKindSectionHeader:
            return headerLayoutAttributes
        case UICollectionView.elementKindSectionFooter:
            return footerLayoutAttributes
        default:
            return nil
        }
    }
    
    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        itemAttributesMap[indexPath.row]
    }
    
    override var collectionViewContentSize: CGSize {
        contentSize
    }
    
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        lastViewWidth != newBounds.size.width
    }
    
    private func clearState() {
        contentSize = .zero
        itemAttributesMap.removeAll()
        hasLayout = false
        lastViewWidth = .zero
    }
    
    private func prepareLayoutOfItems() {
        guard let delegate else {
            return
        }

        let viewWidth = conversationStyle.viewWidth
        let layoutItems = delegate.layoutItems
        var y: CGFloat = 0
        
        if layoutItems.isEmpty {
            headerLayoutAttributes = nil
        } else {
            let headerIndexPath = IndexPath(row: 0, section: 0)
            let headerAttributes = UICollectionViewLayoutAttributes(
                forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                with: headerIndexPath
            )
            let headerHeight = delegate.layoutHeaderHeight
            headerAttributes.frame = CGRect(x: 0, y: y, width: viewWidth, height: headerHeight)
            self.headerLayoutAttributes = headerAttributes
            y += headerHeight
        }
        y += conversationStyle.contentMarginTop
        
        var contentBottom = y
        var previousLayoutItem: ConversationViewLayoutItem? = nil
        layoutItems.enumerated().forEach { row, layoutItem in
            if let previousLayoutItem {
                y += layoutItem.vSpacing(previousLayoutItem: previousLayoutItem)
            }
            
            var layoutSize = CGSizeCeil(layoutItem.cellSize)
            layoutSize.width = min(viewWidth, layoutSize.width)
            
            let itemFrame = CGRectMake(0, y, viewWidth, layoutSize.height)
            let indexPath = IndexPath(row: row, section: 0)
            let itemAttributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            itemAttributes.frame = itemFrame
            self.itemAttributesMap[row] = itemAttributes
            
            contentBottom = CGRectGetMaxY(itemFrame)
            y = contentBottom
            
            previousLayoutItem = layoutItem
        }
        contentBottom += conversationStyle.contentMarginBottom
        
        if layoutItems.isEmpty {
            self.footerLayoutAttributes = nil
        } else {
            let footerIndexPath = IndexPath(row: layoutItems.count - 1, section: 0)
            let footerAttributes = UICollectionViewLayoutAttributes(
                forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter,
                with: footerIndexPath
            )
            let footerHeight = delegate.layoutFooterHeight
            footerAttributes.frame = CGRectMake(0, contentBottom, viewWidth, footerHeight)
            self.footerLayoutAttributes = footerAttributes
            contentBottom += footerHeight
        }
        
        self.contentSize = CGSizeMake(viewWidth, contentBottom)
        self.lastViewWidth = viewWidth
    }
}
