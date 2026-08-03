//
//  DTGroupUpdateMessageProcessor.swift
//  TTServiceKit
//
//  Created by user on 2024/7/18.
//

import Foundation

extension DTGroupBaseInfoEntity {
    /// Syncs mutable fields from an incoming group notify into the local baseInfo row.
    /// Empty / nil values are ignored so we never overwrite a good value with a blank one.
    public static func syncFields(gid: String,
                                  name: String? = nil,
                                  plainAvatar: String? = nil,
                                  encryptedName: String? = nil,
                                  encryptedAvatar: String? = nil,
                                  transaction: SDSAnyWriteTransaction) {
        guard let baseInfo = Self.anyFetch(uniqueId: gid, transaction: transaction) else { return }
        let beforeEncryptedName = baseInfo.encryptedName
        baseInfo.anyUpdate(transaction: transaction) { entity in
            if let name, !name.isEmpty { entity.name = name }
            if let plainAvatar, !plainAvatar.isEmpty { entity.avatar = plainAvatar }
            if let encryptedName, !encryptedName.isEmpty { entity.encryptedName = encryptedName }
            if let encryptedAvatar, !encryptedAvatar.isEmpty { entity.encryptedAvatar = encryptedAvatar }
        }
        let afterEncryptedName = Self.anyFetch(uniqueId: gid, transaction: transaction)?.encryptedName
        if beforeEncryptedName != afterEncryptedName {
            Logger.info("[GroupCrypto] syncFields gid=\(gid) encryptedName changed: \(beforeEncryptedName ?? "nil") → \(afterEncryptedName ?? "nil")")
        }
    }
}

extension DTGroupUpdateMessageProcessor {
    
    @objc public func handleGroupMessageArchiveChanged(oldGroupModel: TSGroupModel,
                                          newGroupModel: TSGroupModel,
                                          newGroupThread: TSGroupThread,
                                          timestamp: UInt64,
                                          transaction: SDSAnyWriteTransaction) {
        
        if DTParamsUtils.validateNumber(newGroupModel.messageExpiry).boolValue,
           DTGroupUtils.isChangedArchiveMessageString(withOldGroupModel: oldGroupModel, newModel: newGroupModel) {
            
            transaction.addAsyncCompletionOnMain {
                NotificationCenter.default.post(name: NSNotification.Name.DTGroupMessageExpiryConfigChanged, object: nil)
            }
        }
    }
    
    @objc public func processGroupUpdateDetailNotifyHandler(envelope: DSKProtoEnvelope, 
                                                            groupNotifyEntity: DTGroupNotifyEntity,
                                                            display: Bool,
                                                            oldGroupModel: TSGroupModel,
                                                            newGroupModel: TSGroupModel,
                                                            newGroupThread: TSGroupThread,
                                                            timeStamp: UInt64,
                                                            transaction: SDSAnyWriteTransaction) {
        
        let handler = self.getHandler(for: groupNotifyEntity.groupNotifyDetailedType)
        guard let handler else { return }
        
        let context = GroupNotifyContext(handler: handler)
        context.executeStrategy(envelope: envelope,
                                groupNotifyEntity: groupNotifyEntity,
                                display: display,
                                oldGroupModel: oldGroupModel,
                                newGroupModel: newGroupModel,
                                newGroupThread: newGroupThread,
                                timeStamp: timeStamp,
                                transaction: transaction)
          
    }
    
    @objc public func handleDonotTrackVersio(envelope: DSKProtoEnvelope,
                                             groupNotifyEntity: DTGroupNotifyEntity,
                                             oldGroupModel: TSGroupModel,
                                             newGroupThread: TSGroupThread,
                                             transaction: SDSAnyWriteTransaction) {
        
        GroupNotifyDonotTrackVersionHandler.handleDonotTrackVersio(envelope: envelope,
                                                                   groupNotifyEntity: groupNotifyEntity,
                                                                   oldGroupModel: oldGroupModel,
                                                                   newGroupThread: newGroupThread,
                                                                   transaction: transaction)
    }

    
    @objc public func isNeedTrackVersion(groupNotifyEntity: DTGroupNotifyEntity) -> Bool {
        
        return GroupNotifyDonotTrackVersionHandler.isNeedTrackVersion(groupNotifyEntity: groupNotifyEntity)
    }
    
