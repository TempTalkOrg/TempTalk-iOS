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
        } else if groupNotifyEntity.groupNotifyDetailedType == .criticalAlertChange {
            
            self.updateCriticalAlertChange(envelope: envelope,
                                              groupNotifyEntity: groupNotifyEntity,
                                              display: display,
                                              oldGroupModel: oldGroupModel,
                                              newGroupModel: newGroupModel,
                                              newGroupThread: newGroupThread,
                                              timeStamp: timeStamp,
                                              transaction: transaction)

        } else if groupNotifyEntity.groupNotifyDetailedType == .upgradeGroupCrypto {

            handleUpgradeGroupCrypto(envelope: envelope,
                                     groupNotifyEntity: groupNotifyEntity,
                                     display: display,
                                     oldGroupModel: oldGroupModel,
                                     newGroupModel: newGroupModel,
                                     newGroupThread: newGroupThread,
                                     timeStamp: timeStamp,
                                     transaction: transaction)

        } else if groupNotifyEntity.groupNotifyDetailedType == .rotateGroupCrypto {

            handleRotateGroupCrypto(envelope: envelope,
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
    
    func updateCriticalAlertChange(envelope: DSKProtoEnvelope,
                                      groupNotifyEntity: DTGroupNotifyEntity,
                                      display: Bool,
                                      oldGroupModel: TSGroupModel,
                                      newGroupModel: TSGroupModel,
                                      newGroupThread: TSGroupThread,
                                      timeStamp: UInt64,
                                      transaction: SDSAnyWriteTransaction) {
        
        guard let criticalAlert = groupNotifyEntity.group?.criticalAlert else {
            Logger.info("group.criticalAlert = nil")
            return
        }
        
        newGroupModel.criticalAlert = criticalAlert
        Logger.info("update group criticalAlert = \(criticalAlert).")
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { gthread in
            gthread.groupModel = newGroupModel
        }
        
        transaction.addAsyncCompletionOnMain {            
            DTGroupUtils.postCriticalAlertChangeNotification(withTargetIds: [newGroupThread.uniqueId: NSNumber(value: criticalAlert)])
        }
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
                                                     messageClearAnchor: NSNumber(value: groupNotifyEntity.group?.messageClearAnchor ?? 0),
                                                     transaction: transaction)
        }

        // 只要归档时间发生变化，就触发归档检查
        if DTGroupUtils.isChangedArchiveMessageString(withOldGroupModel: oldGroupModel, newModel: newGroupModel) {
            transaction.addAsyncCompletionOnMain {
                NotificationCenter.default.post(name: NSNotification.Name.DTGroupMessageExpiryConfigChanged, object: nil)
                // 事务提交后触发归档检查
                OWSArchivedMessageJob.shared().triggerArchiveCheckImmediately()
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
              let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: gid), !groupId.isEmpty else {
            return
        }

        let group = groupNotifyEntity.group
        let cryptoMode = group?.groupCryptoMode ?? 0
        let isEncrypted = DTGroupCryptoDisplayHelper.shared.isEncryptedGroup(cryptoMode)

        DTGroupBaseInfoEntity.syncFields(gid: gid,
                                         plainAvatar: group?.avatar,
                                         encryptedAvatar: group?.encryptedAvatar,
                                         transaction: transaction)

        // 加密群：和头像捆绑刷新群名
        if isEncrypted {
            DTGroupKeyMessageHandler.refreshEncryptedGroupNameIfNeeded(gid: gid, transaction: transaction)
        }

        guard let avatar = DTGroupCryptoDisplayHelper.shared.prepareAvatarUpdate(
            plainAvatar: group?.avatar,
            encryptedAvatar: group?.encryptedAvatar,
            groupCryptoMode: cryptoMode,
            gid: gid,
            transaction: transaction
        ) else {
            return
        }

        let isPlainFallback = isEncrypted && !DTGroupCryptoDisplayHelper.shared.hasGroupKey(gid: gid, transaction: transaction)
        let capturedEncryptedAvatar = group?.encryptedAvatar ?? ""

        Logger.info("[GroupAvatar] GroupInfo avatar download starting, gid: \(gid), version: \(newGroupModel.version), plainFallback: \(isPlainFallback)")
        self.groupAvatarUpdateProcessor.groupThread = newGroupThread
        self.groupAvatarUpdateProcessor.handleReceivedGroupAvatarUpdate(withAvatarUpdate: avatar) { attachmentStream in
            let serialQueue = DTGroupUpdateMessageProcessor.self.serialQueue()
            serialQueue.async {
                guard let image = attachmentStream.image() else {
                    Logger.error("[GroupAvatar] GroupInfo: attachmentStream.image() nil, gid: \(gid)")
                    return
                }

                // Perform database write transaction
                NSObject.databaseStorage.asyncWrite { writeTransaction in
                    let groupThread = TSGroupThread.getOrCreateThread(withGroupId: groupId, transaction: writeTransaction)

                    // Ensure the new version is not older than the existing one
                    guard newGroupModel.version >= groupThread.groupModel.version else {
                        Logger.info("[GroupAvatar] GroupInfo skip: older version \(newGroupModel.version) < local \(groupThread.groupModel.version), gid: \(gid)")
                        return
                    }

                    groupThread.anyUpdateGroupThread(transaction: writeTransaction) { g_thread in
                        g_thread.groupModel.groupImage = image
                        g_thread.groupModel.version = newGroupModel.version
                    }

                    groupThread.fireAvatarChangedNotification()
                    Logger.info("[GroupAvatar] GroupInfo avatar download success, gid: \(gid), version: \(newGroupModel.version)")
                    if !isPlainFallback {
                        DTGroupCryptoDisplayHelper.shared.markAvatarDownloaded(gid: gid, encryptedAvatar: capturedEncryptedAvatar)
                    }
                    
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
            Logger.error("[GroupAvatar] GroupInfo avatar download failed, gid: \(gid), error: \(error)")
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
              let rawName = groupNotifyEntity.group?.name, !rawName.isEmpty,
              let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: gid), !groupId.isEmpty else {
            return
        }
        
        let group = groupNotifyEntity.group
        let resolvedName = DTGroupCryptoManager.shared.resolveGroupName(
            gid: gid,
            cryptoMode: group?.groupCryptoMode ?? 0,
            encryptedName: group?.encryptedName,
            oldName: oldGroupModel.groupName,
            serverName: rawName,
            transaction: transaction)

        DTGroupBaseInfoEntity.syncFields(gid: gid,
                                         name: resolvedName,
                                         encryptedName: group?.encryptedName,
                                         transaction: transaction)

        // 更新 groupName 和 groupThread
        newGroupModel.groupName = resolvedName
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { gthread in
            gthread.groupModel = newGroupModel
        }

        // 加密群：和群名捆绑刷新头像
        if let group, group.groupCryptoMode > 0 {
            DTGroupKeyMessageHandler.downloadEncryptedAvatarIfNeeded(gid: gid, transaction: transaction)
        }

        // 如果旧的 groupName 和新的不一样，则构造变更信息
        guard oldGroupModel.groupName != resolvedName else {
            Logger.error("oldGroupModel.groupName == newGroupModel.groupName")
            return
        }
        
        var updatedGroupInfoString = ""
        let source = groupNotifyEntity.source
        if !source.isEmpty {
            let displayName = TextSecureKitEnv.shared().contactsManager.displayName(forPhoneIdentifier: source, transaction: transaction)
            if !displayName.isEmpty {
                updatedGroupInfoString = String(format: Localized("GROUP_NAME_CHANGED_SYSTEM_MSG"), displayName, resolvedName)
            } else {
                updatedGroupInfoString = String(format: Localized("GROUP_TITLE_CHANGED"), resolvedName)
            }
        } else {
            updatedGroupInfoString = String(format: Localized("GROUP_TITLE_CHANGED"), resolvedName)
        }
        
        // 创建 infoMessage 并插入到数据库
        let infoMessage = TSInfoMessage(timestamp: timeStamp,
                                        in: newGroupThread,
                                        messageType: .typeGroupUpdate,
                                        customMessage: updatedGroupInfoString)
        
        infoMessage.isShouldAffectThreadSorting = false
        infoMessage.anyInsert(transaction: transaction)
    }

    // MARK: - Upgrade Group Crypto

    private func handleUpgradeGroupCrypto(envelope: DSKProtoEnvelope,
                                          groupNotifyEntity: DTGroupNotifyEntity,
                                          display: Bool,
                                          oldGroupModel: TSGroupModel,
                                          newGroupModel: TSGroupModel,
                                          newGroupThread: TSGroupThread,
                                          timeStamp: UInt64,
                                          transaction: SDSAnyWriteTransaction) {
        guard let groupBaseInfo = groupNotifyEntity.group else {
            Logger.info("[GroupCrypto] upgradeGroupCrypto: group base info is nil")
            return
        }

        let cryptoMode = groupBaseInfo.groupCryptoMode
        guard cryptoMode > 0 else {
            Logger.info("[GroupCrypto] upgradeGroupCrypto: groupCryptoMode is 0, ignoring")
            return
        }

        newGroupModel.groupCryptoMode = cryptoMode

        let gid = groupNotifyEntity.gid
        Logger.info("[GroupCrypto] Upgrade notify received: gid: \(gid), cryptoMode: \(cryptoMode), hasEncryptedName: \(groupBaseInfo.encryptedName?.isEmpty == false), hasEncryptedAvatar: \(groupBaseInfo.encryptedAvatar?.isEmpty == false)")

        if let baseInfoEntity = DTGroupBaseInfoEntity.anyFetch(uniqueId: gid, transaction: transaction) {
            baseInfoEntity.anyUpdate(transaction: transaction) { entity in
                entity.groupCryptoMode = cryptoMode
                entity.encryptedName = groupBaseInfo.encryptedName
                entity.encryptedAvatar = groupBaseInfo.encryptedAvatar
            }
            Logger.info("[GroupCrypto] Updated existing baseInfo for upgrade notification, gid: \(gid)")
        } else {
            let newBaseInfo = DTGroupBaseInfoEntity()
            newBaseInfo.gid = gid
            newBaseInfo.name = newGroupModel.groupName ?? ""
            newBaseInfo.avatar = groupBaseInfo.avatar
            newBaseInfo.groupCryptoMode = cryptoMode
            newBaseInfo.encryptedName = groupBaseInfo.encryptedName
            newBaseInfo.encryptedAvatar = groupBaseInfo.encryptedAvatar
            newBaseInfo.anyInsert(transaction: transaction)
            Logger.info("[GroupCrypto] Created new baseInfo for upgrade notification, gid: \(gid)")
        }

        let wasAlreadyEncrypted = oldGroupModel.groupCryptoMode > 0

        newGroupThread.anyUpdateGroupThread(transaction: transaction) { gthread in
            gthread.groupModel = newGroupModel
        }

        // baseInfo 刚写完，R_group 已在本地则立即解出新值
        DTGroupKeyMessageHandler.refreshEncryptedGroupDisplay(gid: gid, transaction: transaction)

        // 升级冷路径兜底：仅当 "普通群 → 加密群" 时主动触发一次单群信息拉取，
        // 命中 runFullSyncVerificationForGid 完成全员校验，关闭升级后老成员未校验窗口。
        if !wasAlreadyEncrypted {
            if let localGroupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: gid),
               !localGroupId.isEmpty {
                let targetVersion = newGroupModel.version
                Logger.info("[GroupCrypto] upgrade cold-path: trigger fullSync for serverGid=\(gid) version=\(targetVersion)")
                transaction.addAsyncCompletion(queue: DTGroupUpdateMessageProcessor.serialQueue()) {
                    SDSDatabaseStorage.shared.asyncWrite { writeTx in
                        DTGroupUpdateMessageProcessor().requestGroupInfo(withGroupId: localGroupId,
                                                                         targetVersion: targetVersion,
                                                                         needSystemMessage: false,
                                                                         generate: false,
                                                                         envelope: envelope,
                                                                         transaction: writeTx,
                                                                         completion: { _ in })
                    }
                }
            } else {
                Logger.error("[GroupCrypto] upgrade cold-path: invalid localGroupId for serverGid=\(gid)")
            }
        }

        guard display else { return }

        if wasAlreadyEncrypted {
            Logger.info("[GroupCrypto] Upgrade notify for already-encrypted group, skip system message, gid: \(gid)")
            return
        }

        let customMessage = Localized("GROUP_CRYPTO_UPGRADE_SYSTEM_MSG")

        let infoMessage = TSInfoMessage(timestamp: timeStamp,
                                        in: newGroupThread,
                                        messageType: .groupCryptoUpgrade,
                                        customMessage: customMessage)
        infoMessage.isShouldAffectThreadSorting = true
        infoMessage.anyInsert(transaction: transaction)

        Logger.info("[GroupCrypto] Inserted upgrade system message for gid: \(gid)")
    }

    // MARK: - Rotate Group Crypto

    /// Group is already encrypted; rotate only refreshes encrypted name/avatar + keyVersion and shows
    /// a "key reset" system message. The new R_group itself is covered by the GroupKeyMessage path
    /// (saveOrRotateRGroup) — no first-upgrade cold-path full sync here.
    private func handleRotateGroupCrypto(envelope: DSKProtoEnvelope,
                                         groupNotifyEntity: DTGroupNotifyEntity,
                                         display: Bool,
                                         oldGroupModel: TSGroupModel,
                                         newGroupModel: TSGroupModel,
                                         newGroupThread: TSGroupThread,
                                         timeStamp: UInt64,
                                         transaction: SDSAnyWriteTransaction) {
        guard let groupBaseInfo = groupNotifyEntity.group else {
            Logger.info("[GroupCrypto] rotateGroupCrypto: group base info is nil")
            return
        }

        let cryptoMode = groupBaseInfo.groupCryptoMode
        guard cryptoMode > 0 else {
            Logger.info("[GroupCrypto] rotateGroupCrypto: groupCryptoMode is 0, ignoring")
            return
        }

        let gid = groupNotifyEntity.gid
        let newKeyVersion = groupBaseInfo.groupCryptoKeyVersion
        Logger.info("[GroupCrypto] Rotate notify received: gid: \(gid), newKeyVersion: \(newKeyVersion), hasEncryptedName: \(groupBaseInfo.encryptedName?.isEmpty == false), hasEncryptedAvatar: \(groupBaseInfo.encryptedAvatar?.isEmpty == false)")

        newGroupModel.groupCryptoMode = cryptoMode

        // Apply the notify's ciphertext directly — no notify-side version gate. The single version
        // authority is the GroupKeyMessage path (saveOrRotateRGroup), which gates the key itself.
        // Decoupling avoids the notify-vs-GroupKeyMessage arrival-order hazard: a strict version gate
        // here would drop the notify's (correct) encryptedName whenever the key message landed first
        // and already bumped the local keyVersion. The non-empty guards keep a trigger-only notify
        // from wiping a good local value; a rare stale/duplicate notify self-corrects on the next
        // group-info refresh.
        if let baseInfoEntity = DTGroupBaseInfoEntity.anyFetch(uniqueId: gid, transaction: transaction) {
            baseInfoEntity.anyUpdate(transaction: transaction) { entity in
                entity.groupCryptoMode = cryptoMode
                if let encryptedName = groupBaseInfo.encryptedName, !encryptedName.isEmpty {
                    entity.encryptedName = encryptedName
                }
                if let encryptedAvatar = groupBaseInfo.encryptedAvatar, !encryptedAvatar.isEmpty {
                    entity.encryptedAvatar = encryptedAvatar
                }
            }
        } else {
            let newBaseInfo = DTGroupBaseInfoEntity()
            newBaseInfo.gid = gid
            newBaseInfo.name = newGroupModel.groupName ?? ""
            newBaseInfo.avatar = groupBaseInfo.avatar
            newBaseInfo.groupCryptoMode = cryptoMode
            newBaseInfo.encryptedName = groupBaseInfo.encryptedName
            newBaseInfo.encryptedAvatar = groupBaseInfo.encryptedAvatar
            newBaseInfo.anyInsert(transaction: transaction)
        }

        newGroupThread.anyUpdateGroupThread(transaction: transaction) { gthread in
            gthread.groupModel = newGroupModel
        }

        // If the new R_group already arrived (via GroupKeyMessage), decrypt the new name/avatar now.
        DTGroupKeyMessageHandler.refreshEncryptedGroupDisplay(gid: gid, transaction: transaction)

        guard display else { return }

        let infoMessage = TSInfoMessage(timestamp: timeStamp,
                                        in: newGroupThread,
                                        messageType: .groupCryptoUpgrade,
                                        customMessage: Localized("GROUP_CRYPTO_RESET_SYSTEM_MSG"))
        infoMessage.isShouldAffectThreadSorting = true
        infoMessage.anyInsert(transaction: transaction)

        Logger.info("[GroupCrypto] Inserted rotate system message for gid: \(gid)")
    }

}
