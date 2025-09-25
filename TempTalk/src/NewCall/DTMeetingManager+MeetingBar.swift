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
                          transaction: SDSAnyWriteTransaction? = nil) {
        
        guard let targetCall = allMeetings.filter ({
            $0.roomId == roomId
        }).first else {
            Logger.info("room is not exist")
            return
        }
        
        handleMeetingBar(call: targetCall, action: action, transaction: transaction)
    }
    
    func handleMeetingBar(call: DTLiveKitCallModel,
                          action: MeetingBarAction,
                          transaction: SDSAnyWriteTransaction? = nil) {

        if let roomId = call.roomId {
            Logger.info("\(logTag) roomId handleMeetingBar")
            let isContain = allMeetings.map({
                $0.roomId ?? ""
            }).contains(roomId)
            
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
        } else {
            var backgroundTask: OWSBackgroundTask?  = OWSBackgroundTask(label: "\(#function)")
            
            databaseStorage.asyncWrite { wTransaction in
                dealMeetingBar(transaction: wTransaction)
            } completion: {
                owsAssertDebug(backgroundTask != nil)
                backgroundTask = nil
            }
        }
    }
    
    func deal1on1MeetingBar(call: DTLiveKitCallModel,
                            action: MeetingBarAction,
                            transaction: SDSAnyWriteTransaction) {
        // TODO: call check
        let recipientId = {
            if call.isCaller, let calleeId = call.conversationId {
                return calleeId
            } else if let caller = call.caller {
                return caller
            } else {
                return ""
            }
        }()
                
        let contactThread = TSContactThread.getOrCreateThread(withContactId: recipientId, transaction: transaction)
        
        switch action {
        case .add:
            if !contactThread.shouldBeVisible {
                contactThread.shouldBeVisible = true
            }
            if contactThread.isRemovedFromConversation {
                contactThread.isRemovedFromConversation = false
            }
//            guard !contactThread.isCallingSticked else {
//                return
//            }
            contactThread.stickCallingThread(with: transaction)
        case .remove:
            guard contactThread.isCallingSticked else {
                return
            }
            contactThread.unstickCallingThread(with: transaction)
        }
        
        postHomeAndConversationNoti()
        Logger.info("\(logTag) 1on1: \(action.rawValue) bar")
    }
    
    func dealGroupMeetingBar(call: DTLiveKitCallModel,
                             action: MeetingBarAction,
                             transaction: SDSAnyWriteTransaction) {
        
        guard let conversationId = call.conversationId, let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: conversationId) else {
            dealInstantMeetingBar(call: call,
                                  action: action,
                                  transaction: transaction
            )
            return
        }
                
        guard let groupThread = TSGroupThread(groupId: groupId, transaction: transaction) else {
            dealInstantMeetingBar(call: call,
                                  action: action,
                                  transaction: transaction
            )
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
//            guard !groupThread.isCallingSticked else {
//                return
//            }
            groupThread.stickCallingThread(with: transaction)
        case .remove:
            guard groupThread.isCallingSticked else {
                return
            }
            groupThread.unstickCallingThread(with: transaction)
        }
        
        postHomeAndConversationNoti()
        Logger.info("\(logTag) group: \(action.rawValue) bar")
    }
    
    func dealInstantMeetingBar(call: DTLiveKitCallModel,
                               action: MeetingBarAction,
                               transaction: SDSAnyWriteTransaction) {
        
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
     
        postHomeAndConversationNoti()
        Logger.info("\(logTag) instant: \(action.rawValue) bar")
    }
    
    func turnIntoInstantCall() {
        
        Logger.info("\(logTag) private call turn into instant")
        handleMeetingBar(call: currentCall, action: .remove)
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            DispatchMainThreadSafe { [self] in
                self.currentCall.callType = .instant
                handleMeetingBar(call: currentCall, action: .add)
            }
        }
    }
    
    func removeAllMeetingBars(completion: (() -> Void)? = nil) {
        var backgroundTask: OWSBackgroundTask?  = OWSBackgroundTask(label: "\(#function)")
        let finder = AnyThreadFinder()
        var callingThreads: [TSThread] = []
        databaseStorage.asyncWrite { transaction in
            try? finder.fetchStickedCallingThread(transaction: transaction, block: {
                callingThreads.append($0)
            })
            try? finder.enumerateVirtualThreads(transaction: transaction, block: {
                callingThreads.append($0)
            })

            callingThreads.forEach { thread in
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

extension DTMeetingManager {
    
    func syncServerCalls() {
        Logger.info("\(logTag) getActiveCallList")
        
        Task {
            let calls = await DTCallAPIManager().getActiveCallList()

            // 先构造新的 MeetingBar 列表
            var newMeetingBars: [DTLiveKitCallModel] = []

            for call in calls {
                let callModel = DTLiveKitCallModel()
                if let roomId = call["roomId"] as? String {
                    callModel.roomId = roomId
                }
                
                if let type = call["type"] as? String {
                    callModel.callType = CallType(rawValue: type) ?? .instant
                }
                
                if let callerInfo = call["caller"] as? [String: Any],
                   let callId = callerInfo["uid"] as? String {
                    callModel.caller = callId
                    if case .private = callModel.callType,
                       let localNumber = TSAccountManager.localNumber(),
                       callId != localNumber {
                        callModel.callees = [localNumber]
                    }
                }
                
                if let conversationId = call["conversation"] as? String {
                    callModel.conversationId = conversationId
                    if callModel.callType == .group,
                       let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: conversationId) {
                        if let groupThread = TSGroupThread.getWithGroupId(groupId) {
                            if !groupThread.groupModel.groupMemberIds.contains(TSAccountManager.localNumber() ?? "") {
                                callModel.callType = .instant
                            }
                        } else {
                            callModel.callType = .instant
                        }
                    } else if callModel.callType == .private {
                        if roomContext?.room.allParticipants.keys.count ?? 0 > 2 {
                            callModel.callType = .instant
                        } else {
                            callModel.callType = .private
                        }
                    }
                } else {
                    callModel.callType = .instant
                }
                
                newMeetingBars.append(callModel)
            }
            
            // 拿到最新数据再清空/替换 UI
            removeAllMeetingBars {
                if newMeetingBars.isEmpty {
                    NotificationCenter.default.post(name: Notification.Name.DTRefreshJoinBarStatusChange, object: nil)
                } else {
                    for model in newMeetingBars {
                        DTMeetingManager.shared.handleMeetingBar(call: model, action: .add)
                    }
                }
            }
        }
    }

}
