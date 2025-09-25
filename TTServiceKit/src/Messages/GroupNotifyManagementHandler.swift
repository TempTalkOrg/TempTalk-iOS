//
//  DTGroupNotifyBaseInfoHander.swift
//  TTServiceKit
//
//  Created by user on 2024/7/22.
//

import Foundation
///createGroup
///joinGroup
///groupLinkJoin
///leaveGroup
///inviteJoinGroup
///kickoutGroup
///dismissGroup
///已完成测试
class GroupNotifyManagementHandler : GroupNotifyHandler {
    
    func handle(envelope: DSKProtoEnvelope,
                groupNotifyEntity: DTGroupNotifyEntity,
                display: Bool,
                oldGroupModel: TSGroupModel,
                newGroupModel: TSGroupModel,
                newGroupThread: TSGroupThread,
                timeStamp: UInt64,
                transaction: SDSAnyWriteTransaction) {
        
        if groupNotifyEntity.groupNotifyDetailedType == .createGroup {
            
            createGroup(envelope: envelope,
                        groupNotifyEntity: groupNotifyEntity,
                        display: display,
                        oldGroupModel: oldGroupModel,
                        newGroupModel: newGroupModel,
                        newGroupThread: newGroupThread,
                        timeStamp:timeStamp,
                        transaction: transaction)
            
        } else if groupNotifyEntity.groupNotifyDetailedType == .joinGroup
                  || groupNotifyEntity.groupNotifyDetailedType == .groupLinkJoin {//DTGroupNotifyTypeMemberChanged
            
            let filteredUids = groupNotifyEntity.members.filter { $0.action == .add }.map { $0.uid }
            joinGroup(envelope: envelope,
                      groupNotifyEntity: groupNotifyEntity,
                      display: display,
                      filteredUids: filteredUids,
                      oldGroupModel: oldGroupModel,
                      newGroupModel: newGroupModel,
                      newGroupThread: newGroupThread,
                      timeStamp:timeStamp,
                      transaction: transaction)
            
        }  else if groupNotifyEntity.groupNotifyDetailedType == .inviteJoinGroup {//DTGroupNotifyTypeMemberChanged
            
            inviteJoinGroup(envelope: envelope,
                            groupNotifyEntity: groupNotifyEntity,
                            display: display,
                            oldGroupModel: oldGroupModel,
                            newGroupModel: newGroupModel,
                            newGroupThread: newGroupThread,
                            timeStamp:timeStamp,
                            transaction: transaction)
            
        }  else if groupNotifyEntity.groupNotifyDetailedType == .dismissGroup ||
                    groupNotifyEntity.groupNotifyDetailedType == .destroy {
            
            dismissGroup(envelope: envelope,
                         groupNotifyEntity: groupNotifyEntity,
                         display: display,
                         oldGroupModel: oldGroupModel,
                         newGroupModel: newGroupModel,
                         newGroupThread: newGroupThread,
                         timeStamp:timeStamp,
                         transaction: transaction)
            
        } else if groupNotifyEntity.groupNotifyDetailedType == .leaveGroup {
            
            leaveGroup(envelope: envelope,
                       groupNotifyEntity: groupNotifyEntity,
                       display: display,
                       oldGroupModel: oldGroupModel,
                       newGroupModel: newGroupModel,
                       newGroupThread: newGroupThread,
                       timeStamp:timeStamp,
                       transaction: transaction)

        } else if groupNotifyEntity.groupNotifyDetailedType == .kickoutGroup {
            
            kickoutGroup(envelope: envelope,
                         groupNotifyEntity: groupNotifyEntity,
                         display: display,
                         oldGroupModel: oldGroupModel,
                         newGroupModel: newGroupModel,
                         newGroupThread: newGroupThread,
                         timeStamp:timeStamp,
                         transaction: transaction)

        }  else {
            Logger.info("unsupported type")
        }
        
    }
    
