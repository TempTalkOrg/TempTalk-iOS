//
//  DataUpdateUtil.swift
//  Pods
//
//  Created by Henry on 2025/8/10.
//

@objcMembers
public class DataUpdateUtil: NSObject {
    @objc public static let shared = DataUpdateUtil()
    
    private override init() {
        super.init()
    }
    
    @objc public func updateConversation(thread: TSThread, expireTime: NSNumber?, messageClearAnchor: NSNumber?) {
        Logger.info("[update transation] show threadId \(thread.uniqueId)")
        
        if let localNumber = TSAccountManager.localNumber() {
            let currentThreadId = TSContactThread.threadId(fromContactId: localNumber)
            if currentThreadId == thread.uniqueId, thread.expiresInSeconds == 0 {
                // 加一个保护，备忘录不会修改值, 如果之前有改动，也可通过这个进行纠正
                Logger.info("[update transation] current thread \(thread.uniqueId) is local")
                return
            }
        }
        
        if let expiry = expireTime, DTParamsUtils.validateNumber(expiry).boolValue, expiry.intValue > 0 {
            Logger.info("[update transation] save expiry time \(expiry.uint64Value)")
            thread.expiresInSeconds = expiry.uint64Value
        } else {
            Logger.info("[update transation] save expiry time default config \(UInt64(thread.messageExpiresInSeconds()))")
            thread.expiresInSeconds = UInt64(thread.messageExpiresInSeconds())
        }

        if let anchor = messageClearAnchor, DTParamsUtils.validateNumber(anchor).boolValue,  anchor.intValue > 0 {
            Logger.info("[update transation] save messageClearAnchor time \(anchor.uint64Value)")
            thread.messageClearAnchor = anchor.uint64Value
        }

        OWSArchivedMessageJob.shared().fallbackTimerDidFire();
    }
    
    @objc public func updateConversation(baseInfo: DTGroupBaseInfoEntity, thread: TSThread, expireTime: NSNumber?, messageClearAnchor: NSNumber?) {
        Logger.info("[update transation] show baseInfo threadId \(thread.uniqueId)")
        if let expiry = expireTime, DTParamsUtils.validateNumber(expiry).boolValue, expiry.intValue > 0 {
            Logger.info("[update transation] save baseInfo expiry time \(expiry.uint64Value)")
            baseInfo.messageExpiry = expiry
        } else {
            Logger.info("[update transation] save baseInfo default config \(thread.messageExpiresInSeconds())")
            baseInfo.messageExpiry = NSNumber(value: thread.messageExpiresInSeconds())
        }

        if let anchor = messageClearAnchor, DTParamsUtils.validateNumber(anchor).boolValue,  anchor.intValue > 0 {
            Logger.info("[update transation] save baseInfo messageClearAnchor time \(anchor.uint64Value)")
            baseInfo.messageClearAnchor = anchor.uint64Value
        }
    }
}
