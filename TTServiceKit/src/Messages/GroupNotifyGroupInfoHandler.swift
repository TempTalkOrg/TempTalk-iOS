//
//  GroupNotifyGroupInfoHandler.swift
//  TTServiceKit
//
//  Created by user on 2024/8/12.
//

import Foundation
class GroupNotifyGroupInfoHandler : GroupNotifyHandler {
    
    lazy var groupAvatarUpdateProcessor: DTGroupAvatarUpdateProcessor = {
        let groupAvatarUpdateProcessor = DTGroupAvatarUpdateProcessor(groupThread: nil)
        return groupAvatarUpdateProcessor
    }()
    //    .groupNameChange,
    //    .groupAvatarChange,
    //    .groupMsgExpiryChange
    func handle(envelope: DSKProtoEnvelope,
                groupNotifyEntity: DTGroupNotifyEntity,
                display: Bool,
                oldGroupModel: TSGroupModel,
                newGroupModel: TSGroupModel,
                newGroupThread: TSGroupThread,
                timeStamp: UInt64,
                transaction: SDSAnyWriteTransaction) {
        
        if groupNotifyEntity.groupNotifyDetailedType == .groupNameChange {
            self.updateGroupName(envelope: envelope,
                                 groupNotifyEntity: groupNotifyEntity,
                                 display: display,
                                 oldGroupModel: oldGroupModel,
                                 newGroupModel: newGroupModel,
                                 newGroupThread: newGroupThread,
                                 timeStamp: timeStamp,
                                 transaction: transaction)
            
        } else if groupNotifyEntity.groupNotifyDetailedType == .groupAvatarChange {
            
            self.updateGroupAvatar(envelope: envelope,
                                   groupNotifyEntity: groupNotifyEntity,
                                   display: display,
                                   oldGroupModel: oldGroupModel,
                                   newGroupModel: newGroupModel,
                                   newGroupThread: newGroupThread,
                                   timeStamp: timeStamp,
                                   transaction: transaction)
            
        } else if groupNotifyEntity.groupNotifyDetailedType == .groupMsgExpiryChange {
            
            self.updateGroupMessageExpireTime(envelope: envelope,
                                              groupNotifyEntity: groupNotifyEntity,
                                              display: display,
                                              oldGroupModel: oldGroupModel,
                                              newGroupModel: newGroupModel,
                                              newGroupThread: newGroupThread,
                                              timeStamp: timeStamp,
                                              transaction: transaction)
            
        } else if groupNotifyEntity.groupNotifyDetailedType == .groupRemindChange {
            
            self.updateGroupReminderChange(envelope: envelope,
                                           groupNotifyEntity: groupNotifyEntity,
                                           display: display,
                                           oldGroupModel: oldGroupModel,
                                           newGroupModel: newGroupModel,
                                           newGroupThread: newGroupThread,
                                           timeStamp: timeStamp,
                                           transaction: transaction)
            
        } else if groupNotifyEntity.groupNotifyDetailedType == .groupAnyoneRemoveChange {
            
            self.updateGroupAnyoneRemoveChange(envelope: envelope,
                                               groupNotifyEntity: groupNotifyEntity,
                                               display: display,
                                               oldGroupModel: oldGroupModel,
                                               newGroupModel: newGroupModel,
                                               newGroupThread: newGroupThread,
                                               timeStamp: timeStamp,
                                               transaction: transaction)
            
        } else if groupNotifyEntity.groupNotifyDetailedType == .groupRejoinChange {

            self.updateGroupRejoinChange(envelope: envelope,
                                         groupNotifyEntity: groupNotifyEntity,
                                         display: display,
                                         oldGroupModel: oldGroupModel,
                                         newGroupModel: newGroupModel,
                                         newGroupThread: newGroupThread,
                                         timeStamp: timeStamp,
                                         transaction: transaction)
            
        } else if groupNotifyEntity.groupNotifyDetailedType == .privateChatChange {
            
            self.updatePrivateChatChange(envelope: envelope,
                                         groupNotifyEntity: groupNotifyEntity,
                                         display: display,
                                         oldGroupModel: oldGroupModel,
                                         newGroupModel: newGroupModel,
                                         newGroupThread: newGroupThread,
                                         timeStamp: timeStamp,
                                         transaction: transaction)
            
        } else if groupNotifyEntity.groupNotifyDetailedType == .groupPublishRuleChange {
            
            self.updateGroupPublishRuleChange(envelope: envelope,
                                              groupNotifyEntity: groupNotifyEntity,
                                              display: display,
                                              oldGroupModel: oldGroupModel,
                                              newGroupModel: newGroupModel,
                                              newGroupThread: newGroupThread,
                                              timeStamp: timeStamp,
                                              transaction: transaction)
            
        } else if groupNotifyEntity.groupNotifyDetailedType == .groupExtChange {
            //TODO: 需要check
            self.updateGroupExtChange(envelope: envelope,
                                      groupNotifyEntity: groupNotifyEntity,
                                      display: display,
                                      oldGroupModel: oldGroupModel,
                                      newGroupModel: newGroupModel,
                                      newGroupThread: newGroupThread,
                                      timeStamp: timeStamp,
                                      transaction: transaction)
            
        } else if groupNotifyEntity.groupNotifyDetailedType == .groupAnyoneChangeNameChange {
            
            self.updateGroupAnyoneChangeNameChangee(envelope: envelope,
                                                    groupNotifyEntity: groupNotifyEntity,
                                                    display: display,
                                                    oldGroupModel: oldGroupModel,
                                                    newGroupModel: newGroupModel,
                                                    newGroupThread: newGroupThread,
                                                    timeStamp: timeStamp,
                                                    transaction: transaction)
            
        } else if groupNotifyEntity.groupNotifyDetailedType == .anyoneChangeAutoClearChange {
            
            self.updateGroupAnyoneChangeAutoClearChange(envelope: envelope,
                                                        groupNotifyEntity: groupNotifyEntity,
                                                        display: display,
                                                        oldGroupModel: oldGroupModel,
                                                        newGroupModel: newGroupModel,
                                                        newGroupThread: newGroupThread,
                                                        timeStamp: timeStamp,
                                                        transaction: transaction)
            
        } else if groupNotifyEntity.groupNotifyDetailedType == .autoClearChange {
            
            self.updateGroupAutoClearChange(envelope: envelope,
                                            groupNotifyEntity: groupNotifyEntity,
                                            display: display,
                                            oldGroupModel: oldGroupModel,
                                            newGroupModel: newGroupModel,
                                            newGroupThread: newGroupThread,
                                            timeStamp: timeStamp,
                                            transaction: transaction)
            
        } else if groupNotifyEntity.groupNotifyDetailedType == .privilegeConfidential {
            
            self.updateGroupPrivilegeConfidential(envelope: envelope,
                                                  groupNotifyEntity: groupNotifyEntity,
                                                  display: display,
                                                  oldGroupModel: oldGroupModel,
                                                  newGroupModel: newGroupModel,
                                                  newGroupThread: newGroupThread,
                                                  timeStamp: timeStamp,
                                                  transaction: transaction)
            
        } else if groupNotifyEntity.groupNotifyDetailedType == .groupRapidRoleChange {///右键头像 编辑角色
            
            self.updateGroupRapidRoleChange(envelope: envelope,
                                                  groupNotifyEntity: groupNotifyEntity,
                                                  display: display,
                                                  oldGroupModel: oldGroupModel,
                                                  newGroupModel: newGroupModel,
                                                  newGroupThread: newGroupThread,
                                                  timeStamp: timeStamp,
                                                  transaction: transaction)
        } else {
            
            Logger.info("unsupported type")
            
        }
        
    }
    
