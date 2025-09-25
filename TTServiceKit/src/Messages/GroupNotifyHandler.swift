//
//  GroupNotifyHandler.swift
//  TTServiceKit
//
//  Created by user on 2024/7/22.
//

import Foundation

@objc public protocol GroupNotifyHandler {
    
    func handle(envelope: DSKProtoEnvelope,
                groupNotifyEntity: DTGroupNotifyEntity,
                display: Bool,
                oldGroupModel: TSGroupModel,
                newGroupModel: TSGroupModel,
                newGroupThread: TSGroupThread,
                timeStamp: UInt64,
                transaction: SDSAnyWriteTransaction)
    
}

@objc public protocol GroupNotifyDonotTrackHandler {
    
    static func handleDonotTrackVersio(envelope: DSKProtoEnvelope,
                          groupNotifyEntity: DTGroupNotifyEntity,
                          oldGroupModel: TSGroupModel,
                          newGroupThread: TSGroupThread,
                          transaction: SDSAnyWriteTransaction)
    
    static func isNeedTrackVersion(groupNotifyEntity: DTGroupNotifyEntity) -> Bool
    
}
