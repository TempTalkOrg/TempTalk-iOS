//
//  SwingingAlarmView.swift
//  Difft
//
//  Created by Henry on 2025/6/25.
//  Copyright © 2025 Difft. All rights reserved.
//

import UIKit

class SwingingAlarmView: UIView, CAAnimationDelegate {

    private let imageView = UIImageView()
    private let textLabel = UILabel()
    private var rotationDirection: CGFloat = 1
    private var vibrationTimer: Timer?
    private var isAnimating = false
    private var isVibrating = false

    var imageName: String = "" {
        didSet { imageView.image = UIImage(named: imageName) }
    }

    var message: String = "" {
        didSet { textLabel.text = message }
    }

    var textColor: UIColor = .white {
        didSet { textLabel.textColor = textColor }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    deinit {
        vibrationTimer?.invalidate()
    }

    private func setupUI() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.widthAnchor.constraint(equalToConstant: 14).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 14).isActive = true

        textLabel.translatesAutoresizingMaskIntoConstraints = false
        textLabel.font = UIFont.systemFont(ofSize: 12)

        let stack = UIStackView(arrangedSubviews: [imageView, textLabel])
        stack.axis = .horizontal
        stack.spacing = 2
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        stack.setContentHuggingPriority(.required, for: .horizontal)
        stack.setContentHuggingPriority(.required, for: .vertical)

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    func startSwinging() {
        guard !isAnimating else { return }
        isAnimating = true
        applySwingAnimation()
    }

    func stopSwinging() {
        self.layer.removeAnimation(forKey: "swing")
        self.isAnimating = false
    }

    func startVibrating() {
        guard !isVibrating else { return }
        isVibrating = true

        stopVibration() // 确保没有重复
        vibrationTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }

    func stopVibrating() {
        isVibrating = false
        stopVibration()
    }

    private func applySwingAnimation() {
        if layer.animation(forKey: "swing") != nil {
            return
        }

        let animation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        animation.values = [
            0.0,
            -Double.pi / 18,
            Double.pi / 18,
            -Double.pi / 18,
            Double.pi / 18,
            0.0
        ]
        animation.keyTimes = [0, 0.1, 0.3, 0.5, 0.7, 1.0] as [NSNumber]
        animation.duration = 1.2
        animation.repeatCount = 7
        animation.delegate = self
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        layer.add(animation, forKey: "swing")
    }

    private func stopVibration() {
        vibrationTimer?.invalidate()
        vibrationTimer = nil
    }

    // MARK: - CAAnimationDelegate
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        stopVibration()
    }
}
