//
//  ConversationActionMenuContainerView.swift
//  Difft
//
//  Created by Jaymin on 2024/6/14.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import UIKit

class ConversationActionMenuContainerView: UIView {
    enum ArrowDirection {
        case top
        case bottom
    }
    
    static let arrowHeight: CGFloat = 6.0
    private let arrowWidth: CGFloat = 13.5
    private let cornerRadius: CGFloat = 8.0
    
    private var sourceRect: CGRect = .zero
    private var arrowPosition: CGFloat = 0.0
    private var arrowDirection: ArrowDirection = .top
    
    private lazy var shapeLayer = CAShapeLayer()
    private lazy var shadowLayer = CAShapeLayer()
    
    var containerBackgroundColor: UIColor = .white {
        didSet {
            shapeLayer.fillColor = containerBackgroundColor.cgColor
            shadowLayer.fillColor = containerBackgroundColor.cgColor
        }
    }
    
    var showShadow = false {
        didSet {
            shadowLayer.isHidden = !showShadow
        }
    }
    
    var shadowColor: UIColor = .black.withAlphaComponent(0.08) {
        didSet {
            shadowLayer.shadowColor = shadowColor.cgColor
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        updateLayers()
    }
    
    func configue(sourceRect: CGRect, arrowDirection: ArrowDirection) {
        self.sourceRect = sourceRect
        self.arrowDirection = arrowDirection
        
        updateLayers()
    }
    
    private func setupLayers() {
        backgroundColor = .clear
        
        shapeLayer.fillColor = containerBackgroundColor.cgColor
        layer.addSublayer(shapeLayer)
        
        shadowLayer.shadowColor = shadowColor.cgColor
        shadowLayer.shadowOpacity = 1.0
        shadowLayer.shadowOffset = .init(width: 0, height: 3)
        shadowLayer.shadowRadius = 6 / 2.0
        shadowLayer.fillColor = containerBackgroundColor.cgColor
        shadowLayer.isHidden = showShadow
        layer.insertSublayer(shadowLayer, at: 0)
    }
    
    private func updateLayers() {
        guard !CGRectEqualToRect(self.frame, .zero) else {
            return
        }
        guard !CGRectEqualToRect(sourceRect, .zero) else {
            return
        }
        
        arrowPosition = sourceRect.midX - self.frame.minX
        
        let path = createBubblePath()
        shadowLayer.shadowPath = path.cgPath
        shapeLayer.path = path.cgPath
    }

    private func createBubblePath() -> UIBezierPath {
        let path = UIBezierPath()
        let arrowHeight = Self.arrowHeight
        
        if arrowDirection == .top {
            // Start from the arrow tip
            path.move(to: CGPoint(x: arrowPosition, y: 0))
            path.addLine(to: CGPoint(x: arrowPosition - arrowWidth / 2, y: arrowHeight))
            path.addLine(to: CGPoint(x: cornerRadius, y: arrowHeight))
            
            // Top-left corner
            path.addArc(withCenter: CGPoint(x: cornerRadius, y: arrowHeight + cornerRadius), radius: cornerRadius, startAngle: CGFloat(3 * Double.pi / 2), endAngle: CGFloat(Double.pi), clockwise: false)
            
            // Left line down
            path.addLine(to: CGPoint(x: 0, y: bounds.height - cornerRadius))
            
            // Bottom-left corner
            path.addArc(withCenter: CGPoint(x: cornerRadius, y: bounds.height - cornerRadius), radius: cornerRadius, startAngle: CGFloat(Double.pi), endAngle: CGFloat(Double.pi / 2), clockwise: false)
            
            // Bottom line to the right
            path.addLine(to: CGPoint(x: bounds.width - cornerRadius, y: bounds.height))
            
            // Bottom-right corner
            path.addArc(withCenter: CGPoint(x: bounds.width - cornerRadius, y: bounds.height - cornerRadius), radius: cornerRadius, startAngle: CGFloat(Double.pi / 2), endAngle: 0, clockwise: false)
            
            // Right line up
            path.addLine(to: CGPoint(x: bounds.width, y: arrowHeight + cornerRadius))
            
            // Top-right corner
            path.addArc(withCenter: CGPoint(x: bounds.width - cornerRadius, y: arrowHeight + cornerRadius), radius: cornerRadius, startAngle: 0, endAngle: CGFloat(3 * Double.pi / 2), clockwise: false)
            
            // Top line to the left
            path.addLine(to: CGPoint(x: arrowPosition + arrowWidth / 2, y: arrowHeight))
        } else {
            // Start from the top-left corner
            path.move(to: CGPoint(x: cornerRadius, y: 0))
            
            // Top line to the right, stopping before the corner
            path.addLine(to: CGPoint(x: bounds.width - cornerRadius, y: 0))
            
            // Top-right corner
            path.addArc(withCenter: CGPoint(x: bounds.width - cornerRadius, y: cornerRadius), radius: cornerRadius, startAngle: CGFloat(3 * Double.pi / 2), endAngle: 0, clockwise: true)
            
            // Right line down
            path.addLine(to: CGPoint(x: bounds.width, y: bounds.height - cornerRadius - arrowHeight))
            
            // Bottom-right corner
            path.addArc(withCenter: CGPoint(x: bounds.width - cornerRadius, y: bounds.height - cornerRadius - arrowHeight), radius: cornerRadius, startAngle: 0, endAngle: CGFloat(Double.pi / 2), clockwise: true)
            
            // Bottom line to the left, stopping for the arrow
            path.addLine(to: CGPoint(x: arrowPosition + arrowWidth / 2, y: bounds.height - arrowHeight))
            
            // Draw the arrow
            path.addLine(to: CGPoint(x: arrowPosition, y: bounds.height))
            path.addLine(to: CGPoint(x: arrowPosition - arrowWidth / 2, y: bounds.height - arrowHeight))
            
            // Bottom line to the left, stopping before the corner
            path.addLine(to: CGPoint(x: cornerRadius, y: bounds.height - arrowHeight))
            
            // Bottom-left corner
            path.addArc(withCenter: CGPoint(x: cornerRadius, y: bounds.height - cornerRadius - arrowHeight), radius: cornerRadius, startAngle: CGFloat(Double.pi / 2), endAngle: CGFloat(Double.pi), clockwise: true)
            
            // Left line up
            path.addLine(to: CGPoint(x: 0, y: cornerRadius))
            
            // Top-left corner
            path.addArc(withCenter: CGPoint(x: cornerRadius, y: cornerRadius), radius: cornerRadius, startAngle: CGFloat(Double.pi), endAngle: CGFloat(3 * Double.pi / 2), clockwise: true)
        }
        
        path.close()
        return path
    }
}
