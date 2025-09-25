//
//  DTTextSelectionView.swift
//  Difft
//
//  Created by Jaymin on 2024/6/25.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit

protocol DTTextSelectionViewDelegate: AnyObject {
    func selectionViewDidBeginSelect(_ selectionView: DTTextSelectionView)
    func selectionViewDidChangeSelectedRange(_ selectionView: DTTextSelectionView)
    func selectionViewDidEndSelect(_ selectionView: DTTextSelectionView)
    func selectionViewDidSingleTap(_ selectionView: DTTextSelectionView)
}

class DTTextSelectionView: UIView {
    
    private enum Constants {
        static let knobDiameter: CGFloat = 12.0
    }
    
    private var currentRange: (Int, Int)?
    private var currentRects: [CGRect]?
    
    private let textView: UITextView
    private var highlightOverlay: DTTextSelectionHighlightingView?
    private var recognizer: TextSelectionGestureRecognizer?
    
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
    
    lazy var highlightAreaView = UIView()
    
    weak var delegate: DTTextSelectionViewDelegate?
    
    init(textView: UITextView) {
        self.textView = textView
        
        super.init(frame: .zero)
        
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if knobAtPoint(point) != nil {
            return self
        }
        if self.bounds.contains(point) {
            return self
        }
        return nil
    }
    
