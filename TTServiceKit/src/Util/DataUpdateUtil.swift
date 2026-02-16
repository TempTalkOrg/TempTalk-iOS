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

        if let localNumber = TSAccountManager.localNumber() {
            let currentThreadId = TSContactThread.threadId(fromContactId: localNumber)
            if currentThreadId == thread.uniqueId, thread.expiresInSeconds == 0 {
                return
            }
        }

        if let expiry = expireTime, DTParamsUtils.validateNumber(expiry).boolValue, expiry.intValue > 0 {
            thread.expiresInSeconds = expiry.uint64Value
        } else {
            thread.expiresInSeconds = UInt64(thread.messageExpiresInSeconds())
        }

        if let anchor = messageClearAnchor, DTParamsUtils.validateNumber(anchor).boolValue, anchor.intValue > 0 {
            thread.messageClearAnchor = anchor.uint64Value
        }
    }

    @objc public func updateConversation(baseInfo: DTGroupBaseInfoEntity, thread: TSThread, expireTime: NSNumber?, messageClearAnchor: NSNumber?) {
        if let expiry = expireTime, DTParamsUtils.validateNumber(expiry).boolValue, expiry.intValue > 0 {
            baseInfo.messageExpiry = expiry
        } else {
            baseInfo.messageExpiry = NSNumber(value: thread.messageExpiresInSeconds())
        }

        if let anchor = messageClearAnchor, DTParamsUtils.validateNumber(anchor).boolValue, anchor.intValue > 0 {
            baseInfo.messageClearAnchor = anchor.uint64Value
        }
    }
}