    func createGroup(envelope: DSKProtoEnvelope,
                     groupNotifyEntity: DTGroupNotifyEntity,
                     display: Bool,
                     oldGroupModel: TSGroupModel,
                     newGroupModel: TSGroupModel,
                     newGroupThread: TSGroupThread,
                     timeStamp: UInt64,
                     transaction: SDSAnyWriteTransaction) {
        
        let filteredUids = groupNotifyEntity.members.filter { $0.action == .add }.map { $0.uid }
        
        joinGroup(envelope: envelope,
                  groupNotifyEntity: groupNotifyEntity,
                  display: display,
                  filteredUids: filteredUids,
                  oldGroupModel: oldGroupModel,
                  newGroupModel: newGroupModel,
                  newGroupThread: newGroupThread,
                  timeStamp:timeStamp,
                  transaction: transaction)
        
        if groupNotifyEntity.groupNotifyDetailedType == .createGroup, groupNotifyEntity.group?.autoClear == true {
            let updateGroupInfo = Localized("LIST_GROUP_AUTO_CLEAN_TURN_ON_MSG", comment: "")
            let timestamp = timeStamp - 1
            let infoMessage = TSInfoMessage(timestamp: timestamp,
                                            in: newGroupThread,
                                            messageType: .typeGroupUpdate,
                                            customMessage: updateGroupInfo)
            infoMessage.isShouldAffectThreadSorting = true
            infoMessage.anyInsert(transaction: transaction)
        }
        
    }
    
    func leaveGroup(envelope: DSKProtoEnvelope,
                    groupNotifyEntity: DTGroupNotifyEntity,
                    display: Bool,
                    oldGroupModel: TSGroupModel,
                    newGroupModel: TSGroupModel,
                    newGroupThread: TSGroupThread,
                    timeStamp: UInt64,
                    transaction: SDSAnyWriteTransaction) {
        
        let localNumber = TSAccountManager.sharedInstance().localNumber(with: transaction)
        ///过滤出来所有要离开的成员
        let filteredUids = groupNotifyEntity.members.filter { $0.action == .leave }.map { $0.uid }
        ///退群
        if let localNumber = localNumber, filteredUids.contains(where: {$0 == localNumber}) {
            
            dismissGroup(envelope: envelope,
                         groupNotifyEntity: groupNotifyEntity,
                         display: display,
                         oldGroupModel: oldGroupModel,
                         newGroupModel: newGroupModel,
                         newGroupThread: newGroupThread,
                         timeStamp:timeStamp,
                         transaction: transaction)
            return
        }
        
        if let group = groupNotifyEntity.group, group.ext != oldGroupModel.isExt {
            newGroupModel.isExt = group.ext
            transaction.addAsyncCompletionOffMain {
                DTGroupUtils.postExternalChangeNotification(withTargetIds: [newGroupThread.uniqueId : NSNumber.init(value:  group.ext)])
            }
        }
        
        let groupMemberIdsSet = Set(newGroupModel.groupMemberIds)
        // 筛选出 filteredUids 中不在 newGroupModel.groupMemberIds 的 ID
        // leftUids 检查当前群组是否存在这些用户
        let leftUids = filteredUids.filter { groupMemberIdsSet.contains($0) }.compactMap { uid -> String? in
            
            let rapidRole = oldGroupModel.rapidRole(for: uid)
            if rapidRole != .none {
                newGroupModel.removeRapidRole(uid)
                DTGroupUtils.postRapidRoleChangeNotification(with: newGroupModel, targedMemberIds: [uid])
            }
            
            return uid
        }
        
        guard !leftUids.isEmpty else {
            return
        }
        
        newGroupModel.groupMemberIds.removeAll { leftUids.contains($0) }
        newGroupModel.groupAdmin.removeAll { leftUids.contains($0) }
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { gthread in
            gthread.groupModel = newGroupModel
        }
        
        let newMembersNames = leftUids.map { uid in
            
            if uid == localNumber {
                return Localized("YOU", comment: "")
            } else {
                return TextSecureKitEnv.shared().contactsManager.displayName(forPhoneIdentifier: uid, transaction: transaction)
            }
            
        }
        guard display else { return }
        
        let  updatedGroupInfoString = String.init(format:  Localized("GROUP_MEMBER_LEFT", comment: ""), newMembersNames.joined(separator: ", "))
        let shouldAffectThreadSorting = false
        
        let infoMessage = TSInfoMessage.init(timestamp: timeStamp, in: newGroupThread, messageType: .typeGroupUpdate, customMessage: updatedGroupInfoString)
        infoMessage.isShouldAffectThreadSorting = shouldAffectThreadSorting
        infoMessage.anyInsert(transaction: transaction)
        
    }
    