    func updateGroupRapidRoleChange(envelope: DSKProtoEnvelope,
                                          groupNotifyEntity: DTGroupNotifyEntity,
                                          display: Bool,
                                          oldGroupModel: TSGroupModel,
                                          newGroupModel: TSGroupModel,
                                          newGroupThread: TSGroupThread,
                                          timeStamp: UInt64,
                                          transaction: SDSAnyWriteTransaction) {
        var rapidChangedIds = [String]()
        let members = groupNotifyEntity.members
       
        guard !members.isEmpty else {
            return
        }

        members.forEach { obj in
            let uid = obj.uid
            if uid.isEmpty { return } 
            rapidChangedIds.append(uid)

            newGroupModel.add(obj.rapidRole, memberId: uid)
            DTGroupUtils.sendRAPIDRoleChangedMessage(withOperatorId: groupNotifyEntity.source,
                                                     otherMemberId: uid,
                                                     rapidRole: obj.rapidDescription,
                                                     serverTimestamp: 0,
                                                     thread: newGroupThread,
                                                     transaction: transaction)
        }

        let targetRapidChangedIds = rapidChangedIds
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { gthread in
            gthread.groupModel = newGroupModel
        }

        transaction.addAsyncCompletionOnMain {
            DTGroupUtils.postRapidRoleChangeNotification(with: newGroupModel,
                                                         targedMemberIds: targetRapidChangedIds)
        }
        
    }
    
