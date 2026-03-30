//
//  DTEmojiFlyingView.swift
//  Difft
//
//  Created by Ethan on 30/09/2025.
//  Copyright © 2025 Difft. All rights reserved.
//

import UIKit
import TTServiceKit

@objc enum DTMeetingUIOrientation: Int {
    case portrait = 0, landscape
}

class DTEmojiFlyingView: UIView {

    private var activeAnimations: [UIView] = []
    private var processedMessageKeys = AtomicArray<String>(lock: .sharedGlobal)
    private var orientation: DTMeetingUIOrientation = .portrait
    private var containerSize: CGSize = .zero
    private let instanceID = UUID().uuidString.prefix(8)

    override init(frame: CGRect) {
        super.init(frame: frame)
        Logger.info("[BulletChat] DTEmojiFlyingView[\(instanceID)] init with frame: \(frame)")
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    @objc convenience init(orientation: DTMeetingUIOrientation) {
        self.init(frame: .zero)
        self.orientation = orientation

        setupView()
        Logger.info("[BulletChat] DTEmojiFlyingView[\(instanceID)] convenience init with orientation: \(orientation.rawValue)")
    }

    deinit {
        clearAllAnimations()
        Logger.info("[BulletChat] DTEmojiFlyingView[\(instanceID)] deinit")
    }

    private func setupView() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    // 更新屏幕方向
    @objc func updateOrientation(_ newOrientation: DTMeetingUIOrientation) {
        orientation = newOrientation
    }

    // 更新容器尺寸
    @objc func updateContainerSize(_ size: CGSize) {
        containerSize = size
        Logger.info("[BulletChat] DTEmojiFlyingView[\(instanceID)] updateContainerSize: \(size), bounds: \(bounds.size), frame: \(frame), orientation: \(orientation.rawValue)")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 当 bounds 更新时，同步更新 containerSize
        if bounds.size != .zero {
            let oldSize = containerSize
            containerSize = bounds.size
            Logger.info("[BulletChat] DTEmojiFlyingView[\(instanceID)] layoutSubviews - frame: \(frame), bounds updated from \(oldSize) to \(containerSize)")
        }
    }
    
    @objc func addFlyingEmoji(_ bulletMessage: DTBulletChatModel) {
        // 使用复合键（时间戳 + ID）进行去重，避免快速发送消息时的时间戳冲突
        let messageKey = "\(bulletMessage.timestamp)_\(bulletMessage.id)"

        guard !processedMessageKeys.get().contains(messageKey) else {
            return
        }
        processedMessageKeys.append(messageKey)

        var senderName = "You"
        // 如果 bulletMessage.name 不为空，使用它（可能是格式化后的文本）
        if !bulletMessage.name.isEmpty {
            senderName = bulletMessage.name
        } else if let localNumber = TSAccountManager.localNumber(), localNumber != bulletMessage.id {
            senderName = Environment.shared.contactsManager.displayName(forPhoneIdentifier: bulletMessage.id)
        }

        addFlyingEmoji(bulletMessage.text, senderName: senderName)
    }
    
    /// 添加飞行的 emoji
    /// - Parameters:
    ///   - emoji: 要显示的 emoji 字符
    ///   - senderName: 发送者名字
    private func addFlyingEmoji(_ emoji: String, senderName: String) {
        Logger.info("[BulletChat] DTEmojiFlyingView[\(instanceID)] addFlyingEmoji called - emoji: \(emoji), sender: \(senderName)")

        let emojiItem = createEmojiItem(emoji: emoji, senderName: senderName)
        addSubview(emojiItem)
        activeAnimations.append(emojiItem)

        // 获取配置
        let config = DTMeetingManager.shared.bubbleMessageConfig()
        let columns = config.columns

        // 从配置的列位置中随机选择一个
        let randomColumn = columns.randomElement() ?? 40

        // 宽度：优先使用 containerSize.width（如果 > 0），否则使用 bounds.width
        // 高度：始终使用 bounds.height（因为 containerSize.height 传入的是 0）
        let effectiveWidth = containerSize.width > 0 ? containerSize.width : bounds.width
        let effectiveHeight = bounds.height

        Logger.info("[BulletChat] DTEmojiFlyingView[\(instanceID)] Size - containerSize: \(containerSize), bounds: \(bounds.size), frame: \(frame), effective: (\(effectiveWidth), \(effectiveHeight))")

        // 根据屏幕方向计算发射位置
        let leftX: CGFloat
        if orientation == .portrait {
            // 竖屏：emoji 左侧对齐到 randomColumn 百分比位置
            leftX = effectiveWidth * CGFloat(randomColumn) / 100.0
        } else {
            // 横屏：限制在屏幕左侧 50% 的区域内，emoji 左侧对齐到 randomColumn 百分比位置
            // 添加左侧边距以避免与横屏模式下的 UI 元素（如参会人列表）重叠
            let landscapeLeftMargin: CGFloat = 100
            let referenceWidth = effectiveWidth * 0.5
            leftX = referenceWidth * CGFloat(randomColumn) / 100.0 + landscapeLeftMargin
        }

        // 计算 centerX（左侧位置 + 一半宽度）
        let centerX = leftX + emojiItem.bounds.width / 2

        // 从屏幕底部往上 120pt 的位置开始
        let startY = effectiveHeight - 120
        emojiItem.center = CGPoint(x: centerX, y: startY)

        Logger.info("[BulletChat] DTEmojiFlyingView[\(instanceID)] Position - orientation: \(orientation.rawValue), randomColumn: \(randomColumn)%, leftX: \(leftX), centerX: \(centerX), startY: \(startY), emojiItemSize: \(emojiItem.bounds.size), emojiItemFrame: \(emojiItem.frame)")

        // 开始动画
        animateEmojiUp(emojiItem)
    }
    
    private func createEmojiItem(emoji: String, senderName: String) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        
        let lbEmoji = UILabel()
        lbEmoji.text = emoji
        lbEmoji.font = UIFont.systemFont(ofSize: 48)
        lbEmoji.textAlignment = .center
        lbEmoji.backgroundColor = .clear
        
        // 创建背景视图
        let nameBgView = UIView()
        nameBgView.backgroundColor = Theme.dark.bg3Color.withAlphaComponent(0.8)
        nameBgView.layer.cornerRadius = 4
        nameBgView.layer.masksToBounds = true
        
        let lbName = UILabel()
        lbName.text = senderName
        lbName.font = UIFont.systemFont(ofSize: 14)
        lbName.textColor = Theme.dark.tprimaryColor
        lbName.textAlignment = .center
        lbName.backgroundColor = .clear
        lbName.numberOfLines = 1
        lbName.lineBreakMode = .byTruncatingTail
        
        lbName.sizeToFit()
        let padding: CGFloat = 6

        let nameTextWidth = lbName.frame.width
        let totalWidth = min(200, nameTextWidth + padding * 2)
        
        // 背景视图的宽度等于总宽度
        nameBgView.frame = CGRect(x: 0, y: 0, width: totalWidth, height: 24)
        
        // label的宽度减去padding，确保文字不会贴边
        let labelWidth = totalWidth - padding * 2
        lbName.frame = CGRect(x: 0, y: 0, width: labelWidth, height: 24)
        
        containerView.addSubview(lbEmoji)
        containerView.addSubview(nameBgView)
        nameBgView.addSubview(lbName)
        
        let totalHeight: CGFloat = 80
        
        containerView.frame = CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight)
        
