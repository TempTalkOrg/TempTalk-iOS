//
//  TTGroupAvatarGenerator.swift
//  TempTalk
//
//  Created by Kris.s on 2025/5/16.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

@objc
public class TTLetterItem: NSObject {
    @objc public let char: String
    @objc public let color: UIColor
    
    @objc public init(char: String, color: UIColor) {
        self.char = char
        self.color = color
    }
}

@objc
public class TTGroupAvatarGenerator: NSObject {
    
    /**
     * Generate a group avatar bitmap with letters and colors arranged around a circle.
     *
     * - Parameters:
     *   - items: List of letter items containing characters and their colors (max 6)
     *   - backgroundColor: Background color of the avatar
     *   - sizePx: Size of the avatar in pixels (default 512)
     */
    @objc public static func generate(
        with items: [TTLetterItem],
        backgroundColor: UIColor,
        sizePx: CGFloat = 512
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: sizePx, height: sizePx))
        
        return renderer.image { context in
            let rect = CGRect(x: 0, y: 0, width: sizePx, height: sizePx)
            let centerX = sizePx / 2
            let centerY = sizePx / 2
            let padding = sizePx * 0.04  // More compact margin
            
            // Background
            backgroundColor.setFill()
            context.cgContext.fillEllipse(in: rect)
            
            let filteredItems = items
                .filter { item in
                    guard let firstChar = item.char.first else { return false }
                    return firstChar.isLetter || firstChar.isNumber || (firstChar.unicodeScalars.first?.value ?? 0) >= 0x4E00
                }
                .prefix(6)
            
            let count = filteredItems.count
            
            // Sub-circle dimensions: reduced to minimize overlap
            let circleRadius: CGFloat
            switch count {
            case 1: circleRadius = sizePx * 0.38
            case 2: circleRadius = sizePx * 0.24
            case 3: circleRadius = sizePx * 0.22
            case 4: circleRadius = sizePx * 0.20
            case 5: circleRadius = sizePx * 0.18
            default: circleRadius = sizePx * 0.16 // 6
            }
            
            // Layout radius for sub-circles: based on center minus padding and sub-circle radius
            let layoutRadius = (sizePx / 2) - padding - circleRadius
            
            let positions: [(CGFloat, CGFloat)]
            
            switch count {
            case 1:
                positions = [(centerX, centerY)]
            case 2:
                positions = [
                    (centerX - layoutRadius * 0.85, centerY),
                    (centerX + layoutRadius * 0.85, centerY)
                ]
            default:
                let angleStep = 360.0 / Double(count)
                positions = (0..<count).map { i in
                    let angle = (Double(i) * angleStep - 90.0) * Double.pi / 180.0
                    let x = centerX + layoutRadius * CGFloat(cos(angle))
                    let y = centerY + layoutRadius * CGFloat(sin(angle))
                    return (x, y)
                }
            }
            
            // Font configuration
            let font = UIFont.systemFont(ofSize: circleRadius * 0.9, weight: .medium)
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white
            ]
            
            for (index, item) in filteredItems.enumerated() {
                let (cx, cy) = positions[index]
                
                // Background circle
                item.color.setFill()
                context.cgContext.fillEllipse(in: CGRect(
                    x: cx - circleRadius,
                    y: cy - circleRadius,
                    width: circleRadius * 2,
                    height: circleRadius * 2
                ))
                
                // Text
                let charString = item.char.prefix(1).uppercased()
                let textSize = charString.size(withAttributes: textAttributes)
                let textRect = CGRect(
                    x: cx - textSize.width / 2,
                    y: cy - textSize.height / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                
                charString.draw(in: textRect, withAttributes: textAttributes)
            }
        }
    }
}
