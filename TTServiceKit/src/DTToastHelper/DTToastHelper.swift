//
//  DTToastHelper.swift
//  TTServiceKit
//
//  Created by Henry on 2025/7/31.
//

import Foundation
import Lottie


extension DTToastHelper {
    @objc(animationViewWithName:)
    class open func animationView(_ name: String) -> LottieAnimationView {
        
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
