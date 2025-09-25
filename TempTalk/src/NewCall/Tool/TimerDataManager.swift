//
//  TimerDataManager.swift
//  TempTalk
//
//  Created by Henry on 2025/3/27.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import SwiftUI
import Combine

//TODO: 和DTMeetingManager+Timer功能有点重合，暂时先只为解决多次渲染问题
class TimerDataManager: ObservableObject {
    static let shared = TimerDataManager()  // 单例实例
    @Published var duration: TimeInterval?
    
    // 用于会议倒计时
    @Published var currentTime: Int = 0 {
        didSet {
            if oldValue != currentTime {
                displayTime = formatTime(currentTime)
                RoomDataManager.shared.pipCountDownUpdate()
            }
        }
    }
    @Published var displayTime: String = "00:00"
    @Published var textColor: UIColor = UIColor(rgbHex: 0xF84135) //F84135
    @Published var isShaking: Bool = false // 动画
    @Published var  isVibrating = false // 震动
    @Published var isShowCountDownView: Bool = false
    @Published var imageName: String = "tabler_stopwatch_red"
    private init() {}  // 防止外部实例化
    
    deinit {
        countDownTimer?.invalidate()
    }
    
    
    private var countDownTimer: Timer?
    private var countdownQueue: [Int] = []
    
    func startCountdown(seconds: Int) {
        countDownTimer?.invalidate()
        currentTime = seconds
        textColor = UIColor(rgbHex: 0x82C1FC)
        imageName = "tabler_stopwatch_blue"
        isShaking = false
        isVibrating = false
        
        countDownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self else { return }
            
            if (self.currentTime > 0) {
                self.currentTime -= 1
            }
            
            if self.currentTime <= 10 && self.currentTime > 0 {
                self.textColor = UIColor(rgbHex: 0xF84135)
                imageName = "tabler_stopwatch_red"
            }
            
            if self.currentTime <= 5 && self.currentTime > 0 {
                isShaking = true
            }
            
            if self.currentTime <= 0 {
                t.invalidate()
                isVibrating = true
                self.textColor = UIColor(rgbHex: 0xF84135)
                imageName = "tabler_stopwatch_red"
                
                // 延迟结束动画与 Timer
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    self.isShaking = false
                    self.isVibrating = false
                    RoomDataManager.shared.pipCountDownUpdate()
                }
            }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let safeSeconds = max(seconds, 0)
        let minutes = safeSeconds / 60
        let secs = safeSeconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
    
    func clearTimerDataSource() {
        DispatchMainThreadSafe {
            self.countDownTimer?.invalidate()
            self.countDownTimer = nil
            self.isShaking = false
            self.isVibrating = false
            self.isShowCountDownView = false
        }
    }
}
