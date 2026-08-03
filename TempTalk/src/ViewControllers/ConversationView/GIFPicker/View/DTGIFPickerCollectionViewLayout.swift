//
//  DTGIFPickerCollectionViewLayout.swift
//  TempTalk
//
//  Pinterest-style waterfall layout for the GIF picker.
//

import Foundation
import UIKit

protocol DTGIFPickerCollectionViewLayoutDataSource: AnyObject {
    /// Width / height ratio per item, in display order. Drives the waterfall heights.
    func aspectRatiosForLayout() -> [CGFloat]
}

class DTGIFPickerCollectionViewLayout: UICollectionViewLayout {

    public weak var dataSource: DTGIFPickerCollectionViewLayoutDataSource?

    private var itemAttributesMap = [UInt: UICollectionViewLayoutAttributes]()

    private var contentSize = CGSize.zero

    @available(*, unavailable, message: "use other constructor instead.")
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init() {
        super.init()
    }

    override func invalidateLayout() {
        super.invalidateLayout()
        itemAttributesMap.removeAll()
    }

    override func invalidateLayout(with context: UICollectionViewLayoutInvalidationContext) {
        super.invalidateLayout(with: context)
        itemAttributesMap.removeAll()
    }

    override func prepare() {
        super.prepare()

        guard let collectionView = collectionView else { return }
        guard let dataSource = dataSource else { return }

        // Match Figma: 2 columns, 16pt outer margin, 8pt gaps.
        let vInset = UInt(8)
        let hInset = UInt(16)
        let vSpacing = UInt(8)
        let hSpacing = UInt(8)

        // 2 columns on phones; widen on larger canvases.
        let columnCount = UInt(max(2, collectionView.width / 200))

        let totalViewWidth = UInt(collectionView.width)
        let hTotalWhitespace = (2 * hInset) + (hSpacing * (columnCount - 1))
        let hRemainderSpace = totalViewWidth - hTotalWhitespace
        let columnWidth = UInt(hRemainderSpace / columnCount)
        let totalHSpacing = totalViewWidth - ((2 * hInset) + (columnCount * columnWidth))

        var columnXs = [UInt]()
        var columnYs = [UInt]()
        for columnIndex in 0...columnCount-1 {
            var columnX = hInset + (columnWidth * columnIndex)
            if columnCount > 1 {
                // Distribute rounding remainder so left/right margins stay equal.
                columnX += ((totalHSpacing * columnIndex) / (columnCount - 1))
            }
            columnXs.append(columnX)
            columnYs.append(vInset)
        }

        let aspectRatios = dataSource.aspectRatiosForLayout()
        var contentBottom = vInset
        for (cellIndex, aspectRatio) in aspectRatios.enumerated() {
            // Pick the highest (shortest) column.
            var column = 0
            var cellY = columnYs[column]
            for (columnValue, columnYValue) in columnYs.enumerated() {
                if columnYValue < cellY {
                    column = columnValue
                    cellY = columnYValue
                }
            }
            let cellX = columnXs[column]
            let cellWidth = columnWidth
            let safeAspectRatio = aspectRatio > 0 ? aspectRatio : 1
            let cellHeight = UInt(CGFloat(columnWidth) / safeAspectRatio)

            let indexPath = NSIndexPath(row: cellIndex, section: 0)
            let itemAttributes = UICollectionViewLayoutAttributes(forCellWith: indexPath as IndexPath)
            itemAttributes.frame = CGRect(x: CGFloat(cellX), y: CGFloat(cellY), width: CGFloat(cellWidth), height: CGFloat(cellHeight))
            itemAttributesMap[UInt(cellIndex)] = itemAttributes

            columnYs[column] = cellY + cellHeight + vSpacing
            contentBottom = max(contentBottom, cellY + cellHeight)
        }

        let contentHeight = contentBottom + vInset
        contentSize = CGSize(width: CGFloat(totalViewWidth), height: CGFloat(contentHeight))
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return itemAttributesMap.values.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return itemAttributesMap[UInt(indexPath.row)]
    }

    override var collectionViewContentSize: CGSize {
        return contentSize
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView = collectionView else { return false }
        return collectionView.width != newBounds.size.width
    }
}
