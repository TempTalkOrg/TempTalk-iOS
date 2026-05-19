//
//  DTMeetingManager+MeetingBar.swift
//  TempTalk
//
//  Created by Ethan on 25/12/2024.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

enum MeetingBarAction: String {
    case add, remove
}

extension DTMeetingManager {
    // 收到join生成bar、所有情况移除bar时可用
    func handleMeetingBar(roomId: String,
                          action: MeetingBarAction,
                          transaction: SDSAnyWriteTransaction? = nil)
    {
        // remove 操作直接清理 DB 和内存，不依赖 allMeetings 存在与否
        if action == .remove {
            Logger.info("\(logTag) handleMeetingBar remove roomId: \(roomId)")

            // 主线程更新内存列表并拿到对应的 call 信息
            let removedCall: DTLiveKitCallModel? = mutateAllMeetings {
                let call = allMeetings.first { $0.roomId == roomId }
                allMeetings = allMeetings.filter { $0.roomId != roomId }
                return call
            }

            if let transaction {
                // 使用统一方法清理所有可能的 bar 类型
                removeAllMeetingBarTypes(roomId: roomId, call: removedCall, transaction: transaction)
                DispatchMainThreadSafe { [weak self] in
                    self?.postHomeAndConversationNoti()
                }
            } else {
                var backgroundTask: OWSBackgroundTask? = OWSBackgroundTask(label: "\(#function)")
                databaseStorage.asyncWrite { [self] wTransaction in
                    // 使用统一方法清理所有可能的 bar 类型
                    removeAllMeetingBarTypes(roomId: roomId, call: removedCall, transaction: wTransaction)
                } completion: { [weak self] in
                    owsAssertDebug(backgroundTask != nil)
                    backgroundTask = nil
                    DispatchMainThreadSafe { [weak self] in
                        self?.postHomeAndConversationNoti()
                    }
                }
            }
            return
        }

        // add 操作保持原逻辑，依赖 allMeetings 查找
        guard let targetCall = allMeetings.first(where: { $0.roomId == roomId }) else {
            Logger.info("\(logTag) handleMeetingBar add failed - room is not exist in allMeetings")
            return
        }

        handleMeetingBar(call: targetCall, action: action, transaction: transaction)
    }

    func handleMeetingBar(call: DTLiveKitCallModel,
                          action: MeetingBarAction,
                          transaction: SDSAnyWriteTransaction? = nil)
    {
        if let roomId = call.roomId {
            Logger.info("\(logTag) roomId handleMeetingBar action: \(action.rawValue)")
            let isContain = allMeetings.map {
                $0.roomId ?? ""
            }.contains(roomId)
            
            switch action {
            case .add:
                guard !isContain else {
                    return
                }
                if let callCopy = call.copy() as? DTLiveKitCallModel {
                    allMeetings.append(callCopy)
                }
            case .remove:
                guard isContain else {
                    return
                }
                allMeetings = allMeetings.filter { meeting in
                    guard let id = meeting.roomId else { return true }
                    return id != roomId
                }
            }
        }

        func dealMeetingBar(transaction: SDSAnyWriteTransaction) {
            let callType = call.callType
            switch callType {
            case .private:
                deal1on1MeetingBar(
                    call: call,
                    action: action,
                    transaction: transaction
                )
            case .group:
                dealGroupMeetingBar(
                    call: call,
                    action: action,
                    transaction: transaction
                )
            case .instant:
                dealInstantMeetingBar(
                    call: call,
                    action: action,
                    transaction: transaction
                )
            }
        }

        if let transaction {
            dealMeetingBar(transaction: transaction)
            // 同步事务：状态已更新，立即发送通知
            DispatchMainThreadSafe { [weak self] in
                self?.postHomeAndConversationNoti()
            }
        } else {
            var backgroundTask: OWSBackgroundTask? = OWSBackgroundTask(label: "\(#function)")

            databaseStorage.asyncWrite { wTransaction in
                dealMeetingBar(transaction: wTransaction)
            } completion: { [weak self] in
                owsAssertDebug(backgroundTask != nil)
                backgroundTask = nil
                // 异步事务完成后：状态已更新，再发送通知
                DispatchMainThreadSafe { [weak self] in
                    self?.postHomeAndConversationNoti()
                }
            }
        }
    }