    func updateGroupPrivilegeConfidential(envelope: DSKProtoEnvelope,
                                          groupNotifyEntity: DTGroupNotifyEntity,
                                          display: Bool,
                                          oldGroupModel: TSGroupModel,
                                          newGroupModel: TSGroupModel,
                                          newGroupThread: TSGroupThread,
                                          timeStamp: UInt64,
                                          transaction: SDSAnyWriteTransaction) {
        
        guard let privilegeConfidential = groupNotifyEntity.group?.privilegeConfidential else {
            Logger.info("group.privilegeConfidential is nil")
            return
        }
        
        newGroupModel.privilegeConfidential = privilegeConfidential
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { instance in
            instance.groupModel = newGroupModel
        }
        
        if privilegeConfidential {
            var operatorName = ""
            if !groupNotifyEntity.source.isEmpty {
                operatorName = TextSecureKitEnv.shared().contactsManager.displayName(forPhoneIdentifier: groupNotifyEntity.source, transaction: transaction)
            }
            let infoMessage = DTGroupUpdateInfoMessageHelper.gPrivilegeConfidentialInfoMessage(with: newGroupThread, operatorName: operatorName)
            infoMessage.anyInsert(transaction: transaction)
            
        }
        
    }
    
    func updateGroupAutoClearChange(envelope: DSKProtoEnvelope,
                                    groupNotifyEntity: DTGroupNotifyEntity,
                                    display: Bool,
                                    oldGroupModel: TSGroupModel,
                                    newGroupModel: TSGroupModel,
                                    newGroupThread: TSGroupThread,
                                    timeStamp: UInt64,
                                    transaction: SDSAnyWriteTransaction) {
        
        guard let autoClear = groupNotifyEntity.group?.autoClear else {
            Logger.info("group.autoClear is nil")
            return
        }
        
        newGroupModel.autoClear = autoClear
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { instance in
            instance.groupModel = newGroupModel
        }
        
        let infoMessage = DTGroupUpdateInfoMessageHelper.gOpenAutoClearSwitchInfoMessage(with: newGroupThread, isOn: autoClear)
        infoMessage.anyInsert(transaction: transaction)
        
    }
    
    func updateGroupAnyoneChangeAutoClearChange(envelope: DSKProtoEnvelope,
                                                groupNotifyEntity: DTGroupNotifyEntity,
                                                display: Bool,
                                                oldGroupModel: TSGroupModel,
                                                newGroupModel: TSGroupModel,
                                                newGroupThread: TSGroupThread,
                                                timeStamp: UInt64,
                                                transaction: SDSAnyWriteTransaction) {
        
        guard let anyoneChangeAutoClear = groupNotifyEntity.group?.anyoneChangeAutoClear else {
            Logger.info("group.anyoneChangeAutoClear is nil")
            return
        }
        
        newGroupModel.anyoneChangeAutoClear = anyoneChangeAutoClear
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { instance in
            instance.groupModel = newGroupModel
        }
        
    }
    
