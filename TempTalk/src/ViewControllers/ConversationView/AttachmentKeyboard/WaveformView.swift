//
//  WaveformView.swift
//  TempTalk
//
//  Created by undefined on 7/12/24.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit

class WaveformView: UIView {

    private var amplitudes = [Float]()
    private var animationJob: DispatchSourceTimer?

    // 设定每根柱子的固定高度
    private let baseHeights: [CGFloat] = [5, 8, 10]  // 单位：点
    
    // 当前显示的柱子数量
    private var visibleBars = 1
    
    // 振幅最大值（用来归一化）
    private var maxAmplitude: Float = 0
    
    // 圆角半径
    private let cornerRadius: CGFloat = 3  // 单位：点
    
    // 设置柱子的颜色
    private var barColor: UIColor = .white

    // 设置柱子的颜色
    func setBarColor(color: UIColor) {
        self.barColor = color
        setNeedsDisplay() // 更新颜色后标记视图需要重新绘制
    }

    // 开始动画：自动更新随机振幅
    func startAnimation() {
        // 使用 DispatchSourceTimer 来定时更新振幅
        animationJob = DispatchSource.makeTimerSource(queue: .main)
        animationJob?.schedule(deadline: .now(), repeating: .milliseconds(300)) // 每50ms更新一次
        animationJob?.setEventHandler { [weak self] in
            self?.updateRandomAmplitude()
        }
        animationJob?.resume()
    }

    // 停止动画
    func stopAnimation() {
        animationJob?.cancel()
        amplitudes.removeAll()
        setNeedsDisplay() // 停止动画后标记视图需要重新绘制
    }

    // 随机更新振幅并更新柱子数量
    private func updateRandomAmplitude() {
        // 随机生成一个振幅值 (0 到 1 之间)
        let randomAmplitude = Float.random(in: 0...1)
        
        // 更新最大振幅值
        maxAmplitude = max(maxAmplitude, randomAmplitude)

        // 归一化振幅到 0 到 1 的范围
        let normalizedAmplitude = randomAmplitude / maxAmplitude

        // 保持最多 20 个振幅值
        if amplitudes.count >= 20 {
            amplitudes.remove(at: 0)
        }
        amplitudes.append(normalizedAmplitude)

        // 根据归一化后的振幅动态调整柱子数量
        visibleBars = {
            switch normalizedAmplitude {
            case ..<0.3:
                return 1 // 振幅较低时显示 1 根柱子
            case ..<0.6:
                return 2 // 中等振幅时显示 2 根柱子
            default:
                return 3 // 高振幅时显示 3 根柱子
            }
        }()

        // 重绘视图
        setNeedsDisplay() // 视图需要重新绘制
    }

    // 重写 draw 方法来绘制柱状图
    override func draw(_ rect: CGRect) {
        super.draw(rect)

        if amplitudes.isEmpty { return }

        let centerX = bounds.width / 2 // X 轴中心点
        let barWidth: CGFloat = 3  // 每根柱子的宽度

        // 获取当前绘制上下文
        guard let context = UIGraphicsGetCurrentContext() else { return }

        // 设置柱子颜色
        barColor.setFill()

        // 绘制显示的柱子
        for i in 0..<visibleBars {
            let barHeight = baseHeights[i] // 固定柱子高度
            let xPosition = centerX + CGFloat(i - 1) * (barWidth + 2) // 将柱子稍微分开
            let yPosition = (bounds.height - barHeight) / 2 // 垂直居中

            // 绘制每根带圆角的柱子
            let barRect = CGRect(x: xPosition, y: yPosition, width: barWidth, height: barHeight)
            context.addPath(UIBezierPath(roundedRect: barRect, cornerRadius: cornerRadius).cgPath)
            context.fillPath()
        }
    }
}