    func inviteJoinGroup(envelope: DSKProtoEnvelope,
                         groupNotifyEntity: DTGroupNotifyEntity,
                         display: Bool,
                         oldGroupModel: TSGroupModel,
                         newGroupModel: TSGroupModel,
                         newGroupThread: TSGroupThread,
                         timeStamp: UInt64,
                         transaction: SDSAnyWriteTransaction) {
        
        
        let localNumber = TSAccountManager.sharedInstance().localNumber(with: transaction)
        ///过滤出来所有添加到群中的成员
        let filteredUids = groupNotifyEntity.members.filter { $0.action == .add }.map { $0.uid }
        ///自己有被邀请进群
        if let localNumber = localNumber, filteredUids.contains(where: {$0 == localNumber}) {
            
            DTPinnedDataSource.shared().syncPinnedMessage(withServer: groupNotifyEntity.gid)
            let baseInfo = DTGroupBaseInfoEntity()
            baseInfo.name = newGroupThread.name(with: transaction)
            baseInfo.gid = newGroupThread.serverThreadId;
            DTGroupUtils.addGroupBaseInfo(baseInfo, transaction: transaction)
            
        }
        
        if let group = groupNotifyEntity.group, group.ext != oldGroupModel.isExt {
            newGroupModel.isExt = group.ext
            transaction.addAsyncCompletionOffMain {
                DTGroupUtils.postExternalChangeNotification(withTargetIds: [newGroupThread.uniqueId : NSNumber.init(value:  group.ext)])
            }
        }
        
        joinGroup(envelope: envelope,
                  groupNotifyEntity: groupNotifyEntity,
                  display: display,
                  filteredUids: filteredUids,
                  oldGroupModel: oldGroupModel,
                  newGroupModel: newGroupModel,
                  newGroupThread: newGroupThread,
                  timeStamp:timeStamp,
                  transaction: transaction)
        
    }
    
    ///主动进群的操作，包括群链接和rejoin
    func joinGroup(envelope: DSKProtoEnvelope,
                   groupNotifyEntity: DTGroupNotifyEntity,
                   display: Bool,
                   filteredUids: [String],
                   oldGroupModel: TSGroupModel,
                   newGroupModel: TSGroupModel,
                   newGroupThread: TSGroupThread,
                   timeStamp: UInt64,
                   transaction: SDSAnyWriteTransaction) {
        
        var updatedGroupInfoString = ""
        let shouldAffectThreadSorting = false
        let localNumber = TSAccountManager.sharedInstance().localNumber(with: transaction)
        
        let groupMemberIdsSet = Set(newGroupModel.groupMemberIds)
        // 筛选出 filteredUids 中不在 newGroupModel.groupMemberIds 的 ID 并重组为 signalAccounts 数组
        let signalAccounts = filteredUids.filter { !groupMemberIdsSet.contains($0) }.compactMap { uid -> SignalAccount? in
            // 假设 `groupNotifyEntity.members` 中存在匹配 uid 的成员
            if let member = groupNotifyEntity.members.first(where: { $0.uid == uid }) {
                return DTGroupUpdateMessageProcessor.self.saveExternalMember(member: member, transaction: transaction)
            }
            return nil
        }
        
        if !signalAccounts.isEmpty {
            TextSecureKitEnv.shared().contactsManager.update(with: signalAccounts)
        }
        
        let filteredUidsSet = Set(filteredUids)
        // 合并两个集合并转换为数组
        let mergedGroupMembers = Array(groupMemberIdsSet.union(filteredUidsSet))
        newGroupModel.groupMemberIds = mergedGroupMembers
        if let groupName = groupNotifyEntity.group?.name {
            newGroupModel.groupName = groupName
        }
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { gThread in
            gThread.groupModel = newGroupModel
        }
        
        ///由于收到的是创建群的通知，因为自己有收到通知，所以检查一下 filteredUids （添加到群中的人）是否有自己，没有自己的话需要把自己加到群里
        var uidsSet = Set(filteredUids)
        if let localNumber = localNumber,
           !uidsSet.contains(localNumber),
           groupNotifyEntity.groupNotifyDetailedType == .createGroup {
            uidsSet.insert(localNumber)
        }
         
        let updatedUids = Array(uidsSet)
        if !updatedUids.isEmpty {
            let newMembersNames = filteredUids.map { uid in
                
                if uid == localNumber {
                    return Localized("YOU", comment: "")
                } else {
                    return TextSecureKitEnv.shared().contactsManager.displayName(forPhoneIdentifier: uid, transaction: transaction)
                }
                
            }
            
            if !newMembersNames.isEmpty {
                
                updatedGroupInfoString = String(format: Localized("GROUP_MEMBER_JOINED", comment: ""), newMembersNames.joined(separator: ", "))
                
            }
        }
        
        if let baseInfo = groupNotifyEntity.group {
          
            baseInfo.gid = groupNotifyEntity.gid;
            
            if let groupName = groupNotifyEntity.group?.name {
                baseInfo.name = groupName
            }
            baseInfo.anyInsert(transaction: transaction)
            DTGroupUtils.postGroupBaseInfoChange(with: baseInfo, remove: false)
            
        }
        
        guard display else { return }
        
        if let localNumber = localNumber,
            !uidsSet.contains(localNumber),
           groupNotifyEntity.groupNotifyDetailedType == .joinGroup {
            
            let infoMessage = TSInfoMessage.init(timestamp: timeStamp,
                                                 in: newGroupThread,
                                                 messageType: .groupAddMember,
                                                 customMessage: updatedGroupInfoString)
            
            infoMessage.anyInsert(transaction: transaction)
        } else {
            
            let infoMessage = TSInfoMessage.init(timestamp: timeStamp, in: newGroupThread, messageType: .typeGroupUpdate, customMessage: updatedGroupInfoString)
            infoMessage.isShouldAffectThreadSorting = shouldAffectThreadSorting
            infoMessage.anyInsert(transaction: transaction)
            
        }
        
    }
    