    func updateGroupAnyoneChangeNameChangee(envelope: DSKProtoEnvelope,
                                            groupNotifyEntity: DTGroupNotifyEntity,
                                            display: Bool,
                                            oldGroupModel: TSGroupModel,
                                            newGroupModel: TSGroupModel,
                                            newGroupThread: TSGroupThread,
                                            timeStamp: UInt64,
                                            transaction: SDSAnyWriteTransaction) {
        
        guard let anyoneChangeName = groupNotifyEntity.group?.anyoneChangeName else {
            Logger.info("group.anyoneChangeName is nil")
            return
        }
        
        newGroupModel.anyoneChangeName = anyoneChangeName
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { instance in
            instance.groupModel = newGroupModel
        }
        
    }
    
    
    func updateGroupExtChange(envelope: DSKProtoEnvelope,
                              groupNotifyEntity: DTGroupNotifyEntity,
                              display: Bool,
                              oldGroupModel: TSGroupModel,
                              newGroupModel: TSGroupModel,
                              newGroupThread: TSGroupThread,
                              timeStamp: UInt64,
                              transaction: SDSAnyWriteTransaction) {
        
        guard let ext = groupNotifyEntity.group?.ext else {
            Logger.info("group.ext is nil")
            return
        }
        
        newGroupModel.isExt = ext
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { instance in
            instance.groupModel = newGroupModel
        }
        
        DTGroupUtils.postExternalChangeNotification(withTargetIds: [newGroupThread.uniqueId: NSNumber(value: ext)])
    }
    
    
    func updateGroupPublishRuleChange(envelope: DSKProtoEnvelope,
                                      groupNotifyEntity: DTGroupNotifyEntity,
                                      display: Bool,
                                      oldGroupModel: TSGroupModel,
                                      newGroupModel: TSGroupModel,
                                      newGroupThread: TSGroupThread,
                                      timeStamp: UInt64,
                                      transaction: SDSAnyWriteTransaction) {
        
        guard let publishRule = groupNotifyEntity.group?.publishRule else {
            Logger.info("group.publishRule = nil")
            return
        }
        
        newGroupModel.publishRule = publishRule
        Logger.info("update group publishRule = \(publishRule).")
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { gthread in
            gthread.groupModel = newGroupModel
        }
        
        let publishRuleChangeSystemMessage = DTGroupUpdateInfoMessageHelper.groupUpdatePublishRuleInfoMessage(publishRule, timestamp: timeStamp, serverTimestamp: envelope.systemShowTimestamp, in: newGroupThread)
        publishRuleChangeSystemMessage.anyInsert(transaction: transaction)
        
    }
    
    func updatePrivateChatChange(envelope: DSKProtoEnvelope,
                                 groupNotifyEntity: DTGroupNotifyEntity,
                                 display: Bool,
                                 oldGroupModel: TSGroupModel,
                                 newGroupModel: TSGroupModel,
                                 newGroupThread: TSGroupThread,
                                 timeStamp: UInt64,
                                 transaction: SDSAnyWriteTransaction) {
        guard let privateChat = groupNotifyEntity.group?.privateChat else {
            return
        }
        newGroupModel.privateChat = privateChat
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { instance in
            instance.groupModel = newGroupModel
        }
        
        var sourceName = ""
        let localNumber = TSAccountManager.sharedInstance().localNumber(with: transaction)
        if groupNotifyEntity.source == localNumber {
            sourceName = NSLocalizedString("YOU", comment: "")
        } else {
            sourceName = TextSecureKitEnv.shared().contactsManager.displayName(forPhoneIdentifier: groupNotifyEntity.source, transaction: transaction)
        }
        
        let timestamp = Date.ows_millisecondTimestamp()
        let customMessage: String
        if privateChat  {
            customMessage = String(format: NSLocalizedString("GROUP_UPDATE_OPEN_EXT_PRIVATE_CHAT_INFO_MESSAGE", comment: ""), sourceName)
        } else {
            customMessage = String(format: NSLocalizedString("GROUP_UPDATE_CLOSE_EXT_PRIVATE_CHAT_INFO_MESSAGE", comment: ""), sourceName)
        }
        
        let systemMsg = TSInfoMessage(timestamp: timestamp,
                                      in: newGroupThread,
                                      messageType: .typeGroupUpdate,
                                      customMessage: customMessage)
        systemMsg.isShouldAffectThreadSorting = true
        systemMsg.anyInsert(transaction: transaction)
        
        return
        
        
    }
    
