//
//  NewCallGlobalConfig.swift
//  TempTalk
//
//  Created by Henry on 2025/3/23.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

struct CallConfig {
    let autoLeave: AutoLeaveConfig
    let chatPresets: [String]
    let muteOtherEnabled: Bool
    let chat: ChatConfig
    let createCallMsg: Bool
    let clusters: [[String: String]]
    let excludedNameRegex: String
    let denoiseMode: String
    let bubbleMessage: BubbleMessageConfig

    // 派生属性
    var soloMemberTimeoutResult: Int {
        autoLeave.promptReminder.soloMemberTimeout
    }

    var silenceTimeoutResult: Int {
        autoLeave.promptReminder.silenceTimeout
    }

    var runAfterReminderTimeoutResult: Int {
        autoLeave.runAfterReminderTimeout
    }

    var autoHideTimeoutResult: Int {
        chat.autoHideTimeout
    }

    init(from dict: [String: Any]) {
        // autoLeave - 使用默认值或解析
        if let autoLeaveDict = dict["autoLeave"] as? [String: Any] {
            self.autoLeave = AutoLeaveConfig(from: autoLeaveDict)
        } else {
            self.autoLeave = AutoLeaveConfig.default
        }

        // chatPresets
        self.chatPresets = dict["chatPresets"] as? [String] ?? []

        // chat
        if let chatDict = dict["chat"] as? [String: Any] {
            self.chat = ChatConfig(from: chatDict)
        } else {
            self.chat = ChatConfig.default
        }

        // createCallMsg
        self.createCallMsg = dict["createCallMsg"] as? Bool ?? false

        // clusters
        if let callServersDict = dict["callServers"] as? [String: Any],
           let clusters = callServersDict["clusters"] as? [[String: String]] {
            self.clusters = clusters
        } else {
            self.clusters = []
        }

        // denoise
        if let denoiseDict = dict["denoise"] as? [String: Any] {
            if let bluetooth = denoiseDict["bluetooth"] as? [String: Any],
               let excludedNameRegex = bluetooth["excludedNameRegex"] as? String {
                self.excludedNameRegex = excludedNameRegex
            } else {
                self.excludedNameRegex = ""
            }
            self.denoiseMode = denoiseDict["mode"] as? String ?? "enhanced"
        } else {
            self.excludedNameRegex = ""
            self.denoiseMode = "enhanced"
        }

        // muteOtherEnabled
        self.muteOtherEnabled = dict["muteOtherEnabled"] as? Bool ?? false

        // bubbleMessage
        if let bubbleMessageDict = dict["bubbleMessage"] as? [String: Any] {
            self.bubbleMessage = BubbleMessageConfig(from: bubbleMessageDict)
        } else {
            self.bubbleMessage = BubbleMessageConfig.default
        }
    }

    // 默认配置
    static let `default` = CallConfig(from: [:])
}

struct AutoLeaveConfig {
    let promptReminder: PromptReminder
    let runAfterReminderTimeout: Int

    init(from dict: [String: Any]) {
        // promptReminder
        if let reminderDict = dict["promptReminder"] as? [String: Any] {
            self.promptReminder = PromptReminder(from: reminderDict)
        } else {
            self.promptReminder = PromptReminder.default
        }

        // runAfterReminderTimeout
        self.runAfterReminderTimeout = Self.parseTimeout(dict["runAfterReminderTimeout"]) ?? 30
    }

    // 统一超时解析方法
    private static func parseTimeout(_ value: Any?) -> Int? {
        switch value {
        case let num as Int: return num
        case let str as String: return Int(str)
        case let num as NSNumber: return num.intValue
        default: return nil
        }
    }

    // 默认配置
    static let `default` = AutoLeaveConfig(from: [:])
}

struct ChatConfig {
    let autoHideTimeout: Int

    init(from dict: [String: Any]) {
        self.autoHideTimeout = Self.parseTimeout(dict["autoHideTimeout"]) ?? 5
    }

    // 统一超时解析方法
    private static func parseTimeout(_ value: Any?) -> Int? {
        switch value {
        case let num as Int: return num
        case let str as String: return Int(str)
        case let num as NSNumber: return num.intValue
        default: return nil
        }
    }

    // 默认配置
    static let `default` = ChatConfig(from: [:])
}

struct PromptReminder {
    let soloMemberTimeout: Int
    let silenceTimeout: Int

