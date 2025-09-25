//
//  RecordingCountdownBubbleView.swift
//  TempTalk
//
//  Created by Kris.s on 2025/6/13.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

class RecordingCountdownBubbleView: UIView {
    private let label = UILabel()
    private let paddingHorizontal: CGFloat = 10
    private let bubbleHeight: CGFloat = 26  // label区域高度
    private let arrowHeight: CGFloat = 6
    private let arrowWidth: CGFloat = 12

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        isHidden = true
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: bubbleHeight + arrowHeight).isActive = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        isHidden = true
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: bubbleHeight + arrowHeight).isActive = true
    }

    private func setupUI() {
        label.font = .systemFont(ofSize: 12)
        label.textColor = .white
        label.numberOfLines = 1
        label.textAlignment = .center

        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor),
            label.heightAnchor.constraint(equalToConstant: 16),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: paddingHorizontal),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -paddingHorizontal),
            // 垂直居中到bubbleHeight区域
            label.centerYAnchor.constraint(equalTo: topAnchor, constant: bubbleHeight / 2)
        ])
    }

    override func draw(_ rect: CGRect) {
        let bubblePath = UIBezierPath()
        let cornerRadius: CGFloat = 4
        let rectWidth = rect.width
        let rectHeight = rect.height - arrowHeight
        let arrowMidX = rect.midX

        // 画圆角矩形部分
        bubblePath.move(to: CGPoint(x: cornerRadius, y: 0))
        bubblePath.addLine(to: CGPoint(x: rectWidth - cornerRadius, y: 0))
        bubblePath.addQuadCurve(to: CGPoint(x: rectWidth, y: cornerRadius),
                                controlPoint: CGPoint(x: rectWidth, y: 0))
        bubblePath.addLine(to: CGPoint(x: rectWidth, y: rectHeight - cornerRadius))
        bubblePath.addQuadCurve(to: CGPoint(x: rectWidth - cornerRadius, y: rectHeight),
                                controlPoint: CGPoint(x: rectWidth, y: rectHeight))
        // 箭头开始
        bubblePath.addLine(to: CGPoint(x: arrowMidX + arrowWidth / 2, y: rectHeight))
        bubblePath.addLine(to: CGPoint(x: arrowMidX, y: rectHeight + arrowHeight))
        bubblePath.addLine(to: CGPoint(x: arrowMidX - arrowWidth / 2, y: rectHeight))
        // 箭头结束
        bubblePath.addLine(to: CGPoint(x: cornerRadius, y: rectHeight))
        bubblePath.addQuadCurve(to: CGPoint(x: 0, y: rectHeight - cornerRadius),
                                controlPoint: CGPoint(x: 0, y: rectHeight))
        bubblePath.addLine(to: CGPoint(x: 0, y: cornerRadius))
        bubblePath.addQuadCurve(to: CGPoint(x: cornerRadius, y: 0),
                                controlPoint: CGPoint(x: 0, y: 0))
        bubblePath.close()

        let context = UIGraphicsGetCurrentContext()
        context?.setFillColor(UIColor(red: 94/255, green: 102/255, blue: 115/255, alpha: 1.0).cgColor)
        context?.addPath(bubblePath.cgPath)
        context?.fillPath()
    }

    func updateText(_ text: String) {
        label.text = text
        setNeedsDisplay()
    }

    func show() {
        isHidden = false
//        alpha = 0
//        UIView.animate(withDuration: 0.2) {
//            self.alpha = 1
//        }
    }

    func hide() {
        isHidden = true
//        UIView.animate(withDuration: 0.2, animations: {
//            self.alpha = 0
//        }) { _ in
//            self.isHidden = true
//        }
    }
}
