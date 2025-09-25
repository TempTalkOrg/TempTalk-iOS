//
//  DTFloatingView.swift
//  Signal
//
//  Created by Ethan on 20/02/2024.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit
import TTServiceKit
import PureLayout

@objcMembers
class DTFloatingView: UIView {
    
    var floatViewAction: ( () -> Void )?
    var lastOrigion: NSValue!
    var origionConstraints: [NSLayoutConstraint]!
    private var btnAction: UIButton!
    private var stateView: UIImageView!
    private var lbState: UILabel!
    private var touchPoint: CGPoint!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupUI() {
        
        lastOrigion = NSValue(cgPoint: CGPoint(x: 5, y: 150))
        backgroundColor = UIColor(rgbHex: 0x333333)
        layer.cornerRadius = 5
        layer.borderWidth = 1
        layer.masksToBounds = true
        layer.borderColor = UIColor.white.cgColor
        autoSetDimensions(to: CGSize(width: 80, height: 100))
        
        stateView = UIImageView(image: UIImage(named: "floating_voice"))
        addSubview(stateView)
        
        lbState = UILabel()
        lbState.numberOfLines = 1
        lbState.textColor = .white
        lbState.font = .systemFont(ofSize: 14)
        lbState.text = Localized("SINGLE_CALL_CALLING")
        addSubview(lbState)

        btnAction = UIButton(type: .custom)
        btnAction.addTarget(self, action: #selector(btnActionClick), for: .touchUpInside)
        addSubview(btnAction)
        
        stateView.autoPinEdge(toSuperviewEdge: .top, withInset: 10)
        stateView.autoAlignAxis(toSuperviewMarginAxis: .vertical)
        stateView.autoSetDimensions(to: .square(50))
        
        lbState.autoPinEdge(.top, to: .bottom, of: stateView, withOffset: 10)
        lbState.autoAlignAxis(toSuperviewMarginAxis: .vertical)

        btnAction.autoPinEdgesToSuperviewEdges()
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }
    
    @objc
    func btnActionClick() {
        guard let floatViewAction else {
            return
        }
        
        floatViewAction()
    }
    
    @objc
    func handlePan(_ pan: UIPanGestureRecognizer) {
        guard let superview else { return }
        
        let point = pan.location(in: superview)
        let btnWidth = bounds.width, btnHeight = bounds.height
        switch pan.state {
        case .began:
            touchPoint = point
            break
        case .changed:
            var tmpFrame = frame
            tmpFrame.x = frame.x + (point.x - touchPoint.x)
            tmpFrame.y = frame.y + (point.y - touchPoint.y)
            touchPoint = point
            frame = tmpFrame
            break
        case .ended:
            var nbtnX: CGFloat = 0, nbtnY: CGFloat = frame.origin.y
            if centerX >= superview.width/2 {
                nbtnX = superview.width - btnWidth - 5
            } else {
                nbtnX = 5
            }
            if frame.y < 100 {
                nbtnY = 100
            } else if frame.y + btnHeight > superview.height - 90 {
                nbtnY = superview.height - btnHeight - 90
            }
            let tmpLastOrigion = CGPoint(x: superview.width - btnWidth - nbtnX, y: nbtnY)
            lastOrigion = NSValue(cgPoint: tmpLastOrigion)
            if !origionConstraints.isEmpty {
                NSLayoutConstraint.deactivate(origionConstraints)
            }
            origionConstraints = [
                autoPinEdge(toSuperviewEdge: .trailing, withInset: tmpLastOrigion.x),
                autoPinEdge(toSuperviewEdge: .top, withInset: tmpLastOrigion.y)
            ]
            UIView.animate(withDuration: 0.3) { [self] in
                frame = CGRectMake(nbtnX, nbtnY, btnWidth, btnHeight)
                layoutIfNeeded()
            }
            break
        default: break
        }
        
    }
    
}