    @objc public func processGroupUpdateDetailNotifyForSelfHandler(envelope: DSKProtoEnvelope,
                                                                   groupNotifyEntity: DTGroupNotifyEntity,
                                                                   display: Bool,
                                                                   oldGroupModel: TSGroupModel,
                                                                   newGroupModel: TSGroupModel,
                                                                   newGroupThread: TSGroupThread,
                                                                   timeStamp: UInt64,
                                                                   transaction: SDSAnyWriteTransaction) {

        newGroupModel.version = groupNotifyEntity.groupVersion
        newGroupThread.anyUpdateGroupThread(transaction: transaction) { instance in
            instance.groupModel = newGroupModel

            // notify自己的时候
            if groupNotifyEntity.groupNotifyDetailedType == .groupMsgExpiryChange {
                DataUpdateUtil.shared.updateConversation(thread: instance,
                                                         expireTime: groupNotifyEntity.group?.messageExpiry,
                                                         messageClearAnchor: NSNumber(value: groupNotifyEntity.group?.messageClearAnchor ?? 0),
                                                         transaction: transaction)
            }
        }

        // 加密群：同步 encryptedName / encryptedAvatar 到 DTGroupBaseInfoEntity
        if let group = groupNotifyEntity.group, group.groupCryptoMode > 0 {
            DTGroupBaseInfoEntity.syncFields(gid: groupNotifyEntity.gid,
                                             plainAvatar: group.avatar,
                                             encryptedName: group.encryptedName,
                                             encryptedAvatar: group.encryptedAvatar,
                                             transaction: transaction)
        }

        transaction.addAsyncCompletionOnMain {
            NotificationCenter.default.post(name: NSNotification.Name.DTGroupMessageExpiryConfigChanged, object: nil)
        }

        if groupNotifyEntity.groupNotifyDetailedType == .createGroup, groupNotifyEntity.group?.autoClear == true {
            let infoMessage = DTGroupUpdateInfoMessageHelper.gOpenAutoClearSwitchInfoMessage(with: newGroupThread, isOn: true)
            infoMessage.anyInsert(transaction: transaction)
        }

    }
    
    @objc public func getHandler(for notifyType: DTGroupNotifyDetailType) -> GroupNotifyHandler? {
        
        switch notifyType {
            
        case .createGroup,
                .joinGroup,
                .leaveGroup,
                .inviteJoinGroup,
                .kickoutGroup,
                .dismissGroup,
                .destroy,
                .kickoutAutoClear,
                .groupAccountInvalid:
            return GroupNotifyManagementHandler()
                
        case .groupNameChange,
                .groupAvatarChange,
                .groupMsgExpiryChange,
                .groupRemindChange,
                .groupAnyoneRemoveChange,
                .groupRejoinChange,
                .privateChatChange,
                .groupPublishRuleChange,
                .groupExtChange,
                .groupAnyoneChangeNameChange,
                .anyoneChangeAutoClearChange,
                .autoClearChange,
                .privilegeConfidential,
                .groupRapidRoleChange,
                .criticalAlertChange,
                .upgradeGroupCrypto,
                .rotateGroupCrypto :
            return GroupNotifyGroupInfoHandler()
          
        case .groupSelfInfoChange:
            return GroupNotifySelfInfoChangeHandler()
                    
        case .groupAddAdmin,
                .groupDeleteAdmin,
                .groupMemberInfoChange,
                .groupOwnerChange:
            return GroupNotifyAdminUpdateHandler()
        default:
            return nil
        }
    }
    
    @objc static public func saveExternalMember(member: DTGroupMemberEntity, transaction: SDSAnyWriteTransaction) -> SignalAccount? {
        
        var signalAccount = SignalAccount(recipientId: member.uid, transaction: transaction)
        
        if let  signalAccount = signalAccount {
            
            if let contact = signalAccount.contact, !contact.isExternal {
                return nil
            }
            
            if let contact = signalAccount.contact, 
                contact.isExternal,
                contact.groupDisplayName == member.displayName,
                contact.extId == member.extId {
                return nil
            }
            
            signalAccount.contact?.groupDisplayName = member.displayName;
            signalAccount.contact?.extId = member.extId;
            signalAccount.contact?.isExternal = true;
            
        } else {
            
            signalAccount = SignalAccount(recipientId: member.uid)
            signalAccount?.isManualEdited = true;
            let contact = Contact()
            contact?.groupDisplayName = member.displayName;
            contact?.number = member.uid;
            contact?.extId = member.extId;
            contact?.isExternal = true;
            signalAccount?.contact = contact;
        }
        
        return signalAccount
    }
    
}
