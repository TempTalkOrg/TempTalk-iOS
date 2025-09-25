//
//  DTConversationUpdateMessageProcessor.swift
//  TTServiceKit
//
//  Created by hornet on 2022/11/9.
//

import Foundation
@objc
public extension DTConversationUpdateMessageProcessor {
    @objc
    func handleConversationSharingConfiguration(_ envelope: DSKProtoEnvelope, display: Bool, conversationNotifyEntity: DTThreadConfigEntity, transaction: SDSAnyWriteTransaction ) {
        let localNumber = TSAccountManager.sharedInstance().localNumber()
        Logger.info("handleConversationSharingConfiguration  receptid = \(conversationNotifyEntity.source)")
        if(conversationNotifyEntity.source == localNumber && conversationNotifyEntity.sourceDeviceId == OWSDevice.currentDeviceId()){
            return
        }
        ///更新消息的过期时间
        if(conversationNotifyEntity.changeType == 1){
            let conversationId = conversationNotifyEntity.source
            var contactThread : TSContactThread?
            if(conversationId.stripped == localNumber?.stripped){///表示的是同一个账号的不同设备的消息同步
                contactThread = TSContactThread.getOrCreateThread(withContactId: conversationNotifyEntity.conversation, transaction: transaction)
            } else {
                contactThread = TSContactThread.getOrCreateThread(withContactId: conversationId, transaction: transaction)
            }
            guard let contactThread = contactThread else {
                Logger.error("contactThread 异常")
                return
            }
            
            if let sharingConfiguration = contactThread.threadConfig, sharingConfiguration.ver - conversationNotifyEntity.ver > 0 {
                return
            } else if let sharingConfiguration = contactThread.threadConfig, conversationNotifyEntity.ver - sharingConfiguration.ver  > 1 {//跨版本
                self.requestConversationSharingConfigurationId(conversationId: contactThread.contactIdentifier())
            } else {
                if(contactThread.threadConfig == nil && conversationNotifyEntity.ver > 1){
                    self.requestConversationSharingConfigurationId(conversationId: contactThread.contactIdentifier())
                } else {
                    self.saveConversationSharingConfiguration(thread: contactThread, conversationNotifyEntity: conversationNotifyEntity, transaction:transaction)
                }
            }
        } else {
            Logger.error("DTConversationUpdateMessageProcessor unknow change type changeType = \(conversationNotifyEntity.changeType)" )
        }
    }
    
    func saveConversationSharingConfiguration(thread: TSContactThread, conversationNotifyEntity: DTThreadConfigEntity, transaction: SDSAnyWriteTransaction) {
        Logger.info("DTConversationUpdateMessageProcessor saveConversationSharingConfiguration  receptid = \(thread.contactIdentifier()) \(conversationNotifyEntity.messageExpiry)")
        
        thread.threadConfig = conversationNotifyEntity
        
        // 全量更新 contact notify
        DataUpdateUtil.shared.updateConversation(thread: thread,
                                                 expireTime: conversationNotifyEntity.messageExpiry,
                                                 messageClearAnchor: NSNumber(value: conversationNotifyEntity.messageClearAnchor))
        thread.anyUpsert(transaction: transaction)
        
        transaction.addAsyncCompletionOnMain({
            NotificationCenter.default.post(Notification(name: Notification.Name("kDTconversationSharingConfigurationChangeNotification")))
        })
    }
    
    func requestConversationSharingConfigurationId(conversationId : String) {
        self.fetchThreadConfigAPI.fetchThreadConfigRequest(withNumber: conversationId) { threadConfigEntity in
            guard let threadConfigEntity, let conversation = threadConfigEntity.conversation as String? else { return  }
            self.databaseStorage.asyncWrite { transaction in
                let contactThread = TSContactThread.getOrCreateThread(withContactId: conversation, transaction: transaction)
                self.saveConversationSharingConfiguration(thread: contactThread, conversationNotifyEntity: threadConfigEntity, transaction: transaction)
            }
        } failure: { error in
            let errorMessage: String = error.userErrorDescription
            Logger.info("requestConversationSharingConfigurationId errorMessage: \(errorMessage)")
        }
    }
}
