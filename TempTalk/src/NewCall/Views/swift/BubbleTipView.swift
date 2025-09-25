//
//  BubbleTipView.swift
//  Difft
//
//  Created by Henry on 2025/6/11.
//  Copyright © 2025 Difft. All rights reserved.
//

class TriangleView: UIView {
    enum Direction {
        case up, down
    }

    var fillColor: UIColor = .darkGray
    var direction: Direction = .up

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let path = UIBezierPath()
        switch direction {
        case .up:
            path.move(to: CGPoint(x: bounds.midX, y: bounds.minY))
            path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
            path.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        case .down:
            path.move(to: CGPoint(x: bounds.midX, y: bounds.maxY))
            path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
            path.addLine(to: CGPoint(x: bounds.minX, y: bounds.minY))
        }
        path.close()

        context.setFillColor(fillColor.cgColor)
        context.addPath(path.cgPath)
        context.fillPath()
    }
}

class BubbleTipView: UIView {
    private let label = UILabel()
    private let backgroundView = UIView()
    private let triangleView = TriangleView()

    init(text: String) {
        super.init(frame: .zero)

        backgroundColor = .clear

        // 气泡背景
        backgroundView.backgroundColor = .darkGray
        backgroundView.layer.cornerRadius = 8
        backgroundView.translatesAutoresizingMaskIntoConstraints = false

        // 文本
        label.text = text
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        // 箭头
        triangleView.fillColor = .darkGray
        triangleView.direction = .up
        triangleView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(triangleView)
        addSubview(backgroundView)
        backgroundView.addSubview(label)

        // 三角靠右约束
        NSLayoutConstraint.activate([
            triangleView.topAnchor.constraint(equalTo: topAnchor),
            triangleView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -6),
            triangleView.widthAnchor.constraint(equalToConstant: 14),
            triangleView.heightAnchor.constraint(equalToConstant: 8),

            backgroundView.topAnchor.constraint(equalTo: triangleView.bottomAnchor, constant: -2),
            backgroundView.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: 20),
//            backgroundView.centerXAnchor.constraint(equalTo: centerXAnchor),
            backgroundView.widthAnchor.constraint(lessThanOrEqualToConstant: 360),

            label.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -12),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