    func updateGroupRejoinChange(envelope: DSKProtoEnvelope,
                                 groupNotifyEntity: DTGroupNotifyEntity,
                                 display: Bool,
                                 oldGroupModel: TSGroupModel,
                                 newGroupModel: TSGroupModel,
                                 newGroupThread: TSGroupThread,
                                 timeStamp: UInt64,
                                 transaction: SDSAnyWriteTransaction) {
        
        guard let rejoin = groupNotifyEntity.group?.rejoin else {
            Logger.info("group.rejoin = nil")
            return
        }
        
        newGroupModel.rejoin = rejoin
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { instance in
            instance.groupModel = newGroupModel;
        }
        
    }
    
    func updateGroupAnyoneRemoveChange(envelope: DSKProtoEnvelope,
                                       groupNotifyEntity: DTGroupNotifyEntity,
                                       display: Bool,
                                       oldGroupModel: TSGroupModel,
                                       newGroupModel: TSGroupModel,
                                       newGroupThread: TSGroupThread,
                                       timeStamp: UInt64,
                                       transaction: SDSAnyWriteTransaction) {
        guard let anyoneRemove = groupNotifyEntity.group?.anyoneRemove else {
            Logger.info("anyoneRemove = nil")
            return
        }
        
        newGroupModel.anyoneRemove = anyoneRemove
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { instance in
            instance.groupModel = newGroupModel;
        }
        
    }
    
    
    func updateGroupReminderChange(envelope: DSKProtoEnvelope,
                                   groupNotifyEntity: DTGroupNotifyEntity,
                                   display: Bool,
                                   oldGroupModel: TSGroupModel,
                                   newGroupModel: TSGroupModel,
                                   newGroupThread: TSGroupThread,
                                   timeStamp: UInt64,
                                   transaction: SDSAnyWriteTransaction) {
        
        let oldRemindCycle = !oldGroupModel.remindCycle.isEmpty ? oldGroupModel.remindCycle : "none"
        let newRemindCycle = groupNotifyEntity.group?.remindCycle
        Logger.info("[group remind] changed, \(oldRemindCycle) | \(String(describing: newRemindCycle))")
        
        guard let newRemindCycle else {
            Logger.info("[group remind] changed, newRemindCycle = nil")
            return
        }
        newGroupModel.remindCycle = newRemindCycle
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { instance in
            instance.groupModel = newGroupModel
        }
        DTGroupUtils.sendGroupReminderMessage(
            withSource: groupNotifyEntity.source,
            serverTimestamp: envelope.systemShowTimestamp,
            isChanged: true,
            thread: newGroupThread,
            remindCycle: newRemindCycle,
            transaction: transaction
        )
        
    }
    
    
    func updateGroupMessageExpireTime(envelope: DSKProtoEnvelope,
                                      groupNotifyEntity: DTGroupNotifyEntity,
                                      display: Bool,
                                      oldGroupModel: TSGroupModel,
                                      newGroupModel: TSGroupModel,
                                      newGroupThread: TSGroupThread,
                                      timeStamp: UInt64,
                                      transaction: SDSAnyWriteTransaction) {
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { gthread in
            gthread.groupModel = newGroupModel
            // 更新群消息 - notify expire change
            DataUpdateUtil.shared.updateConversation(thread: gthread,
                                                     expireTime: groupNotifyEntity.group?.messageExpiry,
                                                     messageClearAnchor: NSNumber(value: groupNotifyEntity.group?.messageClearAnchor ?? 0))
        }
        if DTParamsUtils.validateNumber(newGroupModel.messageExpiry).boolValue,
           DTGroupUtils.isChangedArchiveMessageString(withOldGroupModel: oldGroupModel, newModel: newGroupModel) {
            
            transaction.addAsyncCompletionOnMain {
                NotificationCenter.default.post(name: NSNotification.Name.DTGroupMessageExpiryConfigChanged, object: nil)
            }
        }
    }
    