    func deal1on1MeetingBar(call: DTLiveKitCallModel,
                            action: MeetingBarAction,
                            transaction: SDSAnyWriteTransaction)
    {
        // TODO: call check
        let recipientId = if call.isCaller, let calleeId = call.conversationId {
            calleeId
        } else if let caller = call.caller {
            caller
        } else {
            ""
        }
        
        guard DTParamsUtils.validateString(recipientId).boolValue else {
            return
        }

        let contactThread = TSContactThread.getOrCreateThread(withContactId: recipientId, transaction: transaction)

        switch action {
        case .add:
            if !contactThread.shouldBeVisible {
                contactThread.shouldBeVisible = true
            }
            if contactThread.isRemovedFromConversation {
                contactThread.isRemovedFromConversation = false
            }
            contactThread.stickCallingThread(with: transaction)
        case .remove:
            guard contactThread.isCallingSticked else {
                return
            }
            contactThread.unstickCallingThread(with: transaction)
        }

        Logger.info("\(logTag) 1on1: \(action.rawValue) bar")
    }

    func dealGroupMeetingBar(call: DTLiveKitCallModel,
                             action: MeetingBarAction,
                             transaction: SDSAnyWriteTransaction)
    {
        guard let conversationId = call.conversationId, let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: conversationId) else {
            dealInstantMeetingBar(call: call,
                                  action: action,
                                  transaction: transaction)
            return
        }

        guard let groupThread = TSGroupThread(groupId: groupId, transaction: transaction) else {
            dealInstantMeetingBar(call: call,
                                  action: action,
                                  transaction: transaction)
            return
        }
        switch action {
        case .add:
            if !groupThread.shouldBeVisible {
                groupThread.shouldBeVisible = true
            }
            if groupThread.isRemovedFromConversation {
                groupThread.isRemovedFromConversation = false
            }
            groupThread.stickCallingThread(with: transaction)
        case .remove:
            guard groupThread.isCallingSticked else {
                return
            }
            groupThread.unstickCallingThread(with: transaction)
        }

        Logger.info("\(logTag) group: \(action.rawValue) bar")
    }

    func dealInstantMeetingBar(call: DTLiveKitCallModel,
                               action: MeetingBarAction,
                               transaction: SDSAnyWriteTransaction)
    {
        guard let roomId = call.roomId else {
            return
        }

        switch action {
        case .add:
            if DTVirtualThread.getWithId(roomId, transaction: transaction) != nil {
                return
            }

            let virtualThread = DTVirtualThread(uniqueId: roomId)
            virtualThread.anyInsert(transaction: transaction)

        case .remove:
            guard let virtualThread = DTVirtualThread.getWithId(roomId, transaction: transaction) else {
                return
            }
            virtualThread.anyRemove(transaction: transaction)
        }

        Logger.info("\(logTag) instant: \(action.rawValue) bar")
    }

    @MainActor
    func turnIntoInstantCall() {
        Logger.info("\(logTag) private call turn into instant")

        // 1. 清理 1v1 专属的超时定时器和呼叫提示音，
        //    并补偿可能卡在 connecting 的状态机（caller 先于 callee 入房时会出现）
        stopCallTimeoutTimer()
        stopSound()
        if lifecycleState == .connecting,
           roomContext?.room.connectionState == .connected {
            tryTransition(from: .connecting, to: .connected)
        }

        // 2. 更新 callType，让 UI 立即响应
        currentCall.callType = .instant

        // 3. 手动触发 objectWillChange 确保 SwiftUI 更新
        currentCall.objectWillChange.send()

        // 4. 获取需要的信息
        let roomId = currentCall.roomId
        let recipientId: String
        if currentCall.isCaller, let calleeId = currentCall.conversationId {
            recipientId = calleeId
        } else if let caller = currentCall.caller {
            recipientId = caller
        } else {
            recipientId = ""
        }

        // 5. 使用同步事务处理数据库操作（不操作 allMeetings）
        databaseStorage.write { [self] transaction in
            // 移除 1v1 的 bar
            if DTParamsUtils.validateString(recipientId).boolValue {
                let contactThread = TSContactThread.getOrCreateThread(withContactId: recipientId, transaction: transaction)
                if contactThread.isCallingSticked {
                    contactThread.unstickCallingThread(with: transaction)
                }
            }

            // 添加 instant 的 bar
            dealInstantMeetingBar(call: currentCall, action: .add, transaction: transaction)
        }

        // 6. 事务完成后在主线程更新 allMeetings（代码更清晰）
        if let roomId = roomId {
            allMeetings = allMeetings.filter { $0.roomId != roomId }
        }
        if let callCopy = currentCall.copy() as? DTLiveKitCallModel {
            allMeetings.append(callCopy)
        }

        // 7. 同步完成后立即发送通知
        postHomeAndConversationNoti()
    }

    func removeAllMeetingBars(completion: (() -> Void)? = nil) {
        var backgroundTask: OWSBackgroundTask? = OWSBackgroundTask(label: "\(#function)")
        let finder = AnyThreadFinder()
        var callingThreads: [TSThread] = []
        databaseStorage.asyncWrite { transaction in
            try? finder.fetchStickedCallingThread(transaction: transaction, block: {
                callingThreads.append($0)
            })
            try? finder.enumerateVirtualThreads(transaction: transaction, block: {
                callingThreads.append($0)
            })

            for thread in callingThreads {
                if let virtualThread = thread as? DTVirtualThread {
                    virtualThread.anyRemove(transaction: transaction)
                } else {
                    thread.unstickCallingThread(with: transaction)
                }
            }
        } completion: {
            owsAssertDebug(backgroundTask != nil)
            backgroundTask = nil
            self.allMeetings.removeAll()

            // 使用 RoomIdManager 清理
            RoomIdManager.shared.removeAllRoomIds()

            completion?()
        }
    }

    func postHomeAndConversationNoti() {
        NotificationCenter.default.postNotificationNameAsync(
            DTStickMeetingManager.kMeetingDurationUpdateNotification,
            object: nil
        )

        NotificationCenter.default.postNotificationNameAsync(
            Notification.Name.DTRefreshJoinBarStatusChange,
            object: nil
        )
    }
}

