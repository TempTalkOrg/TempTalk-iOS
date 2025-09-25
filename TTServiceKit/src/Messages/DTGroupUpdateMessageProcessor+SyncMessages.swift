//
//  DTGroupUpdateNotifyProcessor.swift
//  TTServiceKit
//
//  Created by user on 2024/7/18.
//

import Foundation

extension DTGroupUpdateMessageProcessor {
    
    @objc public func handleSyncGroupUpdateMessage(groupNotifyEntity: DTGroupNotifyEntity,
                                                       oldGroupModel: TSGroupModel,
                                                         localNumber: String,
                                                      newGroupThread: TSGroupThread,
                                                         transaction: SDSAnyWriteTransaction) {
        
        if groupNotifyEntity.source == localNumber 
            && groupNotifyEntity.sourceDeviceId == OWSDevice.currentDeviceId() {
            
            let newGroupModel = DTGroupUtils.createNewGroupModel(with: oldGroupModel)
            newGroupModel.version = groupNotifyEntity.groupVersion
            
            if let group = groupNotifyEntity.group, 
                (groupNotifyEntity.groupNotifyDetailedType == .groupExtChange || groupNotifyEntity.groupNotifyType == .memberChanged) {
                
                let ext = group.ext
                if oldGroupModel.isExt != ext {
                    newGroupModel.isExt = ext
                    
                    transaction.addAsyncCompletionOffMain {
                        DTGroupUtils.postExternalChangeNotification(withTargetIds: [newGroupThread.uniqueId : NSNumber(value: ext)])
                    }
                }
                
                if let messageExpiry = group.messageExpiry {
                    newGroupModel.messageExpiry = messageExpiry
                }
            }
            
            newGroupThread.anyUpdateGroupThread(transaction: transaction) { instance in
                instance.groupModel = newGroupModel
            }
            
            let timestamp = Date.ows_millisecondTimestamp()
            self.handleGroupMessageArchiveChanged(oldGroupModel: oldGroupModel, newGroupModel: newGroupModel, newGroupThread: newGroupThread, timestamp: timestamp, transaction: transaction)
            
            // drop
            return
        }

   }
    
}
