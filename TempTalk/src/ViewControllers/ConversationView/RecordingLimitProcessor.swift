//
//  RecordingLimitProcessor.swift
//  TempTalk
//
//  Created by Kris.s on 2025/6/13.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

protocol RecordingLimitProcessorDelegate: AnyObject {
    func recordingLimitProcessorShouldShowCountdown(secondsLeft: Int)
    func recordingLimitProcessorDidReachLimit()
}

class RecordingLimitProcessor {
    weak var delegate: RecordingLimitProcessorDelegate?

    private let maxDuration: TimeInterval = 180
    private let countdownThreshold: TimeInterval = 10
    private var timer: Timer?
    private var startTime: Date?
    private var countdownStarted = false

    func start() {
        stop()
        startTime = Date()
        countdownStarted = false
        startTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        startTime = nil
        countdownStarted = false
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        guard let startTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        let remaining = maxDuration - elapsed

        if remaining <= countdownThreshold && !countdownStarted {
            countdownStarted = true
        }

        if countdownStarted && remaining > 0 {
            delegate?.recordingLimitProcessorShouldShowCountdown(secondsLeft: Int(ceil(remaining)))
        }

        if remaining <= 0 {
            stop()
            delegate?.recordingLimitProcessorDidReachLimit()
        }
    }
}
