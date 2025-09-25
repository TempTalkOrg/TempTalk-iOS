//
//  DTImageRecognizedContent.swift
//  Difft
//
//  Created by Jaymin on 2024/5/30.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import Vision

struct DTImageRecognizedContent {
    enum Content {
        case text(text: String, words: [(Range<String.Index>, Rect)])
        case qrCode(payload: String)
    }
    
    struct Rect {
        struct Point {
            let x: Double
            let y: Double
            
            init(cgPoint: CGPoint) {
                self.x = cgPoint.x
                self.y = cgPoint.y
            }
            
            var cgPoint: CGPoint {
                return CGPoint(x: self.x, y: self.y)
            }
        }
        
        let topLeft: CGPoint
        let topRight: CGPoint
        let bottomLeft: CGPoint
        let bottomRight: CGPoint
        
        var boundingFrame: CGRect {
        let top: CGFloat = min(topLeft.y, topRight.y)
        let left: CGFloat = min(topLeft.x, bottomLeft.x)
        let right: CGFloat = max(topRight.x, bottomRight.x)
        let bottom: CGFloat = max(bottomLeft.y, bottomRight.y)
            return CGRect(x: left, y: top, width: abs(right - left), height: abs(bottom - top))
        }
                
        var leftMidPoint: CGPoint {
            return self.topLeft.midPoint(self.bottomLeft)
        }
        
        var leftHeight: CGFloat {
            return self.topLeft.distanceTo(self.bottomLeft)
        }
        
        var rightMidPoint: CGPoint {
            return self.topRight.midPoint(self.bottomRight)
        }
        
        var rightHeight: CGFloat {
            return self.topRight.distanceTo(self.bottomRight)
        }
                
        func convertTo(size: CGSize, insets: UIEdgeInsets = UIEdgeInsets()) -> Rect {
            return Rect(
                topLeft: CGPoint(x: self.topLeft.x * size.width + insets.left, y: size.height - self.topLeft.y * size.height + insets.top),
                topRight: CGPoint(x: self.topRight.x * size.width - insets.right, y: size.height - self.topRight.y * size.height + insets.top),
                bottomLeft: CGPoint(x: self.bottomLeft.x * size.width + insets.left, y: size.height - self.bottomLeft.y * size.height - insets.bottom),
                bottomRight: CGPoint(x: self.bottomRight.x * size.width - insets.right, y: size.height - self.bottomRight.y * size.height - insets.bottom)
            )
        }
        
        init() {
            self.topLeft = CGPoint()
            self.topRight = CGPoint()
            self.bottomLeft = CGPoint()
            self.bottomRight = CGPoint()
        }
        
        init(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) {
            self.topLeft = topLeft
            self.topRight = topRight
            self.bottomLeft = bottomLeft
            self.bottomRight = bottomRight
        }

        init(observation: VNRectangleObservation) {
            self.topLeft = observation.topLeft
            self.topRight = observation.topRight
            self.bottomLeft = observation.bottomLeft
            self.bottomRight = observation.bottomRight
        }
    }
    
    let rect: Rect
    let content: Content
    
    init?(observation: VNObservation) {
        if let barcode = observation as? VNBarcodeObservation, case .qr = barcode.symbology, let payload = barcode.payloadStringValue {
            self.content = .qrCode(payload: payload)
            self.rect = Rect(observation: barcode)
        } else if let text = observation as? VNRecognizedTextObservation, let candidate = text.topCandidates(1).first, candidate.confidence >= 0.5 {
            let string = candidate.string
            var words: [(Range<String.Index>, Rect)] = []
            string.enumerateSubstrings(in: string.startIndex ..< string.endIndex, options: .byWords) { _, substringRange, _, _ in
                if let rectangle = try? candidate.boundingBox(for: substringRange) {
                    words.append((substringRange, Rect(observation: rectangle)))
                }
            }
            self.content = .text(text: string, words: words)
            self.rect = Rect(observation: text)
        } else {
            return nil
        }
    }
    
    struct WordRangeAndRect {
        let start: Int32
        let end: Int32
        let rect: Rect
        
        init(text: String, range: Range<String.Index>, rect: Rect) {
            self.start = Int32(text.distance(from: text.startIndex, to: range.lowerBound))
            self.end = Int32(text.distance(from: text.startIndex, to: range.upperBound))
            self.rect = rect
        }
        
        func toRangeWithRect(text: String) -> (Range<String.Index>, Rect) {
            return (text.index(text.startIndex, offsetBy: Int(self.start)) ..< text.index(text.startIndex, offsetBy: Int(self.end)), self.rect)
        }
    }
}

extension CGPoint {
    func distanceTo(_ a: CGPoint) -> CGFloat {
        let xDist = a.x - x
        let yDist = a.y - y
        return CGFloat(sqrt((xDist * xDist) + (yDist * yDist)))
    }
    
    func midPoint(_ other: CGPoint) -> CGPoint {
        return CGPoint(x: (self.x + other.x) / 2.0, y: (self.y + other.y) / 2.0)
    }
}
