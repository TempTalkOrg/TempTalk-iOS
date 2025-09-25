//
//  OWSMessageManager+ClientNotify.swift
//  TTServiceKit
//
//  Created by hornet on 2023/11/6.
//

import Foundation
@objc extension OWSMessageManager {
    @objc
    public func handleClientNotify(envelopeJob:OWSMessageContentJob, envelope: DSKProtoEnvelope, message: DSKProtoNotifyMessage, transaction: SDSAnyWriteTransaction) {
        //
    }
    
    ///跨端同步的mark信息
    public func processIncomingSyncMessage(topicMark: DSKProtoTopicMark, serverTimestamp: UInt64, transaction: SDSAnyWriteTransaction) {
       //
    }
    
    public func processIncomingSyncMessage(topicAction: DSKProtoTopicAction, serverTimestamp: UInt64, transaction: SDSAnyWriteTransaction) {
        //
    }
}

