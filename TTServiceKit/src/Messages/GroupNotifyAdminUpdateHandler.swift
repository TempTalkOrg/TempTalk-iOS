//
//  GroupNotifyAdminUpdateHandler.swift
//  TTServiceKit
//
//  Created by user on 2024/8/12.
//

import Foundation
class GroupNotifyAdminUpdateHandler : GroupNotifyHandler {
    
//    .groupAddAdmin,
//    .groupDeleteAdmin,
//    .groupMemberInfoChange
//    .groupOwnerChange
    func handle(envelope: DSKProtoEnvelope,
                groupNotifyEntity: DTGroupNotifyEntity,
                display: Bool,
                oldGroupModel: TSGroupModel,
                newGroupModel: TSGroupModel,
                newGroupThread: TSGroupThread,
                timeStamp: UInt64,
                transaction: SDSAnyWriteTransaction) {
     
        if groupNotifyEntity.groupNotifyDetailedType == .groupAddAdmin {
            
            updateGroupAddAdmin(envelope: envelope,
                                groupNotifyEntity: groupNotifyEntity,
                                display: display,
                                oldGroupModel: oldGroupModel,
                                newGroupModel: newGroupModel,
                                newGroupThread: newGroupThread,
                                timeStamp: timeStamp,
                                transaction: transaction)
            
        } else if groupNotifyEntity.groupNotifyDetailedType == .groupDeleteAdmin {
            
            updateGroupDeleteAdmin(envelope: envelope,
                                groupNotifyEntity: groupNotifyEntity,
                                display: display,
                                oldGroupModel: oldGroupModel,
                                newGroupModel: newGroupModel,
                                newGroupThread: newGroupThread,
                                timeStamp: timeStamp,
                                transaction: transaction)
            
        } else if groupNotifyEntity.groupNotifyDetailedType == .groupMemberInfoChange {
            //check 和sever 和核对之后发现这个类型暂时没有使用
            Logger.error("groupMemberInfoChange 这个类型暂时没有使用，请核查")
            
        } else if groupNotifyEntity.groupNotifyDetailedType == .groupOwnerChange {
            
            updaterGoupOwnerChange(envelope: envelope,
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
    
 
    func updateGroupAddAdmin(envelope: DSKProtoEnvelope,
                              groupNotifyEntity: DTGroupNotifyEntity,
                              display: Bool,
                              oldGroupModel: TSGroupModel,
                              newGroupModel: TSGroupModel,
                              newGroupThread: TSGroupThread,
                              timeStamp: UInt64,
                              transaction: SDSAnyWriteTransaction) {
        
        // 过滤出所有添加到群中的管理员成员
        let addedAdminIds = getAddedAdminIds(from: groupNotifyEntity, in: newGroupModel)
        
        // 更新管理员列表
        updateGroupAdminIds(with: addedAdminIds, in: newGroupModel)
        
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { groupThread in
            groupThread.groupModel = newGroupModel
        }

        // 创建并插入系统信息消息
        let infoMessageDesc = DTGroupUtils.getMemberChangedInfoString(withAddedAdminIds: addedAdminIds, removedIds: nil, transaction: transaction)
        let systemInfoMsg = TSInfoMessage(timestamp: timeStamp,
                                          in: newGroupThread,
                                          messageType:.typeGroupUpdate,
                                          customMessage: infoMessageDesc)
        systemInfoMsg.anyInsert(transaction: transaction)
    }

    // 获取添加的管理员 ID
    private func getAddedAdminIds(from groupNotifyEntity: DTGroupNotifyEntity, in newGroupModel: TSGroupModel) -> [String] {
        
        let filteredMembers = groupNotifyEntity.members.filter { $0.action == .update && $0.role == .admin }
        let newGroupMembers = newGroupModel.groupMemberIds
        
        return filteredMembers.compactMap { memberNotifyEntity in
            // 检查条件并返回 UID
            guard !newGroupMembers.isEmpty,
                  newGroupMembers.contains(memberNotifyEntity.uid),
                  !newGroupModel.groupAdmin.contains(memberNotifyEntity.uid) else {
                return nil
            }
            return memberNotifyEntity.uid
        }
        
    }

    // 更新群组管理员 IDs
    private func updateGroupAdminIds(with addedAdminIds: [String], in newGroupModel: TSGroupModel) {
        
        guard !addedAdminIds.isEmpty else { return }
        
        var newGroupAdminIds = Set(newGroupModel.groupAdmin)
        newGroupAdminIds.formUnion(addedAdminIds)
        newGroupModel.groupAdmin = Array(newGroupAdminIds)
        
    }

    func updateGroupDeleteAdmin(envelope: DSKProtoEnvelope,
                                 groupNotifyEntity: DTGroupNotifyEntity,
                                 display: Bool,
                                 oldGroupModel: TSGroupModel,
                                 newGroupModel: TSGroupModel,
                                 newGroupThread: TSGroupThread,
                                 timeStamp: UInt64,
                                 transaction: SDSAnyWriteTransaction) {
        
        ///过滤出来所有添加到群中的成员 DTGroupMemberNotifyEntity
        let filteredmembers = groupNotifyEntity.members.filter { $0.action == .update && $0.role == .member }
        var signalAccounts = [SignalAccount]()
        
        let removedAdminIds = filteredmembers
            .filter { memberNotifyEntity in
                // 检查 newGroupMembers 是否包含 memberNotifyEntity.uid，并且 newGroupModel.groupAdmin 不包含该 uid
                let newGroupMembers = newGroupModel.groupMemberIds
                if !newGroupMembers.isEmpty &&
                       newGroupMembers.contains(memberNotifyEntity.uid) &&
                    newGroupModel.groupAdmin.contains(memberNotifyEntity.uid) {
                    
                    
                    if let account = DTGroupUpdateMessageProcessor.saveExternalMember(member: memberNotifyEntity, transaction: transaction) {
                        signalAccounts.append(account)
                    }
                    
                    return true
                    
                } else {
                    
                    return false
                    
                }
            }
            .map { $0.uid } // 提取符合条件的 uid
        
        guard !removedAdminIds.isEmpty else { return }
        
        var newAdminMemberIds = Set(newGroupModel.groupAdmin) // 使用 Set 去重
        for receptiedUid in removedAdminIds {
            // 如果 newAdminMemberIds 包含 receptiedUid，则将其移除
            if newAdminMemberIds.contains(receptiedUid) {
                newAdminMemberIds.remove(receptiedUid)
            }
        }
        newGroupModel.groupAdmin = Array(newAdminMemberIds)
        
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { groupThread in
            groupThread.groupModel = newGroupModel
        }

        if !signalAccounts.isEmpty {
            TextSecureKitEnv.shared().contactsManager.update(with: signalAccounts)
        }
        
        let infoMessageDesc = DTGroupUtils.getMemberChangedInfoString(withAddedAdminIds: nil,
                                                                      removedIds: removedAdminIds,
                                                                      transaction: transaction)
        let systemInfoMsg = TSInfoMessage.init(timestamp: timeStamp, in: newGroupThread, messageType: .typeGroupUpdate, customMessage: infoMessageDesc)
        systemInfoMsg.anyInsert(transaction: transaction)
    }
    
    func updaterGoupOwnerChange(envelope: DSKProtoEnvelope,
                                 groupNotifyEntity: DTGroupNotifyEntity,
                                 display: Bool,
                                 oldGroupModel: TSGroupModel,
                                 newGroupModel: TSGroupModel,
                                 newGroupThread: TSGroupThread,
                                 timeStamp: UInt64,
                                 transaction: SDSAnyWriteTransaction) {
        
        let owners = groupNotifyEntity.members.filter { $0.action == .update && $0.role == .owner }.map{ $0.uid }
        let admins = groupNotifyEntity.members.filter { $0.action == .update && $0.role == .admin }.map{ $0.uid }
        guard !owners.isEmpty, !admins.isEmpty, let owner_new = owners.first else { return }
       
        var newGroupAdminIds = Set(newGroupModel.groupAdmin)
        newGroupAdminIds.formUnion(admins)
        newGroupModel.groupAdmin = Array(newGroupAdminIds)
        newGroupModel.groupOwner = owner_new
        
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { groupThread in
            groupThread.groupModel = newGroupModel
        }
        
        if oldGroupModel.groupOwner != owner_new && !owner_new.isEmpty && !oldGroupModel.groupOwner.isEmpty {
            var newGroupAdminIds = Set(newGroupModel.groupAdmin)
            
            if newGroupAdminIds.contains(owner_new) {
                newGroupAdminIds.remove(owner_new)
            }
            
            let owerIdArr = [owner_new] // 这里的 receptid 是一个 String? 类型的变量
            // 使用 map 来转换 owerIdArr 中的元素
            let owerIdArrNames = owerIdArr.map { item -> String in
                if item == TSAccountManager.sharedInstance().localNumber(with: transaction) {
                    return NSLocalizedString("YOU", comment: "")
                }
                return TextSecureKitEnv.shared().contactsManager.displayName(forPhoneIdentifier: item, transaction: transaction)
            }

            let infoMessageDesc = String(format: NSLocalizedString("GROUP_MEMBER_INFO_UPDATE_BECOME_OWER", comment: ""), owerIdArrNames.first ?? "")
            let systemInfoMsg = TSInfoMessage.init(timestamp: timeStamp, in: newGroupThread, messageType: .typeGroupUpdate, customMessage: infoMessageDesc)
            systemInfoMsg.anyInsert(transaction: transaction)

        } else {
            Logger.error("oldGroupModel.groupOwner = \(oldGroupModel.groupOwner) owner_new = \(owner_new)")
        }
       
    }
    
}
