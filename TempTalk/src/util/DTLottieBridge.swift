//
//  DTLottieBridge.swift
//  Signal
//
//  Created by Ethan on 08/06/2023.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
import Lottie

@objc
open class DTLottieBridge: NSObject {
    
    @objc(animationViewWithName:)
    class func animationView(_ name: String) -> LottieAnimationView {
        
        let animationView = LottieAnimationView()
        animationView.isUserInteractionEnabled = false
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.animationSpeed = 1
        animationView.backgroundBehavior = .pauseAndRestore
        if let animation = LottieAnimation.named(name) {
          animationView.animation = animation
        } else {
          DotLottieFile.named(name) { [animationView] result in
            guard case Result.success(let lottie) = result else { return }
            animationView.loadAnimation(from: lottie)
          }
        }
        animationView.play()
        
        return animationView
    }
    
}