// MARK: - Helpers
extension DTMeetingManager {
    /// 保证 allMeetings 的读写在主线程，防止 Published 跨线程发布
    func mutateAllMeetings<T>(_ block: () -> T) -> T {
        if Thread.isMainThread { return block() }
        var result: T!
        DispatchQueue.main.sync {
            result = block()
        }
        return result
    }

    /// 直接清理与 roomId 关联的所有可能的 bar 类型
    /// - Parameters:
    ///   - roomId: 房间 ID
    ///   - call: 可选的 call 信息，如果提供则精确清理；否则清理所有 sticked threads 作为兜底
    ///   - transaction: 数据库事务
    func removeAllMeetingBarTypes(roomId: String, call: DTLiveKitCallModel?, transaction: SDSAnyWriteTransaction) {
        // 1. 总是清理 instant bar（可以用 roomId 精确匹配）
        if let virtualThread = DTVirtualThread.getWithId(roomId, transaction: transaction) {
            virtualThread.anyRemove(transaction: transaction)
            Logger.info("\(logTag) removeAllMeetingBarTypes: removed instant bar for roomId: \(roomId)")
        }

        // 2. 清理 1v1/group bar
        if let call = call {
            // 有 call 信息，精确清理
            if call.callType == .private {
                let recipientId: String
                if call.isCaller, let calleeId = call.conversationId {
                    recipientId = calleeId
                } else if let caller = call.caller {
                    recipientId = caller
                } else {
                    recipientId = ""
                }

                if DTParamsUtils.validateString(recipientId).boolValue {
                    let contactThread = TSContactThread.getOrCreateThread(withContactId: recipientId, transaction: transaction)
                    if contactThread.isCallingSticked {
                        contactThread.unstickCallingThread(with: transaction)
                        Logger.info("\(logTag) removeAllMeetingBarTypes: removed 1on1 bar for recipientId: \(recipientId)")
                    }
                }
            } else if call.callType == .group,
                      let conversationId = call.conversationId,
                      let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: conversationId),
                      let groupThread = TSGroupThread(groupId: groupId, transaction: transaction) {
                if groupThread.isCallingSticked {
                    groupThread.unstickCallingThread(with: transaction)
                    Logger.info("\(logTag) removeAllMeetingBarTypes: removed group bar for conversationId: \(conversationId)")
                }
            }
        } else {
            Logger.info("\(logTag) removeAllMeetingBarTypes: no call info, clearing all sticked threads as fallback")
            let finder = AnyThreadFinder()
            var threadsToUnstick: [TSThread] = []
            try? finder.fetchStickedCallingThread(transaction: transaction) { thread in
                // 跳过 DTVirtualThread（instant bar 已在上面处理）
                if !(thread is DTVirtualThread) {
                    threadsToUnstick.append(thread)
                }
            }
            for thread in threadsToUnstick {
                thread.unstickCallingThread(with: transaction)
                if thread is TSContactThread {
                    Logger.info("\(logTag) removeAllMeetingBarTypes: unsticked contact thread (fallback)")
                } else if thread is TSGroupThread {
                    Logger.info("\(logTag) removeAllMeetingBarTypes: unsticked group thread (fallback)")
                }
            }
        }
    }
}

extension DTMeetingManager {
    private static var syncServerCallsTask: Task<[DTLiveKitCallModel], Never>?
    private static var syncServerCallsStartTime: TimeInterval?
    private static let syncServerCallsLock = NSLock()

