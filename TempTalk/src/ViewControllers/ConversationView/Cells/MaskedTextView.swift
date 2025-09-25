//
//  MaskedTextView.swift
//  TempTalk
//
//  Created by Kris.s on 2025/1/4.
//  Copyright © 2025 Difft. All rights reserved.
//

import UIKit

class MaskedTextView: OWSMessageTextView {
    
    var maskEnable: Bool = false
    var maskColor: UIColor = UIColor.black.withAlphaComponent(0.3)
    
    // 每行遮罩的间隔（5px）
    private let lineSpacing: CGFloat = 5.0
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard maskEnable else { return }
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        
        let layoutManager = self.layoutManager
        let range = NSRange(location: 0, length: self.text.count)
        
        layoutManager.enumerateLineFragments(forGlyphRange: range) { [weak self] (lineRect, usedRect, textContainer, glyphRange, stop) in
            guard let self = self else { return }
            
            let safeLocation = min(glyphRange.location, range.length - 1)
            let safeLength = min(glyphRange.length, range.length - safeLocation)
            let safeRange = NSMakeRange(safeLocation, safeLength)
            let lineString = (self.text as NSString).substring(with: safeRange)
            
            var currentX = usedRect.origin.x  // 遮罩起点
            
            // 计算当前行的遮罩起始 Y 位置（增加 2px 间隔）
            let maskY = usedRect.origin.y + (lineSpacing / 2.0)
            let maskHeight = usedRect.height - lineSpacing
            
            // 遍历当前行的字符
            for (index, character) in lineString.enumerated() {
                let glyphRange = NSRange(location: safeRange.location + index, length: 1)
                let glyphRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                
                // 只对非空格字符绘制遮罩
                if character != " " {
                    let maskFrame = CGRect(
                        x: glyphRect.origin.x - 1.0,
                        y: maskY,  // 应用行间距
                        width: glyphRect.width + 1.0,
                        height: maskHeight
                    )
                    context.setFillColor(maskColor.cgColor)
                    context.fill(maskFrame)
                }
                
                // 更新 X 位置
                currentX += glyphRect.width
            }
        }
        
        context.restoreGState()
    }
}