    func updateGroupAvatar(envelope: DSKProtoEnvelope,
                           groupNotifyEntity: DTGroupNotifyEntity,
                           display: Bool,
                           oldGroupModel: TSGroupModel,
                           newGroupModel: TSGroupModel,
                           newGroupThread: TSGroupThread,
                           timeStamp: UInt64,
                           transaction: SDSAnyWriteTransaction) {
        let gid = groupNotifyEntity.gid
        guard !gid.isEmpty,
              let avatar = groupNotifyEntity.group?.avatar, !avatar.isEmpty,
              let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: gid), !groupId.isEmpty else {
            return
        }
        
        self.groupAvatarUpdateProcessor.groupThread = newGroupThread
        self.groupAvatarUpdateProcessor.handleReceivedGroupAvatarUpdate(withAvatarUpdate: avatar) { attachmentStream in
            let serialQueue = DTGroupUpdateMessageProcessor.self.serialQueue()
            serialQueue.async {
                guard let image = attachmentStream.image() else {
                    Logger.error("update avatar data empty")
                    return
                }
                
                // Perform database write transaction
                NSObject.databaseStorage.asyncWrite { writeTransaction in
                    let groupThread = TSGroupThread.getOrCreateThread(withGroupId: groupId, transaction: writeTransaction)
                    
                    // Ensure the new version is not older than the existing one
                    guard newGroupModel.version >= groupThread.groupModel.version else { return }
                    
                    groupThread.anyUpdateGroupThread(transaction: writeTransaction) { g_thread in
                        g_thread.groupModel.groupImage = image
                        g_thread.groupModel.version = newGroupModel.version
                    }
                    
                    groupThread.fireAvatarChangedNotification()
                    
                    let updatedGroupInfoString = Localized("GROUP_AVATAR_CHANGED")
                    
                    // Only generate system message if display is true
                    guard display else { return }
                    
                    let infoMessage = TSInfoMessage(
                        timestamp: timeStamp,
                        in: newGroupThread,
                        messageType: .typeGroupUpdate,
                        customMessage: updatedGroupInfoString
                    )
                    
                    infoMessage.isShouldAffectThreadSorting = false
                    infoMessage.anyInsert(transaction: writeTransaction)
                }
            }
        } failure: { error in
            Logger.info("update avatar data error \(error.localizedDescription)")
        }
    }

    
    func updateGroupName(envelope: DSKProtoEnvelope,
                         groupNotifyEntity: DTGroupNotifyEntity,
                         display: Bool,
                         oldGroupModel: TSGroupModel,
                         newGroupModel: TSGroupModel,
                         newGroupThread: TSGroupThread,
                         timeStamp: UInt64,
                         transaction: SDSAnyWriteTransaction) {
        
        let gid = groupNotifyEntity.gid
        guard !gid.isEmpty,
              let name = groupNotifyEntity.group?.name, !name.isEmpty,
              let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: gid), !groupId.isEmpty else {
            return
        }
        
        // 更新 groupName 和 groupThread
        newGroupModel.groupName = name
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { gthread in
            gthread.groupModel = newGroupModel
        }
        
        // 如果旧的 groupName 和新的不一样，则构造变更信息
        guard oldGroupModel.groupName != name else {
            Logger.error("oldGroupModel.groupName == newGroupModel.groupName")
            return
        }
        
        var updatedGroupInfoString = ""
        let source = groupNotifyEntity.source
        if !source.isEmpty {
            let displayName = TextSecureKitEnv.shared().contactsManager.displayName(forPhoneIdentifier: source)
            if !displayName.isEmpty {
                updatedGroupInfoString = String(format: Localized("GROUP_NAME_CHANGED_SYSTEM_MSG"), displayName, name)
            } else {
                updatedGroupInfoString = String(format: Localized("GROUP_TITLE_CHANGED"), name)
            }
        } else {
            updatedGroupInfoString = String(format: Localized("GROUP_TITLE_CHANGED"), name)
        }
        
        // 创建 infoMessage 并插入到数据库
        let infoMessage = TSInfoMessage(timestamp: timeStamp,
                                        in: newGroupThread,
                                        messageType: .typeGroupUpdate,
                                        customMessage: updatedGroupInfoString)
        
        infoMessage.isShouldAffectThreadSorting = false
        infoMessage.anyInsert(transaction: transaction)
    }

}
