//
//  FloatingConversationConfiguration.swift
//  TempTalk
//
//  Created by henry on 2025-12-26.
//  Copyright © 2025 Difft Inc. All rights reserved.
//

import UIKit

/// 浮动聊天窗口的转场动画风格
enum FloatingTransitionStyle {
    case push      // 从右侧滑入/滑出（类似 navigationController push）
    case present   // 从底部滑入/滑出（类似 modal present）
}

/// 浮动聊天窗口的高度模式
enum FloatingHeightMode {
    case compact      // 初始状态（如 50%）
    case expanded     // 键盘弹出后/保持状态（如 90%）
    case fullscreen   // 全屏状态（100%）

    func height(for screenHeight: CGFloat, config: FloatingConversationConfiguration) -> CGFloat {
        // 如果设置了固定高度，优先使用固定高度
        if let fixedHeight = config.fixedHeight {
            return fixedHeight
        }

        switch self {
        case .compact:
            return screenHeight * config.compactHeightRatio
        case .expanded:
            return screenHeight * config.expandedHeightRatio
        case .fullscreen:
            return screenHeight
        }
    }
}

/// 浮动聊天窗口的配置
struct FloatingConversationConfiguration {
    /// 初始高度比例（compact模式）
    let compactHeightRatio: CGFloat

    /// 固定高度（如果设置了固定高度，则忽略比例）
    let fixedHeight: CGFloat?

    /// 键盘弹出时的高度比例（expanded模式）
    let expandedHeightRatio: CGFloat

    /// 转场动画风格
    let transitionStyle: FloatingTransitionStyle

    /// 是否显示顶部拖动条
    let showDragIndicator: Bool

    /// 遮罩层透明度
    let dimViewAlpha: CGFloat

    /// 点击遮罩是否关闭
    let dismissOnDimViewTap: Bool

    /// 是否支持下拉关闭
    let enablePullToDismiss: Bool

    /// 下拉关闭的阈值（相对于容器高度）
    let pullToDismissThreshold: CGFloat

    /// 圆角半径（仅present风格生效）
    let cornerRadius: CGFloat

    /// 高度变化动画时长
    let heightAnimationDuration: TimeInterval

    /// 弹窗消失动画时长
    let dismissAnimationDuration: TimeInterval

    /// 是否显示全屏按钮
    let showFullscreenButton: Bool

    // MARK: - Initializer

    init(compactHeightRatio: CGFloat = 0.5,
         expandedHeightRatio: CGFloat = 0.9,
         fixedHeight: CGFloat? = nil,
         transitionStyle: FloatingTransitionStyle = .push,
         showDragIndicator: Bool = true,
         dimViewAlpha: CGFloat = 0.5,
         dismissOnDimViewTap: Bool = true,
         enablePullToDismiss: Bool = true,
         pullToDismissThreshold: CGFloat = 0.3,
         cornerRadius: CGFloat = 16,
         heightAnimationDuration: TimeInterval = 0.3,
         dismissAnimationDuration: TimeInterval = 0.25,
         showFullscreenButton: Bool = true) {
        self.compactHeightRatio = compactHeightRatio
        self.expandedHeightRatio = expandedHeightRatio
        self.fixedHeight = fixedHeight
        self.transitionStyle = transitionStyle
        self.showDragIndicator = showDragIndicator
        self.dimViewAlpha = dimViewAlpha
        self.dismissOnDimViewTap = dismissOnDimViewTap
        self.enablePullToDismiss = enablePullToDismiss
        self.pullToDismissThreshold = pullToDismissThreshold
        self.cornerRadius = cornerRadius
        self.heightAnimationDuration = heightAnimationDuration
        self.dismissAnimationDuration = dismissAnimationDuration
        self.showFullscreenButton = showFullscreenButton
    }

    // MARK: - 预设配置

    /// 默认配置（50% → 90% → 100%）
    static var `default`: FloatingConversationConfiguration {
        return FloatingConversationConfiguration(
            compactHeightRatio: 0.5,
            expandedHeightRatio: 0.9,
            transitionStyle: .push,  // 改为push风格，进来时从右往左滑入
            showDragIndicator: true,
            dimViewAlpha: 0.5,
            dismissOnDimViewTap: true,
            enablePullToDismiss: true,
            pullToDismissThreshold: 0.3,
            cornerRadius: 16,
            heightAnimationDuration: 0.3,
            showFullscreenButton: true
        )
    }

    /// Push风格配置（全屏）
    static var pushStyle: FloatingConversationConfiguration {
        return FloatingConversationConfiguration(
            compactHeightRatio: 1.0,
            expandedHeightRatio: 1.0,
            transitionStyle: .push,
            showDragIndicator: false,
            dimViewAlpha: 0,
            dismissOnDimViewTap: false,
            enablePullToDismiss: false,
            pullToDismissThreshold: 0,
            cornerRadius: 0,
            heightAnimationDuration: 0.3,
            showFullscreenButton: false
        )
    }

    /// 机密消息提示配置（固定高度220）
    static var confidentialAlert: FloatingConversationConfiguration {
        return FloatingConversationConfiguration(
            compactHeightRatio: 0.0,
            expandedHeightRatio: 0.0,
            fixedHeight: 220,
            transitionStyle: .present,
            showDragIndicator: false,
            dimViewAlpha: 0.5,
            dismissOnDimViewTap: false,
            enablePullToDismiss: false,
            pullToDismissThreshold: 0,
            cornerRadius: 16,
            heightAnimationDuration: 0.5,
            dismissAnimationDuration: 0.2,
            showFullscreenButton: false
        )
    }
}