    init(from dict: [String: Any]) {
        // 解析 soloMemberTimeout，默认 60 秒
        self.soloMemberTimeout = Self.parseTimeout(dict["soloMemberTimeout"]) ?? 60

        // 解析 silenceTimeout，默认 120 秒
        self.silenceTimeout = Self.parseTimeout(dict["silenceTimeout"]) ?? 120
    }

    // 统一超时解析方法
    private static func parseTimeout(_ value: Any?) -> Int? {
        switch value {
        case let num as Int: return num
        case let str as String: return Int(str)
        case let num as NSNumber: return num.intValue
        default: return nil
        }
    }

    // 默认配置
    static let `default` = PromptReminder(from: [:])
}

struct BubbleMessageConfig {
    let emojiPresets: [String]
    let textPresets: [String]
    let columns: [Int]
    let baseSpeed: Int
    let deltaSpeed: Int

    init(from dict: [String: Any]) {
        // emojiPresets - 默认 emoji 预设
        self.emojiPresets = dict["emojiPresets"] as? [String] ?? [
            "👍",
            "👏",
            "🎉",
            "🚀",
            "❤️",
            "😂"
        ]

        // textPresets - 默认文本预设
        self.textPresets = dict["textPresets"] as? [String] ?? [
            "Agree ✅",
            "Disagree ⛔️",
            "Bye 👋",
            "Can't hear 🙉"
        ]

        // columns - 默认值为屏幕左侧 10%, 40%, 70% 的位置
        self.columns = dict["columns"] as? [Int] ?? [10, 40, 70]

        // baseSpeed - 默认 4600 毫秒
        self.baseSpeed = dict["baseSpeed"] as? Int ?? 4600

        // deltaSpeed - 默认 400 毫秒
        self.deltaSpeed = dict["deltaSpeed"] as? Int ?? 400
    }

    // 默认配置
    static let `default` = BubbleMessageConfig(from: [:])
}

// MARK: - CallConfigManager
class CallConfigManager {

    // 默认配置字典
    private static func defaultConfigDict() -> [String: Any] {
        return [
            "chatPresets": [
                "Good 👍",
                "Bad 😝",
                "Agree ✅",
                "Disagree ❌",
                "Gotta go, bye",
                "Please go faster",
                "Please make screen bigger",
                "Can't hear you. Bad Signal",
                "Can't hear you. Your voice is too low"
            ],
            "muteOtherEnabled": false,
            "createCallMsg": false,
            "autoLeave": [
                "promptReminder": [
                    "soloMemberTimeout": 60000,
                    "silenceTimeout": 120000
                ],
                "runAfterReminderTimeout": 30000
            ],
            "chat": [
                "autoHideTimeout": 5000
            ],
            "bubbleMessage": [
                "emojiPresets": ["👍", "👏", "🎉", "🚀", "❤️", "😂"],
                "textPresets": ["Agree ✅", "Disagree ⛔️", "Bye 👋", "Can't hear 🙉"],
                "columns": [10, 40, 70],
                "baseSpeed": 4600,
                "deltaSpeed": 400
            ],
            "callServers": [
                "clusters": []
            ],
            "denoise": [
                "bluetooth": [
                    "excludedNameRegex": "AirPodsDisable"
                ],
                "mode": "enhanced"
            ]
        ]
    }

    // 同步获取配置（参考 DTGroupConfig 的实现）
    static func fetchCallConfig() -> CallConfig {
        var result: CallConfig!

        DTServerConfigManager.shared().fetchConfigFromLocal(withSpaceName: "call") { config, error in
            var finalConfig = defaultConfigDict()

            // 如果获取成功，合并配置（服务器配置覆盖默认配置）
            if error == nil, let serverConfig = config as? [String: Any] {
                finalConfig = mergeConfig(base: finalConfig, override: serverConfig)
            }

            // 创建 CallConfig 对象
            result = CallConfig(from: finalConfig)
        }

        return result
    }

    // 递归合并配置字典
    private static func mergeConfig(base: [String: Any], override: [String: Any]) -> [String: Any] {
        var merged = base

        for (key, value) in override {
            if let baseDict = base[key] as? [String: Any],
               let overrideDict = value as? [String: Any] {
                // 递归合并嵌套字典
                merged[key] = mergeConfig(base: baseDict, override: overrideDict)
            } else {
                // 直接覆盖
                merged[key] = value
            }
        }

        return merged
    }
}

