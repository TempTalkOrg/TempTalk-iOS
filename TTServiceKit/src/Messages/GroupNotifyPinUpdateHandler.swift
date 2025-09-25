//
//  GroupNotifyPinUpdateHandler.swift
//  TTServiceKit
//
//  Created by user on 2024/7/22.
//

import Foundation

class GroupNotifyPinUpdateHandler : GroupNotifyHandler {
    
    func handle(envelope: DSKProtoEnvelope,
                groupNotifyEntity: DTGroupNotifyEntity,
                display: Bool,
                oldGroupModel: TSGroupModel,
                newGroupModel: TSGroupModel,
                newGroupThread: TSGroupThread,
                timeStamp: UInt64,
                transaction: SDSAnyWriteTransaction) {
        
        if groupNotifyEntity.groupNotifyDetailedType == .groupAddPin {
            self.updateGroupAddPin(envelope: envelope,
                                   groupNotifyEntity: groupNotifyEntity,
                                   display: display,
                                   oldGroupModel: oldGroupModel,
                                   newGroupModel: newGroupModel,
                                   newGroupThread: newGroupThread,
                                   timeStamp:timeStamp,
                                   transaction: transaction)
            
        } else if groupNotifyEntity.groupNotifyDetailedType == .groupDeletePin {
            
            self.updateGroupDeletePin(envelope: envelope,
                                      groupNotifyEntity: groupNotifyEntity,
                                      display: display,
                                      oldGroupModel: oldGroupModel,
                                      newGroupModel: newGroupModel,
                                      newGroupThread: newGroupThread,
                                      timeStamp:timeStamp,
                                      transaction: transaction)
            
        }
    }
    
    func updateGroupAddPin(envelope: DSKProtoEnvelope,
                           groupNotifyEntity: DTGroupNotifyEntity,
                           display: Bool,
                           oldGroupModel: TSGroupModel,
                           newGroupModel: TSGroupModel,
                           newGroupThread: TSGroupThread,
                           timeStamp: UInt64,
                           transaction: SDSAnyWriteTransaction) {
        
        let groupPins = groupNotifyEntity.groupPins
        guard !groupPins.isEmpty else {
            return
        }
        
        
        // 过滤出 action 为 .add 的 pin 消息
        let filteredPinMessages = groupPins.filter { $0.action == .add }
        
        for obj in filteredPinMessages {
            let newPinned = DTPinnedMessage.parseBase64String(toPinnedMessage: obj, groupId: groupNotifyEntity.gid, transaction: transaction) 
            
            newPinned.pinId = obj.pinId
            newPinned.anyInsert(transaction: transaction)
            
            
            guard let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: groupNotifyEntity.gid) else{
                continue
            }
            let groupThread = TSGroupThread.getOrCreateThread(withGroupId: groupId, transaction: transaction)
            
            DTGroupUtils.sendPinSystemMessage(withSource: obj.creator, serverTimestamp: timeStamp, thread: groupThread, pinnedMessage: newPinned, transaction: transaction)
            newPinned.downloadAllAttachment(with: transaction, success: nil, failure: nil)
        }
        ///主要用于更新版本号等附加信息
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { gthread in
            gthread.groupModel = newGroupModel
        }
    }

    
    func updateGroupDeletePin(envelope: DSKProtoEnvelope,
                              groupNotifyEntity: DTGroupNotifyEntity,
                              display: Bool,
                              oldGroupModel: TSGroupModel,
                              newGroupModel: TSGroupModel,
                              newGroupThread: TSGroupThread,
                              timeStamp: UInt64,
                              transaction: SDSAnyWriteTransaction) {
        
        let groupPins = groupNotifyEntity.groupPins
        guard !groupPins.isEmpty else {
            return
        }
        // 过滤出 action 为 .add 的 pin 消息
        let filteredPinMessages = groupPins.filter { $0.action == .delete }
        for obj in filteredPinMessages {
            // MARK: 移除pin
            if let localPinned = DTPinnedMessage.anyFetch(uniqueId: obj.pinId, transaction: transaction) {
                localPinned.removePinMessage(with: transaction)
            }
        }
        ///主要用于更新版本号等附加信息
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { gthread in
            gthread.groupModel = newGroupModel
        }

    }
    
}
