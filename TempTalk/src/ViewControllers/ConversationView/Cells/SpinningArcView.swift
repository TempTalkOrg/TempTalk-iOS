//
//  Copyright (c) 2026 Open Whisper Systems. All rights reserved.
//

import UIKit

/// A white 3/4 circle arc that spins continuously. Re-attaches its rotation
/// animation on window changes (cell reuse) and on foreground, since the system
/// strips CAAnimations off the layer when the app backgrounds and never restores
/// them — without the notification the arc would come back frozen.
final class SpinningArcView: UIView {

    private let arcLayer = CAShapeLayer()
    private let lineWidth: CGFloat

    init(lineWidth: CGFloat) {
        self.lineWidth = lineWidth
        super.init(frame: .zero)
        arcLayer.fillColor = UIColor.clear.cgColor
        arcLayer.strokeColor = UIColor.white.cgColor
        arcLayer.lineWidth = lineWidth
        arcLayer.lineCap = .round
        layer.addSublayer(arcLayer)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        arcLayer.frame = bounds
        let radius = (min(bounds.width, bounds.height) - lineWidth) / 2
        arcLayer.path = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: max(radius, 0),
            startAngle: -.pi / 2,
            endAngle: .pi,
            clockwise: true
        ).cgPath
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            layer.removeAnimation(forKey: "spin")
        } else {
            startSpinning()
        }
    }

    /// Unconditional remove-then-add: whether a backgrounded layer still reports
    /// the animation under `animation(forKey:)` is not contractual, so the guard in
    /// `startSpinning` can't be trusted here. Re-adding snaps the arc back to angle
    /// zero, which is invisible — the screen was off.
    @objc private func applicationDidBecomeActive() {
        guard window != nil else { return }
        layer.removeAnimation(forKey: "spin")
        startSpinning()
    }

    private func startSpinning() {
        guard layer.animation(forKey: "spin") == nil else { return }
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = 2 * CGFloat.pi
        rotation.duration = 1
        rotation.repeatCount = .infinity
        layer.add(rotation, forKey: "spin")
    }
}
