//
//  DTGroupUpdateMessageProcessor.swift
//  TTServiceKit
//
//  Created by user on 2024/7/18.
//

import Foundation

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
        guard let handler  else {
            return
        }
        
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
                                                         messageClearAnchor: NSNumber(value: groupNotifyEntity.group?.messageClearAnchor ?? 0))
            }
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
                .destroy:
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
                .groupRapidRoleChange:
            return GroupNotifyGroupInfoHandler()
          
        case .groupSelfInfoChange:
            return GroupNotifySelfInfoChangeHandler()
            
        case .groupAddPin,
                .groupDeletePin:
            return GroupNotifyPinUpdateHandler()
                    
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
