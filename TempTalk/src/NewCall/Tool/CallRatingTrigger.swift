//
//  CallRatingTrigger.swift
//  Difft
//
//  Created by henry on 2025/10/15.
//  Copyright © 2025 Difft. All rights reserved.
//

final class CallRatingTrigger {
    static let shared = CallRatingTrigger()
    private init() {}

    private let userDefaults = UserDefaults.standard

    private let thresholdKey = "CallRatingTriggerThreshold"
    private let dateKey = "CallRatingTriggerDate"
    private let countKey = "CallRatingDailyCount"
    private let triggeredKey = "CallRatingTriggered"

    /// 阈值范围，例如 1~5 次通话内随机一次
    private let range = 1...5

    /// 通话结束时调用
    /// - Parameter hasSevereQualityIssue: 是否存在网络差或丢包
    /// - Returns: true 表示今天应弹出评分
    func shouldTriggerRating(hasSevereQualityIssue: Bool) -> Bool {
        let today = Self.currentDateString()
        let savedDate = userDefaults.string(forKey: dateKey)

        // 如果是新的一天，重置所有状态
        if savedDate != today {
            let threshold = Int.random(in: range)
            userDefaults.set(threshold, forKey: thresholdKey)
            userDefaults.set(today, forKey: dateKey)
            userDefaults.set(0, forKey: countKey)
            userDefaults.set(false, forKey: triggeredKey)
            print("[Rating] 🎲 New day: \(today), threshold=\(threshold)")
        }

        // 如果今天已经弹过，就不再弹
        if userDefaults.bool(forKey: triggeredKey) {
            print("[Rating] 🚫 Already triggered today")
            return false
        }

        // 增加通话次数
        let newCount = userDefaults.integer(forKey: countKey) + 1
        userDefaults.set(newCount, forKey: countKey)

        let threshold = userDefaults.integer(forKey: thresholdKey)

        // ✅ 情况 1：通话中出现严重网络问题，立即触发
        if hasSevereQualityIssue {
            userDefaults.set(true, forKey: triggeredKey)
            print("[Rating] ⚠️ Trigger due to poor network, count=\(newCount)")
            return true
        }

        // ✅ 情况 2：当天通话次数等于阀值时触发
        if newCount == threshold {
            userDefaults.set(true, forKey: triggeredKey)
            print("[Rating] ✅ Trigger by threshold: \(newCount)")
            return true
        }

        print("[Rating] ⏭️ Skip: count=\(newCount), threshold=\(threshold)")
        return false
    }

    // MARK: - Helpers
    private static func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