    func kickoutGroup(envelope: DSKProtoEnvelope,
                      groupNotifyEntity: DTGroupNotifyEntity,
                      display: Bool,
                      oldGroupModel: TSGroupModel,
                      newGroupModel: TSGroupModel,
                      newGroupThread: TSGroupThread,
                      timeStamp: UInt64,
                      transaction: SDSAnyWriteTransaction) {
        // 被踢出群
        // 被踢出群需要检查被踢的人是否是群管理人员，是群管理就把他变成普通成员
        let localNumber = TSAccountManager.sharedInstance().localNumber(with: transaction)
        ///过滤出来所有添加到群中的成员 DTGroupMemberNotifyEntity
        let filteredUids = groupNotifyEntity.members.filter { $0.action == .delete }.map { member -> String in
            return member.uid
        }
        
        //自己被踢
        if let localNumber = localNumber, filteredUids.contains(where: {$0 == localNumber}) {
            
            dismissGroup(envelope: envelope,
                         groupNotifyEntity: groupNotifyEntity,
                         display: display,
                         oldGroupModel: oldGroupModel,
                         newGroupModel: newGroupModel,
                         newGroupThread: newGroupThread,
                         timeStamp:timeStamp,
                         transaction: transaction)
            return
        }
        
        let meGroupNotifyEntity = groupNotifyEntity.members.filter {$0.uid == localNumber}.first
        let inviteCode = meGroupNotifyEntity?.inviteCode;
        
        DTPinnedDataSource.shared().removeAllPinnedMessage(groupNotifyEntity.gid)
        DTGroupUtils.removeGroupBaseInfo(withGid: groupNotifyEntity.gid, transaction: transaction)
        if newGroupThread.isSticked {
            newGroupThread.unstickThread(with: transaction)
        }
        newGroupThread.clearDraft(with: transaction)
        
        if let group = groupNotifyEntity.group, group.ext != oldGroupModel.isExt {
            newGroupModel.isExt = group.ext
            transaction.addAsyncCompletionOffMain {
                DTGroupUtils.postExternalChangeNotification(withTargetIds: [newGroupThread.uniqueId : NSNumber.init(value:  group.ext)])
            }
        }
        
        let oldGroupMembers = newGroupModel.groupMemberIds
        let filteredUidsSet = Set(filteredUids)
        let oldGroupAdmins = newGroupModel.groupAdmin
        // 过滤掉 oldGroupMembers 中出现在 filteredUids 中的元素
        let updatedGroupMembers = oldGroupMembers.filter { !filteredUidsSet.contains($0) }
        let updateAdmins = oldGroupAdmins.filter{!filteredUidsSet.contains($0)}
        // 去重后的数组赋值
        newGroupModel.groupMemberIds = Array(Set(updatedGroupMembers))
        newGroupModel.groupAdmin =  Array(Set(updateAdmins))
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { gThread in
            gThread.groupModel = newGroupModel
        }
        
        var tmpShouldAffectSorting = false
        var updatedGroupInfoString = ""
        
        let oldMembersNames = filteredUids.map { item -> String in
            if item == localNumber {
                tmpShouldAffectSorting = true
                return Localized("YOU", comment: "")
            }
            return TextSecureKitEnv.shared().contactsManager.displayName(forPhoneIdentifier: item, transaction: transaction)
        }
        
        if oldMembersNames.count == 1 {
            if oldMembersNames.first == Localized("YOU", comment: "") {
                updatedGroupInfoString = String(format: Localized("UPDATE_GROUP_MESSAGE_BODY_REMOVE_MEMBERS", comment: ""), oldMembersNames.joined(separator: ", "))
            } else {
                updatedGroupInfoString = String(format: Localized("UPDATE_GROUP_MESSAGE_BODY_REMOVE_MEMBER", comment: ""), oldMembersNames.joined(separator: ", "))
            }
        }
        
        guard display else { return }

        if let inviteCode = inviteCode {
            
            if inviteCode.isEmpty {
                ///生成系统消息的时候优先使用server时间戳
                let infoMessage = TSInfoMessage.init(timestamp: timeStamp, 
                                                     in: newGroupThread,
                                                     messageType: .typeGroupUpdate,
                                                     customMessage: updatedGroupInfoString)
                infoMessage.isShouldAffectThreadSorting = tmpShouldAffectSorting
                infoMessage.anyInsert(transaction: transaction)
               
            } else {
               
                let invitationRule = newGroupModel.invitationRule.intValue
                let isOpteratorGroupOwner = newGroupModel.groupOwner == groupNotifyEntity.source
                let isOpteratorGroupAdmin = newGroupModel.groupAdmin.contains(where: { $0 == groupNotifyEntity.source })
                let opteratorHasInvitePermission = (invitationRule == 0 && isOpteratorGroupOwner) ||
                            (invitationRule == 1 && (isOpteratorGroupOwner || isOpteratorGroupAdmin)) || invitationRule == 2;
                
                if !newGroupModel.rejoin || (newGroupModel.rejoin && !opteratorHasInvitePermission) {
                    
                    let infoMessage = TSInfoMessage.init(timestamp: timeStamp,
                                                         in: newGroupThread,
                                                         messageType: .typeGroupUpdate,
                                                         customMessage: updatedGroupInfoString)
                    
                    infoMessage.isShouldAffectThreadSorting = tmpShouldAffectSorting
                    infoMessage.anyInsert(transaction: transaction)
                    
                } else {
                    
                    DTGroupUtils.sendGroupRejoinMessage(withInviteCode: inviteCode,
                                                        updateInfo: updatedGroupInfoString,
                                                        thread: newGroupThread,
                                                        transaction: transaction)
                }
            }
            
        } else {
            
            let infoMessage = TSInfoMessage.init(timestamp: timeStamp, 
                                                 in: newGroupThread,
                                                 messageType: .typeGroupUpdate,
                                                 customMessage: updatedGroupInfoString)
            infoMessage.isShouldAffectThreadSorting = tmpShouldAffectSorting
            infoMessage.anyInsert(transaction: transaction)
           
        }
        
    }
    
    func dismissGroup(envelope: DSKProtoEnvelope,
                      groupNotifyEntity: DTGroupNotifyEntity,
                      display: Bool,
                      oldGroupModel: TSGroupModel,
                      newGroupModel: TSGroupModel,
                      newGroupThread: TSGroupThread,
                      timeStamp: UInt64,
                      transaction: SDSAnyWriteTransaction) {
        
        DTPinnedDataSource.shared().removeAllPinnedMessage(groupNotifyEntity.gid)
        DTGroupUtils.removeGroupBaseInfo(withGid: groupNotifyEntity.gid, transaction: transaction)
        newGroupThread.anyRemove(transaction: transaction)
    }
}