    private func setupView() {
        addSubview(leftKnob)
        addSubview(rightKnob)
        
        addSubview(highlightAreaView)
        highlightAreaView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        let recognizer = TextSelectionGestureRecognizer(target: nil, action: nil)
        recognizer.knobAtPoint = { [weak self] point in
            return self?.knobAtPoint(point)
        }
        recognizer.moveKnob = { [weak self] knob, point in
            guard let self, !self.textView.attributedText.isEmpty, let currentRange = self.currentRange else {
                return
            }
            
            self.delegate?.selectionViewDidBeginSelect(self)
            
            var mappedPoint = self.convert(point, to: self.textView)
            // 当光标已经在第一行或者最后一行，此时向上或者向下拖动，光标会直接移动到文本的开头或末尾，容易误触，通过限制触摸点范围来解决这个问题
            mappedPoint.y = min(mappedPoint.y, self.textView.height - 1)
            mappedPoint.y = max(mappedPoint.y, 0)
            
            if let closetPosition = self.textView.closestPosition(to: mappedPoint) {
                let stringIndex = self.textView.offset(
                    from: self.textView.beginningOfDocument,
                    to: closetPosition
                )
                
                var updatedLeft = currentRange.0
                var updatedRight = currentRange.1
                switch knob {
                case .left:
                    updatedLeft = stringIndex
                case .right:
                    updatedRight = stringIndex
                }
                if self.currentRange?.0 != updatedLeft || self.currentRange?.1 != updatedRight {
                    self.currentRange = (updatedLeft, updatedRight)
                    let updatedRange = NSRange(location: min(updatedLeft, updatedRight), length: max(updatedLeft, updatedRight) - min(updatedLeft, updatedRight))
                    self.updateSelection(range: updatedRange, animateIn: false)
                }
                
                if let scrollView = findScrollView(view: self) {
                    let scrollPoint = self.convert(point, to: scrollView)
                    scrollView.scrollRectToVisible(CGRect(origin: CGPoint(x: scrollPoint.x, y: scrollPoint.y - 50.0), size: CGSize(width: 1.0, height: 100.0)), animated: false)
                }
            }
        }
        recognizer.finishedMovingKnob = { [weak self] in
            guard let self else { return }
            self.delegate?.selectionViewDidEndSelect(self)
        }
        recognizer.beginSelection = { [weak self] point in
            guard let self, let attributedString = self.textView.attributedText else {
                return
            }
            
            self.dismissSelection()
            
            let mappedPoint = self.convert(point, to: self.textView)
            var resultRange: NSRange?
            if let closetPosition = self.textView.closestPosition(to: mappedPoint) {
                let stringIndex = self.textView.offset(
                    from: self.textView.beginningOfDocument,
                    to: closetPosition
                )
                let string = attributedString.string as NSString
                let inputRange = CFRangeMake(0, string.length)
                let flag = UInt(kCFStringTokenizerUnitWord)
                let locale = CFLocaleCopyCurrent()
                let tokenizer = CFStringTokenizerCreate(kCFAllocatorDefault, string as CFString, inputRange, flag, locale)
                var tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
                
                while !tokenType.isEmpty {
                    let currentTokenRange = CFStringTokenizerGetCurrentTokenRange(tokenizer)
                    if currentTokenRange.location <= stringIndex && currentTokenRange.location + currentTokenRange.length > stringIndex {
                        resultRange = NSRange(location: currentTokenRange.location, length: currentTokenRange.length)
                        break
                    }
                    tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
                }
                if resultRange == nil {
                    resultRange = NSRange(location: stringIndex, length: 1)
                }
            }
            
            self.currentRange = resultRange.flatMap {
                ($0.lowerBound, $0.upperBound)
            }
            self.updateSelection(range: resultRange, animateIn: true)
        }
        recognizer.clearSelection = { [weak self] in
            guard let self else { return }
            self.dismissSelection()
        }
        self.recognizer = recognizer
        addGestureRecognizer(recognizer)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didSingleTap))
        addGestureRecognizer(tapGesture)
    }
    
    @objc
    private func didSingleTap() {
        delegate?.selectionViewDidSingleTap(self)
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
    
    func getLeftKnobFrame() -> CGRect {
        return leftKnob.frame
    }
    
    func getRightKnobFrame() -> CGRect {
        return rightKnob.frame
    }
    
    func selectAll(animated: Bool) {
        guard let attributedText = textView.attributedText, !attributedText.isEmpty else {
            return
        }
        let range = NSRange(location: 0, length: attributedText.length)
        setSelection(range: range, animated: animated)
    }
    
    func getSelection() -> NSRange? {
        guard let currentRange, let _ = textView.attributedText else {
            return nil
        }
        let range = NSRange(
            location: min(currentRange.0, currentRange.1),
            length: max(currentRange.0, currentRange.1) - min(currentRange.0, currentRange.1)
        )
        return range
    }
    
    func setSelection(range: NSRange, animated: Bool) {
        guard let attributedString = textView.attributedText else {
            return
        }
        guard range.location < attributedString.length, range.length <= attributedString.length else {
            return
        }
        self.currentRange = (range.lowerBound, range.upperBound)
        updateSelection(range: range, animateIn: animated)
    }
    
    private func updateSelection(range: NSRange?, animateIn: Bool) {
        delegate?.selectionViewDidChangeSelectedRange(self)
        
        var rects: (rects: [CGRect], start: CGRect, end: CGRect)?
        if let range {
            rects = textView.rangeRects(in: range)
        }
        self.currentRects = rects?.rects
        
        if let (selectionRects, startRect, endRect) = rects, !selectionRects.isEmpty {
            let highlightOverlay: DTTextSelectionHighlightingView
            if let current = self.highlightOverlay {
                highlightOverlay = current
            } else {
                let selectionColor = Theme.themeBlueColor.withAlphaComponent(0.4)
                highlightOverlay = DTTextSelectionHighlightingView(color: selectionColor)
                highlightOverlay.isUserInteractionEnabled = false
                highlightOverlay.innerRadius = 2.0
                highlightOverlay.outerRadius = 2.0
                highlightOverlay.inset = 1.0
                highlightOverlay.useModernPathCalculation = true
                
                self.highlightOverlay = highlightOverlay
                self.highlightAreaView.addSubview(highlightOverlay)
            }
            highlightOverlay.frame = self.bounds
            highlightOverlay.updateRects(selectionRects)
            
            if let image = self.leftKnob.image {
                self.leftKnob.frame = CGRect(
                    x: floor(startRect.x - image.size.width / 2.0),
                    y: startRect.y - Constants.knobDiameter,
                    width: image.size.width,
                    height: Constants.knobDiameter + startRect.height
                )
                self.rightKnob.frame = CGRect(
                    x: floor(endRect.x + 1 - image.size.width / 2.0), // highlightOverlay.inset = 1.0
                    y: endRect.y,
                    width: image.size.width,
                    height: Constants.knobDiameter + endRect.height
                )
            }
            
            if self.leftKnob.alpha.isZero {
                highlightOverlay.layer.animateAlpha(
                    from: 0.0,
                    to: 1.0,
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
                    for rect in selectionRects {
                        if result.isEmpty {
                            result = rect
                        } else {
                            result = result.union(rect)
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
                            y: (-fromResult.midY + highlightOverlay.bounds.midY) / 1.0),
                        to: CGPoint(),
                        duration: 0.26,
                        additive: true
                    )
                }
            }
            
        } else if let highlightOverlay {
            self.highlightOverlay = nil
            highlightOverlay.layer.animateAlpha(
                from: 1.0,
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
    
    func dismissSelection() {
        currentRange = nil
        updateSelection(range: nil, animateIn: false)
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
    
    private func findScrollView(view: UIView?) -> UIScrollView? {
        if let view = view {
            if let view = view as? UIScrollView {
                return view
            }
            return findScrollView(view: view.superview)
        } else {
            return nil
        }
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

private class TextSelectionGestureRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    
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
        } else {
            self.state = .failed
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
        
        if let _ = self.currentLocation, let _ = self.moveKnob {
            self.finishedMovingKnob?()
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

extension UITextView {
    
    func rangeRects(in range: NSRange) -> (rects: [CGRect], start: CGRect, end: CGRect)? {
        guard let attributedText, !attributedText.isEmpty else {
            return nil
        }
        guard let startPosition = position(from: beginningOfDocument, offset: range.location) else {
            return nil
        }
        guard let endPosition = position(from: startPosition, offset: range.length) else {
            return nil
        }
        guard let textRange = textRange(from: startPosition, to: endPosition) else {
            return nil
        }
        let rects = selectionRects(for: textRange).map { $0.rect }
        let start = caretRect(for: startPosition)
        let end = caretRect(for: endPosition)
        return (rects, start, end)
    }
    
}
