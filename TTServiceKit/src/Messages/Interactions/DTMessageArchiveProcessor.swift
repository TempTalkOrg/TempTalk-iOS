//
//  DTConversationArchiveProcess.swift
//  TTServiceKit
//
//  Created by hornet on 2022/8/9.
//

import Foundation

/// 会话归档的处理类
@objc public class DTMessageArchiveProcessor : NSObject {
    
    /// 处理归档的同步消息
    /// - Parameters:
    ///   - archiveMessage: 归档的同步消息类型
    ///   - serverTimestamp: 服务端的同步消息的时间戳
    ///   - transaction: 事务
    @objc public class func processIncomingSyncMessage(archiveMessage : DSKProtoSyncMessageConversationArchive?,
                                                       serverTimestamp : UInt64,
                                                       transaction : SDSAnyWriteTransaction) {
        
        guard let archiveMessage = archiveMessage else {
            return
        }
        
        guard let conversation = archiveMessage.conversation, archiveMessage.hasFlag, let flag = archiveMessage.flag else {
            return
        }
        
        if conversation.hasGroupID, let groupId = conversation.groupID {
            
            guard let gThread = TSGroupThread(groupId: groupId, transaction: transaction) else {
                return
            }
            
            if flag == .archive {
                
                gThread.anyUpdate(transaction: transaction) { t in
                    t.archiveThread(with: transaction)
                }
            } else if flag == .unarchive {
                
                gThread.anyUpdate(transaction: transaction) { t in
                    t.unarchiveThread()
                }
            }
        } else if conversation.hasNumber, let receiptId = conversation.number {
            
            let cThread = TSContactThread.getOrCreateThread(withContactId: receiptId, transaction: transaction)
            
            if flag == .archive {
                
                cThread.anyUpdate(transaction: transaction) { t in
                    t.archiveThread(with: transaction)
                }
            } else if flag == .unarchive {
                
                cThread.anyUpdate(transaction: transaction) { t in
                    t.unarchiveThread()
                }
            }
        } else {
            Logger.info("Conversation Archive error")
        }
    }
    
    /// 处理消息归档的相关消息
    /// 数据结构{"notifyType":14,"notifyTime":1715671461358,"content":null,"data":{"concatNumbers":null,"gid":"4ec08895b19548f382abf918a86737dd","endTimestamp":1715671461349},"display":0}
    /// - Parameters:
    ///   - archiveMessage: 归档的同步消息类型
    ///   - transaction: 事务
    @objc public class func processNotifyArchiveMessage(archiveMessage : DTMessageArchiveEntity?,
                                                       transaction : SDSAnyWriteTransaction) {
        
        guard let archiveMessage = archiveMessage else {
            return
        }
        
        if let groupId = archiveMessage.gid,
            let localGroupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: groupId) {
            
            let group_thread_id = TSGroupThread.threadId(fromGroupId: localGroupId)
            
            if let thread_g = TSGroupThread.anyFetchGroupThread(uniqueId: group_thread_id, transaction: transaction) {
                if let threadConfig = thread_g.threadConfig {
 
                    thread_g.anyUpdateGroupThread(transaction: transaction) { g_thread in
                        
                        threadConfig.endTimestamp = archiveMessage.endTimestamp
                        g_thread.threadConfig = threadConfig
                        
                    }
                    
                } else {
                    
                    if let threadConfig = DTThreadConfigEntity.init()  {
                        
                        thread_g.anyUpdateGroupThread(transaction: transaction) { g_thread in
                            threadConfig.endTimestamp = archiveMessage.endTimestamp
                            g_thread.threadConfig = threadConfig
                            
                        }
                        
                    }
                   
                }
               
                let interactions = InteractionFinder.fetch(uniqueId: thread_g.uniqueId, beforeTimestamp: archiveMessage.endTimestamp, transaction: transaction)
                if interactions.count > 0 {
                    for interaction in interactions {
                        
                        if let interaction = interaction as? TSMessage {
                            OWSArchivedMessageJob.shared().archiveMessage(interaction, transaction: transaction)
                        } else {
                            Logger.info("interaction type error")
                        }
                    }
                }
               
            } else {
                
                ///说明没有这个会话
                guard let thread_g = TSGroupThread.init(groupId: localGroupId, transaction: transaction) else { return }
                
                if let threadConfig = DTThreadConfigEntity.init()  {
                    
                    thread_g.anyUpdateGroupThread(transaction: transaction) { g_thread in
                        threadConfig.endTimestamp = archiveMessage.endTimestamp
                        g_thread.threadConfig = threadConfig
                        
                    }
                }
                
                let interactions = InteractionFinder.fetch(uniqueId: thread_g.uniqueId, beforeTimestamp: archiveMessage.endTimestamp, transaction: transaction)
                
                if interactions.count > 0 {
                    
                    for interaction in interactions {
                        
                        if let interaction = interaction as? TSMessage {
                            OWSArchivedMessageJob.shared().archiveMessage(interaction, transaction: transaction)
                        } else {
                            Logger.info("interaction type error")
                        }
                        
                    }
                    
                }
            }
            
        } else if let concatNumbers = archiveMessage.concatNumbers,
                  let receiptIds =  splitString(input:concatNumbers, separator: ":") {
         
            if let localNum = TSAccountManager.shared.localNumber(with: transaction) {
                
                if let firstNonMatchingId = receiptIds.first(where: { $0 != localNum }) {
                    // 处理第一个与 localNum 不相等的 ID
                    Logger.info("First non-matching ID: \(firstNonMatchingId)")
                    let c_thread = TSContactThread.getOrCreateThread(withContactId: firstNonMatchingId, transaction: transaction)
                    ///查询待归档的interactions <= beforeTimestamp
                    let interactions = InteractionFinder.fetch(uniqueId: c_thread.uniqueId, beforeTimestamp: archiveMessage.endTimestamp, transaction: transaction)
                    
                    for interaction in interactions {
                        
                        if let interaction = interaction as? TSMessage {
                            OWSArchivedMessageJob.shared().archiveMessage(interaction, transaction: transaction)
                        } else {
                            Logger.info("interaction type error")
                        }
                        
                    }
                    
                } else {
                    
                    Logger.error("receiptId is error")
                    
                }
                
            } else {
                
                // 所有 ID 都与 localNum 相等
                Logger.error("receiptId is equal localNum")
                
            }

        } else {
            
            Logger.error("localNum error -> nil")
            
        }
    }
    
    class func splitString(input: String, separator: Character) -> [String]? {
        return input.split(separator: separator).map { String($0) }
    }
}
