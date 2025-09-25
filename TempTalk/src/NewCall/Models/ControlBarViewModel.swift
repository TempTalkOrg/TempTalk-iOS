
//
//  ControlBarViewModel.swift
//  Difft
//
//  Created by Henry on 2025/4/30.
//  Copyright © 2025 Difft. All rights reserved.
//


class ControlBarViewModel: ObservableObject {
    @Published var showControls = true
    private var startSharingTime: Date?
    private var hideControlsWorkItem: DispatchWorkItem?

    // 用于触发隐藏控制视图的逻辑
    func hiddenTopBottomBar() {
        self.startSharingTime = Date()
        
        // 如果有先前的延迟任务，取消它
        hideControlsWorkItem?.cancel()
        
        // 创建新的延迟任务
        hideControlsWorkItem = DispatchWorkItem {
            // 延迟 3 秒后检查是否隐藏控制视图
            if let startTime = self.startSharingTime, Date().timeIntervalSince(startTime) >= 3 {
                self.showControls = false
            }
        }
        
        // 延迟 3 秒后执行任务
        if let hideControlsWorkItem = hideControlsWorkItem {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: hideControlsWorkItem)
        }
    }

    // 触发控制视图的显示逻辑（例如按键事件）
    func userPressedButton() {
        // 按键时，重置显示控制视图的状态
        self.showControls = true
        // 重新调用隐藏控制视图的方法
        hiddenTopBottomBar()
    }
}
