//
//  DTSpeakingAnimationView.swift
//  Difft
//
//  Created by Henry on 2025/4/16.
//  Copyright © 2025 Difft. All rights reserved.
//

import UIKit
import PureLayout
import TTMessaging
import Lottie

@objcMembers
class DTSpeakingAnimationView: UIImageView {
    
    @objc enum SpeakingState: Int {
    case muted = 0, // 闭麦
         unmuted,   // 开麦未讲话
         speaking,  // 讲话中
         sharing,   // 分享人未讲话
         none
    }
    
    var state: SpeakingState! {
        willSet {
            setState(newValue)
        }
    }
    
    private var iconColor: UIColor?
    
    func setState(_ state: SpeakingState) {
                
        switch state {
        case .muted:
            animationView.isHidden = true
            var tmpImage = UIImage(named: "call_ic_muted")
            if let iconColor {
                tmpImage = tmpImage?.withTintColor(iconColor)
            }
            image = tmpImage
        case .unmuted:
            animationView.isHidden = true
            image = UIImage(named: "ic_call_unmuted")
        case .speaking:
            animationView.isHidden = false
            image = nil
        case .sharing:
            animationView.isHidden = true
            var tmpImage = UIImage(named: "ic_call_sharing")
            if let iconColor {
                tmpImage = tmpImage?.withTintColor(iconColor)
            }
            image = tmpImage
        case .none:
            animationView.isHidden = true
            image = nil
        }
    }
    
    private var animationView: LottieAnimationView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentMode = .center
        setCompressionResistanceHigh()
        
        setupUI()
    }
    
    convenience init(iconColor: UIColor? = nil) {
        self.init(frame: .zero)
        
        self.iconColor = iconColor
        self.state = .muted
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupUI() {
        
        animationView = DTLottieBridge.animationView("Meeting_Soundwave")
        addSubview(animationView)
        
        animationView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    func setAnimation(file: String) {
        guard let animationView else {
            return
        }
        
        if let animation = LottieAnimation.named(file) {
          animationView.animation = animation
        } else {
          DotLottieFile.named(file) { [animationView] result in
            guard case .success(let lottie) = result else { return }
            animationView.loadAnimation(from: lottie)
          }
        }
        animationView.play()
    }
    
}
