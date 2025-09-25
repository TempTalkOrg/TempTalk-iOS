//
//  GroupNotifyAnnouncementHander.swift
//  TTServiceKit
//
//  Created by user on 2024/7/22.
//

import Foundation

class GroupNotifyAnnouncementHandler : GroupNotifyHandler {
    
    func handle(envelope: DSKProtoEnvelope, 
                groupNotifyEntity: DTGroupNotifyEntity,
                display: Bool,
                oldGroupModel: TSGroupModel,
                newGroupModel: TSGroupModel,
                newGroupThread: TSGroupThread,
                timeStamp: UInt64,
                transaction: SDSAnyWriteTransaction) {
        ///目前看原来的代码这一块是没做任何处理的
        if groupNotifyEntity.groupNotifyDetailedType == .groupAddAnnnouncement {
            
           
        } else if groupNotifyEntity.groupNotifyDetailedType == .groupUpdateAnnnouncement {
            
            
        } else if groupNotifyEntity.groupNotifyDetailedType == .groupDeleteAnnnouncement {
            
           
        } else {
            
            Logger.info("unsupported type")
            
        }
        
    }
    
}
