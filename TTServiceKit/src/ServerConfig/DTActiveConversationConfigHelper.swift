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
        if thread.isNoteToSelf {
            return entity.activeConversationMe.doubleValue
        } else if thread.isGroupThread() {
            return entity.activeConversationGroup.doubleValue
        } else {
            return entity.activeConversationOthers.doubleValue
        }
    }

    @objc public static func shouldSkipCleanup(forThread thread: TSThread) -> Bool {
        // saved (NoteToSelf) 或 stick 的会话不受影响
        return thread.isNoteToSelf || thread.isSticked
    }
}