        lbEmoji.frame = CGRect(
            x: (totalWidth - 48) / 2,
            y: 0,
            width: 48,
            height: 48
        )
        
        nameBgView.center = CGPoint(
            x: totalWidth / 2,
            y: 68
        )
        
        lbName.center = CGPoint(
            x: nameBgView.bounds.width / 2,
            y: nameBgView.bounds.height / 2
        )
        
        return containerView
    }
    
    private func animateEmojiUp(_ emojiItem: UIView) {
        // 计算终点位置（顶部随机位置）
        let endX = emojiItem.center.x + CGFloat.random(in: -20...20)
        let endY: CGFloat = 80

        // 添加淡入效果
        emojiItem.alpha = 0
        UIView.animate(withDuration: 0.3) {
            emojiItem.alpha = 1
        }

        // 直接在这里管理速度配置，根据屏幕方向使用不同速度
        let baseSpeed: Int
        let deltaSpeed = 400  // 速度浮动范围 ±400 毫秒

        if orientation == .landscape {
            // 横屏：更快的速度 1000 毫秒（1秒）
            baseSpeed = 1500
        } else {
            // 竖屏：基础速度 3000 毫秒（3秒）
            baseSpeed = 3000
        }

        // 计算动画时长：baseSpeed ± deltaSpeed 的随机值，转换为秒
        let randomOffset = Int.random(in: -deltaSpeed...deltaSpeed)
        let durationMs = baseSpeed + randomOffset
        let duration = TimeInterval(durationMs) / 1000.0

        // 主要的上浮动画
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveEaseOut],
            animations: {
                emojiItem.center = CGPoint(x: endX, y: endY)
                // 添加轻微的缩放效果
                emojiItem.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            }
        ) { [weak self] _ in
            // 动画完成后移除
            emojiItem.removeFromSuperview()
            self?.removeFromActiveAnimations(emojiItem)
        }

        // 单独的淡出动画，在一半时间后开始
        UIView.animate(
            withDuration: duration / 2,
            delay: duration / 2,
            options: [],
            animations: {
                emojiItem.alpha = 0
            }
        )

        // 添加轻微的左右摆动效果
//        addSwayAnimation(to: emojiItem)
    }
    
    private func addSwayAnimation(to view: UIView) {
        let swayAnimation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        swayAnimation.values = [0, 10, -10, 8, -8, 5, -5, 0]
        swayAnimation.duration = 4.0
        swayAnimation.repeatCount = 1
        swayAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        view.layer.add(swayAnimation, forKey: "sway")
    }
    
    private func removeFromActiveAnimations(_ view: UIView) {
        if let index = activeAnimations.firstIndex(of: view) {
            activeAnimations.remove(at: index)
        }
    }
    
    func clearAllAnimations() {
        for view in activeAnimations {
            view.layer.removeAllAnimations()
            view.removeFromSuperview()
        }
        activeAnimations.removeAll()
    }
    
    func addMultipleEmojis(_ emojis: [(emoji: String, sender: String)]) {
        for (index, item) in emojis.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.3) {
                self.addFlyingEmoji(item.emoji, senderName: item.sender)
            }
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // 让触摸事件穿透，不拦截任何交互
        return nil
    }
    
}

extension DTEmojiFlyingView {
    
    /// 快速添加单个 emoji
    func showEmoji(_ emoji: String, from sender: String) {
        addFlyingEmoji(emoji, senderName: sender)
    }
    
    /// 添加点赞效果（连续多个👍）
    func showLikeEffect(from sender: String, count: Int = 3) {
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.2) {
                self.addFlyingEmoji("👍", senderName: sender)
            }
        }
    }
}
