//
//  DirectionPanGestureRecognizer.swift
//  Signal
//
//  Created by Kris.s on 2024/9/21.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import UIKit

@objc
public class DTPanGestureRecognizer: UIPanGestureRecognizer {
    
    @objc public enum DTPanGestureRecognizerDirection: Int {
        case vertical = 0
        case horizontal = 1
    }
    
    var drag = false
    var moveX = 0.0
    var moveY = 0.0
    var direction: DTPanGestureRecognizerDirection = .horizontal
    
    static let kDirectionPanThreshold = 5.0
    static let kDirectionPanBackThreshold = 20.0
    
    override public func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        if self.state == .failed {
            return;
        }
        let touch = touches.first!
        let nowPoint = touch.location(in: self.view)
        let prevPoint = touch.previousLocation(in: self.view)
        moveX += prevPoint.x - nowPoint.x
        moveY += prevPoint.y - nowPoint.y
        
        if !drag {
            if abs(moveX) > DTPanGestureRecognizer.kDirectionPanThreshold {
                if direction == .vertical || abs(moveX/moveY) < sqrt(3) {
                    self.state = .failed
                } else {
                    drag = true
                }
            } else if (abs(moveY) > DTPanGestureRecognizer.kDirectionPanThreshold) {
                if (direction == .horizontal || abs(moveY/moveX) < sqrt(3)) {
                    self.state = .failed
                } else {
                    drag = true
                }
            }
        }
        
        if prevPoint.x < DTPanGestureRecognizer.kDirectionPanBackThreshold {
            self.state = .failed
        }
        
    }
    
    override public func reset() {
        super.reset()
        drag = false
        moveX = 0.0
        moveY = 0.0
    }
    
}
