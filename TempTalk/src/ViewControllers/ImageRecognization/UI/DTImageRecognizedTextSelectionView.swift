//
//  DTImageRecognizedTextSelectionView.swift
//  Difft
//
//  Created by Jaymin on 2024/5/31.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit

class DTImageRecognizedTextSelectionView: UIView {
    enum Constants {
        static let knobDiameter: CGFloat = 10.0
    }
    
    private let recognitions: [(string: String, rect: DTImageRecognizedContent.Rect)]

    private var selectedIndices: Set<Int>?
    private var selectedText: String?
    private var currentRects: [DTImageRecognizedContent.Rect]?
    private var currentTopLeft: CGPoint?
    private var currentBottomRight: CGPoint?
    private var highlightOverlay: UIImageView?
    private var recognizer: RecognizedTextSelectionGestureRecognizer?
    
    lazy var highlightAreaView = UIView()
    
    private lazy var leftKnob: UIImageView = {
        let imageView = UIImageView()
        imageView.isUserInteractionEnabled = false
        imageView.image = generateKnobImage(
            color: Theme.themeBlueColor,
            diameter: Constants.knobDiameter
        )
        imageView.alpha = 0
        return imageView
    }()
    
    private lazy var rightKnob: UIImageView = {
        let imageView = UIImageView()
        imageView.isUserInteractionEnabled = false
        imageView.image = generateKnobImage(
            color: Theme.themeBlueColor,
            diameter: Constants.knobDiameter,
            inverted: true
        )
        imageView.alpha = 0
        return imageView
    }()
    
