//
//  NewCallGlobalConfig.swift
//  TempTalk
//
//  Created by Henry on 2025/3/23.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

struct CallConfig {
    var autoLeave: AutoLeaveConfig?
    var chatPresets: [String] = []
    var muteOtherEnabled: Bool = false
    let chat: ChatConfig?
    var createCallMsg: Bool = false
    var clusters: [[String: String]] = []
    var excludedNameRegex: String = ""

    // 派生属性
    var soloMemberTimeoutResult: Int? {
        autoLeave?.promptReminder.soloMemberTimeout
    }
    
    var silenceTimeoutResult: Int? {
        autoLeave?.promptReminder.silenceTimeout
    }
    
    var runAfterReminderTimeoutResult: Int? {
        autoLeave?.runAfterReminderTimeout
    }
    
    var autoHideTimeoutResult: Int? {
        chat?.autoHideTimeout
    }

    init?(from dict: [String: Any]) {
        // autoLeave
        if let autoLeaveDict = dict["autoLeave"] as? [String: Any] {
            self.autoLeave = AutoLeaveConfig(from: autoLeaveDict)
        }

        // chatPresets
        if let chatPresets = dict["chatPresets"] as? [String] {
            self.chatPresets = chatPresets
        }

        // chat
        if let chatDict = dict["chat"] as? [String: Any] {
            self.chat = ChatConfig(from: chatDict)
        } else {
            self.chat = nil // ✅ 因为 chat 是 let，必须显式初始化
        }

        // createCallMsg
        if let createCallMsg = dict["createCallMsg"] as? Bool {
            self.createCallMsg = createCallMsg
        }

        // clusters
        if let callServersDict = dict["callServers"] as? [String: Any],
           let clusters = callServersDict["clusters"] as? [[String: String]] {
            self.clusters = clusters
        }

        // excludedNameRegex
        if let denoiseDict = dict["denoise"] as? [String: Any],
           let bluetooth = denoiseDict["bluetooth"] as? [String: Any],
           let excludedNameRegex = bluetooth["excludedNameRegex"] as? String {
            self.excludedNameRegex = excludedNameRegex
        }

        // muteOtherEnabled
        if let muteOtherEnabled = dict["muteOtherEnabled"] as? Bool {
            self.muteOtherEnabled = muteOtherEnabled
        }
    }
}

struct AutoLeaveConfig {
    let promptReminder: PromptReminder
    let runAfterReminderTimeout: Int
    
    init?(from dict: [String: Any]) {
        guard let reminderDict = dict["promptReminder"] as? [String: Any],
              let reminder = PromptReminder(from: reminderDict) else {
            Logger.error("Invalid promptReminder config")
            return nil
        }
        
        guard let reminderTimeout = Self.parseTimeout(dict["runAfterReminderTimeout"]) else {
            Logger.error("Invalid runAfterReminderTimeout")
            return nil
        }
        self.promptReminder = reminder
        self.runAfterReminderTimeout = reminderTimeout
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
}

struct ChatConfig {
    let autoHideTimeout: Int
    
    init?(from dict: [String: Any]) {
        // 确保字典中有正确的值
        guard let autoHideTimeout = dict["autoHideTimeout"] as? Int else {
            Logger.error("Missing or invalid autoHideTimeout value")
            return nil
        }
        self.autoHideTimeout = autoHideTimeout
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
}

struct PromptReminder {
    let soloMemberTimeout: Int
    let silenceTimeout: Int
    
    init?(from dict: [String: Any]) {
        // 解析 soloMemberTimeout
        guard let soloTimeout = Self.parseTimeout(dict["soloMemberTimeout"]) else {
            Logger.error("Invalid soloMemberTimeout")
            return nil
        }
        
        // 解析 silenceTimeout
        guard let silenceTimeout = Self.parseTimeout(dict["silenceTimeout"]) else {
            Logger.error("Invalid silenceTimeout")
            return nil
        }
        
        self.soloMemberTimeout = soloTimeout
        self.silenceTimeout = silenceTimeout
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
}
