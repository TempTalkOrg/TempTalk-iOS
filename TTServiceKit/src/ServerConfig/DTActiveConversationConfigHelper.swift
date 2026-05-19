//
//  DTActiveConversationConfigHelper.swift
//  TTServiceKit
//
//  Created by henry on 2026/01/20.
//

import Foundation

@objc public class DTActiveConversationConfigHelper: NSObject {

    @objc public static func getCleanupInterval(forThread thread: TSThread) -> TimeInterval {
        // 使用 DTDisappearanceTimeIntervalConfig 获取配置
        let entity = DTDisappearanceTimeIntervalConfig.fetchDisappearanceTimeInterval()

        // 根据 thread 类型返回对应的间隔
        let interval: TimeInterval
        if thread.isNoteToSelf {
            interval = entity.activeConversationMe.doubleValue
        } else if thread.isGroupThread() {
            interval = entity.activeConversationGroup.doubleValue
        } else {
            interval = entity.activeConversationOthers.doubleValue
        }
        return interval
    }

    @objc public static func shouldSkipCleanup(forThread thread: TSThread) -> Bool {
        return thread.isNoteToSelf || thread.isSticked
    }
}