    init(recognitions: [DTImageRecognizedContent]) {
        let sortedRecognitions = recognitions.sorted { lhs, rhs in
            if abs(lhs.rect.leftMidPoint.y - rhs.rect.rightMidPoint.y) < min(lhs.rect.leftHeight, rhs.rect.leftHeight) / 2.0  {
                return lhs.rect.leftMidPoint.x < rhs.rect.leftMidPoint.x
            } else {
                return lhs.rect.leftMidPoint.y > rhs.rect.leftMidPoint.y
            }
        }
        var textRecognitions: [(String, DTImageRecognizedContent.Rect)] = []
        sortedRecognitions.forEach {
            if case let .text(text, _) = $0.content {
                textRecognitions.append((text, $0.rect))
            }
        }
        self.recognitions = textRecognitions
        
        super.init(frame: .zero)
        
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var canBecomeFirstResponder: Bool {
        true
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if knobAtPoint(point) != nil {
            return self
        }
        if self.bounds.contains(point) {
            for recognition in recognitions {
                let mappedRect = recognition.rect.convertTo(size: self.bounds.size)
                if mappedRect.boundingFrame.insetBy(dx: -20.0, dy: -20.0).contains(point) {
                    return self
                }
            }
        }
        return nil
    }
    
    private func setupView() {
        addSubview(leftKnob)
        addSubview(rightKnob)
        
        let recognizer = RecognizedTextSelectionGestureRecognizer(target: nil, action: nil)
        recognizer.knobAtPoint = { [weak self] point in
            return self?.knobAtPoint(point)
        }
        recognizer.moveKnob = { [weak self] knob, point in
            guard let self, let _ = self.selectedIndices, let currentTopLeft, let currentBottomRight else {
                return
            }
            
            let topLeftPoint: CGPoint
            let bottomRightPoint: CGPoint
            switch knob {
                case .left:
                    topLeftPoint = point
                    bottomRightPoint = currentBottomRight
                case .right:
                    topLeftPoint = currentTopLeft
                    bottomRightPoint = point
            }
            
            let selectionRect = CGRect(x: min(topLeftPoint.x, bottomRightPoint.x), y: min(topLeftPoint.y, bottomRightPoint.y), width: max(bottomRightPoint.x, topLeftPoint.x) - min(bottomRightPoint.x, topLeftPoint.x), height: max(bottomRightPoint.y, topLeftPoint.y) - min(bottomRightPoint.y, topLeftPoint.y))
            
            var i = 0
            var selectedIndices: Set<Int>?
            for recognition in self.recognitions {
                let rect = recognition.rect.convertTo(size: self.size, insets: UIEdgeInsets(top: -4.0, left: -2.0, bottom: -4.0, right: -2.0))
                if selectionRect.intersects(rect.boundingFrame) {
                    if selectedIndices == nil {
                        selectedIndices = Set()
                    }
                    selectedIndices?.insert(i)
                }
                i += 1
            }
            
            self.selectedIndices = selectedIndices
            self.updateSelection(range: selectedIndices, animateIn: false)
        }
        recognizer.finishedMovingKnob = { [weak self] in
            guard let self else {
                return
            }
            self.displayMenu()
        }
        recognizer.beginSelection = { [weak self] point in
            guard let self else {
                return
            }
            
            let _ = self.dismissSelection()
            
            var i = 0
            var selectedIndices: Set<Int>?
            var topLeft: CGPoint?
            var bottomRight: CGPoint?
            for recognition in self.recognitions {
                let rect = recognition.rect.convertTo(size: self.size, insets: UIEdgeInsets(top: -4.0, left: -2.0, bottom: -4.0, right: -2.0))
                if rect.boundingFrame.contains(point) {
                    topLeft = rect.topLeft
                    bottomRight = rect.bottomRight
                    selectedIndices = Set([i])
                    break
                }
                i += 1
            }
            self.selectedIndices = selectedIndices
            self.currentTopLeft = topLeft
            self.currentBottomRight = bottomRight
            self.updateSelection(range: selectedIndices, animateIn: true)

            self.displayMenu()
        }
        recognizer.clearSelection = { [weak self] in
            let _ = self?.dismissSelection()
        }
        self.recognizer = recognizer
        addGestureRecognizer(recognizer)
    }
    
    private func knobAtPoint(_ point: CGPoint) -> (Knob, CGPoint)? {
        if !self.leftKnob.alpha.isZero, self.leftKnob.frame.insetBy(dx: -4.0, dy: -8.0).contains(point) {
            return (.left, self.leftKnob.frame.offsetBy(dx: 0.0, dy: self.leftKnob.frame.width / 2.0).center)
        }
        if !self.rightKnob.alpha.isZero, self.rightKnob.frame.insetBy(dx: -4.0, dy: -8.0).contains(point) {
            return (.right, self.rightKnob.frame.offsetBy(dx: 0.0, dy: -self.rightKnob.frame.width / 2.0).center)
        }
        if !self.leftKnob.alpha.isZero, self.leftKnob.frame.insetBy(dx: -14.0, dy: -14.0).contains(point) {
            return (.left, self.leftKnob.frame.offsetBy(dx: 0.0, dy: self.leftKnob.frame.width / 2.0).center)
        }
        if !self.rightKnob.alpha.isZero, self.rightKnob.frame.insetBy(dx: -14.0, dy: -14.0).contains(point) {
            return (.right, self.rightKnob.frame.offsetBy(dx: 0.0, dy: -self.rightKnob.frame.width / 2.0).center)
        }
        return nil
    }
    
    private func updateSelection(range: Set<Int>?, animateIn: Bool) {
        var rects: [DTImageRecognizedContent.Rect]? = nil
        var startEdge: (position: CGPoint, height: CGFloat)?
        var endEdge: (position: CGPoint, height: CGFloat)?
        
        if let range = range {
            var i = 0
            rects = []
            for recognition in self.recognitions {
                let rect = recognition.rect.convertTo(size: self.size)
                if range.contains(i) {
                    if startEdge == nil {
                        startEdge = (rect.leftMidPoint, rect.leftHeight)
                    }
                    rects?.append(rect)
                }
                i += 1
            }
            
            if let rect = rects?.last {
                endEdge = (rect.rightMidPoint, rect.rightHeight)
            }
        }

        self.currentRects = rects

        if let rects = rects, let startEdge = startEdge, let endEdge = endEdge, !rects.isEmpty {
            let highlightOverlay: UIImageView
            if let current = self.highlightOverlay {
                highlightOverlay = current
            } else {
                highlightOverlay = UIImageView()
                self.highlightOverlay = highlightOverlay
                self.highlightAreaView.addSubview(highlightOverlay)
            }
            highlightOverlay.frame = self.bounds
            highlightOverlay.image = generateSelectionsImage(
                size: self.size,
                rects: rects,
                color: Theme.themeBlueColor.withAlphaComponent(0.4)
            )
            highlightOverlay.alpha = 0.9
            
            if let image = self.leftKnob.image {
                self.leftKnob.frame = CGRect(
                    x: floor(startEdge.position.x - image.size.width / 2.0),
                    y: startEdge.position.y - floorToScreenPixels(startEdge.height / 2.0) - Constants.knobDiameter,
                    width: image.size.width,
                    height: Constants.knobDiameter + startEdge.height + 2.0
                )
                self.rightKnob.frame = CGRect(
                    x: floor(endEdge.position.x + 1.0 - image.size.width / 2.0),
                    y: endEdge.position.y - floorToScreenPixels(endEdge.height / 2.0),
                    width: image.size.width,
                    height: Constants.knobDiameter + endEdge.height + 2.0
                )
            }
            if self.leftKnob.alpha.isZero {
                highlightOverlay.layer.animateAlpha(
                    from: 0.0,
                    to: highlightOverlay.alpha,
                    duration: 0.3,
                    timingFunction: CAMediaTimingFunctionName.easeOut.rawValue
                )
                
                self.leftKnob.alpha = 1.0
                self.leftKnob.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.14, delay: 0.19)
                
                self.rightKnob.alpha = 1.0
                self.rightKnob.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.14, delay: 0.19)
                
                self.leftKnob.layer.animateSpring(
                    from: 0.5 as NSNumber,
                    to: 1.0 as NSNumber,
                    keyPath: "transform.scale",
                    duration: 0.2,
                    delay: 0.25,
                    initialVelocity: 0.0,
                    damping: 80.0
                )
                self.rightKnob.layer.animateSpring(
                    from: 0.5 as NSNumber,
                    to: 1.0 as NSNumber,
                    keyPath: "transform.scale",
                    duration: 0.2,
                    delay: 0.25,
                    initialVelocity: 0.0,
                    damping: 80.0
                )
                
                if animateIn {
                    var result = CGRect()
                    for rect in rects {
                        if result.isEmpty {
                            result = rect.boundingFrame
                        } else {
                            result = result.union(rect.boundingFrame)
                        }
                    }
                    highlightOverlay.layer.animateScale(from: 2.0, to: 1.0, duration: 0.26)
                    let fromResult = CGRect(
                        x: result.minX - result.width / 2.0,
                        y: result.minY - result.height / 2.0,
                        width: result.width * 2.0,
                        height: result.height * 2.0
                    )
                    highlightOverlay.layer.animatePosition(
                        from: CGPoint(
                            x: (-fromResult.midX + highlightOverlay.bounds.midX) / 1.0,
                            y: (-fromResult.midY + highlightOverlay.bounds.midY) / 1.0
                        ),
                        to: CGPoint(), 
                        duration: 0.26,
                        additive: true
                    )
                }
            }
        } else if let highlightOverlay = self.highlightOverlay {
            self.highlightOverlay = nil
            highlightOverlay.layer.animateAlpha(
                from: highlightOverlay.alpha,
                to: 0.0,
                duration: 0.18,
                removeOnCompletion: false,
                completion: { [weak highlightOverlay] _ in
                    highlightOverlay?.removeFromSuperview()
                }
            )
            self.leftKnob.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.18)
            self.leftKnob.alpha = 0.0
            self.leftKnob.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18)
            self.rightKnob.alpha = 0.0
            self.rightKnob.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18)
        }
    }
    
    private func displayMenu() {
        guard let currentRects = self.currentRects, !currentRects.isEmpty, let selectedIndices = self.selectedIndices else {
            return
        }
        
        var completeRect = currentRects[0].boundingFrame
        for i in 0 ..< currentRects.count {
            completeRect = completeRect.union(currentRects[i].boundingFrame)
        }
        completeRect = completeRect.insetBy(dx: 0.0, dy: -12.0)
        
        var selectedText = ""
        for i in 0 ..< self.recognitions.count {
            if selectedIndices.contains(i) {
                let (string, _) = self.recognitions[i]
                if !selectedText.isEmpty {
                    selectedText += "\n"
                }
                selectedText.append(contentsOf: string.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        self.selectedText = selectedText
        
        becomeFirstResponder()
        let menuController = UIMenuController.shared
        let copyItem = UIMenuItem(title: Localized("EDIT_ITEM_COPY_ACTION"), action: #selector(didTapCopy))
        menuController.menuItems = [copyItem]
        menuController.showMenu(from: self, rect: completeRect)
    }
    
    @objc
    private func didTapCopy() {
        UIPasteboard.general.string = selectedText
    }
    
    func dismissSelection() -> Bool {
        if let _ = self.selectedIndices {
            self.selectedIndices = nil
            self.updateSelection(range: nil, animateIn: false)
            return true
        } else {
            return false
        }
    }
    
    private func generateKnobImage(color: UIColor, diameter: CGFloat, inverted: Bool = false) -> UIImage? {
        let f: (CGSize, CGContext) -> Void = { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setFillColor(color.cgColor)
            context.fill(CGRect(origin: CGPoint(x: (size.width - 2.0) / 2.0, y: size.width / 2.0), size: CGSize(width: 2.0, height: size.height - size.width / 2.0 - 1.0)))
            context.fillEllipse(in: CGRect(origin: CGPoint(x: floor((size.width - diameter) / 2.0), y: floor((size.width - diameter) / 2.0)), size: CGSize(width: diameter, height: diameter)))
            context.fillEllipse(in: CGRect(origin: CGPoint(x: (size.width - 2.0) / 2.0, y: size.width + 2.0), size: CGSize(width: 2.0, height: 2.0)))
        }
        let size = CGSize(width: 12.0, height: 12.0 + 2.0 + 2.0)
        if inverted {
            return generateImage(size, contextGenerator: f)?.stretchableImage(withLeftCapWidth: Int(size.width / 2.0), topCapHeight: Int(size.height) - (Int(size.width) + 1))
        } else {
            return generateImage(size, rotatedContext: f)?.stretchableImage(withLeftCapWidth: Int(size.width / 2.0), topCapHeight: Int(size.width) + 1)
        }
    }
    
    private func generateSelectionsImage(size: CGSize, rects: [DTImageRecognizedContent.Rect], color: UIColor) -> UIImage? {
        return generateImage(size, opaque: false, rotatedContext: { size, c in
            let bounds = CGRect(origin: CGPoint(), size: size)
            c.clear(bounds)
            
            c.setFillColor(color.cgColor)
            for rect in rects {
                let path = UIBezierPath(rect: rect, radius: 2.5)
                c.addPath(path.cgPath)
                c.fillPath()
            }
        })
    }
    
    private func floorToScreenPixels(_ value: CGFloat) -> CGFloat {
        let UIScreenScale = UIScreen.main.scale
        return floor(value * UIScreenScale) / UIScreenScale
    }
    
    private func ceilToScreenPixels(_ value: CGFloat) -> CGFloat {
        let UIScreenScale = UIScreen.main.scale
        return ceil(value * UIScreenScale) / UIScreenScale
    }
}

private enum Knob {
    case left
    case right
}

private class RecognizedTextSelectionGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    
    private var longTapTimer: Timer?
    private var movingKnob: (Knob, CGPoint, CGPoint)?
    private var currentLocation: CGPoint?
    
    var beginSelection: ((CGPoint) -> Void)?
    var knobAtPoint: ((CGPoint) -> (Knob, CGPoint)?)?
    var moveKnob: ((Knob, CGPoint) -> Void)?
    var finishedMovingKnob: (() -> Void)?
    var clearSelection: (() -> Void)?
    
    override init(target: Any?, action: Selector?) {
        super.init(target: nil, action: nil)
        
        self.delegate = self
    }
    
    override func reset() {
        super.reset()
        
        longTapTimer?.invalidate()
        longTapTimer = nil
        
        movingKnob = nil
        currentLocation = nil
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        currentLocation = touches.first?.location(in: self.view)
        guard let currentLocation else { return }
        
        if let (knob, knobPosition) = knobAtPoint?(currentLocation) {
            movingKnob = (knob, knobPosition, currentLocation)
            cancelScrollViewGestures(view: self.view?.superview)
            self.state = .began
            
        } else if self.longTapTimer == nil {
            let longTapTimer = Timer(timeInterval: 0.3, target: TimerTarget(f: { [weak self] in
                self?.longTapEvent()
            }), selector: #selector(TimerTarget.event), userInfo: nil, repeats: false)
            self.longTapTimer = longTapTimer
            RunLoop.main.add(longTapTimer, forMode: .common)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        currentLocation = touches.first?.location(in: self.view)
        guard let currentLocation, let (knob, initialKnobPosition, initialGesturePosition) = self.movingKnob else {
            return
        }
        
        self.moveKnob?(knob, CGPoint(x: initialKnobPosition.x + currentLocation.x - initialGesturePosition.x, y: initialKnobPosition.y + currentLocation.y - initialGesturePosition.y))
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        if let longTapTimer {
            longTapTimer.invalidate()
            self.longTapTimer = nil
            self.clearSelection?()
        } else {
            if let _ = self.currentLocation, let _ = self.moveKnob {
                self.finishedMovingKnob?()
            }
        }
        self.state = .ended
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        self.state = .cancelled
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive press: UIPress) -> Bool {
        true
    }
    
    private func longTapEvent() {
        if let currentLocation = self.currentLocation {
            self.beginSelection?(currentLocation)
            self.state = .ended
        }
    }
    
    private func cancelScrollViewGestures(view: UIView?) {
        if let view = view {
            if let gestureRecognizers = view.gestureRecognizers {
                for recognizer in gestureRecognizers {
                    if let recognizer = recognizer as? UIPanGestureRecognizer {
                        switch recognizer.state {
                        case .began, .possible:
                            recognizer.state = .ended
                        default:
                            break
                        }
                    }
                }
            }
            cancelScrollViewGestures(view: view.superview)
        }
    }
}

extension RecognizedTextSelectionGestureRecognizer {
    final class TimerTarget: NSObject {
        let f: () -> Void
        
        init(f: @escaping () -> Void) {
            self.f = f
        }
        
        @objc func event() {
            self.f()
        }
    }
}