    func syncServerCalls() {
        Logger.info("\(logTag) getActiveCallList invoked")
        Task { await syncServerCallsAsync() }
    }

    func syncServerCallsAsync() async -> [DTLiveKitCallModel] {
        let (runningTask, start) = Self.syncServerCallsLock.withLock {
            (Self.syncServerCallsTask, Self.syncServerCallsStartTime)
        }

        if let runningTask {
            if let start {
                let elapsedMs = (Date().timeIntervalSince1970 - start) * 1000 // seconds → ms
                Logger.info("\(logTag) getActiveCallList already running for \(elapsedMs)ms")
            } else {
                Logger.info("\(logTag) getActiveCallList already running")
            }
            return await runningTask.value
        }

        let startTime = Date().timeIntervalSince1970
        Logger.info("\(logTag) getActiveCallList invoked")

        let task = Task<[DTLiveKitCallModel], Never> { [weak self] in
            defer {
                Self.syncServerCallsLock.withLock {
                    Self.syncServerCallsTask = nil
                    Self.syncServerCallsStartTime = nil
                }
            }
            return await self?.performSyncServerCalls() ?? []
        }

        Self.syncServerCallsLock.withLock {
            Self.syncServerCallsTask = task
            Self.syncServerCallsStartTime = startTime
        }

        return await task.value
    }

    private func performSyncServerCalls() async -> [DTLiveKitCallModel] {
        guard TSAccountManager.isRegistered() else {
            Logger.info("\(logTag) User not registered, skipping performSyncServerCalls")
            return []
        }

        let startTime = Date().timeIntervalSince1970
        Logger.info("\(logTag) getActiveCallList beg")

        let calls = await DTCallAPIManager().getActiveCallList()

        // 先构造新的 MeetingBar 列表
        var newMeetingBars: [DTLiveKitCallModel] = []

        // 合并为单个 read 事务：原有群成员校验 + 群会议 roomName 解析共用一个 tx，
        // 避免每次循环重复开关事务，也规避潜在的嵌套读问题。
        SDSDatabaseStorage.shared.read { tx in
            for call in calls {
                let callModel = DTLiveKitCallModel()
                if let roomId = call["roomId"] as? String {
                    callModel.roomId = roomId
                }

                if let type = call["type"] as? String {
                    callModel.callType = CallType(rawValue: type) ?? .instant
                }

                if let callerInfo = call["caller"] as? [String: Any],
                   let callId = callerInfo["uid"] as? String
                {
                    callModel.caller = callId
                    if case .private = callModel.callType,
                       let localNumber = TSAccountManager.localNumber(),
                       callId != localNumber
                    {
                        callModel.callees = [localNumber]
                    }
                }

                if let conversationId = call["conversation"] as? String {
                    callModel.conversationId = conversationId
                    if callModel.callType == .group,
                       let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: conversationId)
                    {
                        if let groupThread = TSGroupThread.getWithGroupId(groupId, transaction: tx) {
                            if !groupThread.groupModel.groupMemberIds.contains(TSAccountManager.localNumber() ?? "") {
                                callModel.callType = .instant
                            }
                        } else {
                            callModel.callType = .instant
                        }
                    } else if callModel.callType == .private {
                        if self.roomContext?.room.allParticipants.keys.count ?? 0 > 2 {
                            callModel.callType = .instant
                        } else {
                            callModel.callType = .private
                        }
                    }
                } else {
                    callModel.callType = .instant
                }

                // group 类型补齐群名，否则 joinBar 入会后会议标题为空只剩 "(N)"。
                // private/instant 由 DTLiveKitCallModel.roomName getter 自行兜底。
                if callModel.callType == .group, let gid = callModel.conversationId {
                    callModel.roomName = DTGroupCryptoDisplayHelper.shared.resolveGroupDisplayName(
                        serverGroupId: gid,
                        fallbackName: "",
                        transaction: tx
                    )
                }

                newMeetingBars.append(callModel)
            }
        }

        // 拿到最新数据再清空/替换 UI
        await withCheckedContinuation { continuation in
            removeAllMeetingBars {
                if newMeetingBars.isEmpty {
                    NotificationCenter.default.post(name: Notification.Name.DTRefreshJoinBarStatusChange, object: nil)
                } else {
                    for model in newMeetingBars {
                        DTMeetingManager.shared.handleMeetingBar(call: model, action: .add)
                    }
                }
                continuation.resume()
            }
        }

        Logger.info("\(logTag) getActiveCallList end cost: \((Date().timeIntervalSince1970 - startTime) * 1000)ms getActiveCallList count \(newMeetingBars.count)")
        return newMeetingBars
    }
}
