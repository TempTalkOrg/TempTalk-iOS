//
//  GroupNotifyMemberInfoUpdateHander.swift
//  TTServiceKit
//
//  Created by user on 2024/7/22.
//

import Foundation
//groupSelfInfoChange

class GroupNotifySelfInfoChangeHandler : GroupNotifyHandler {
    
    private let getPersonalConfigAPI = DTGetGroupPersonalConfigAPI.init()
    
    func handle(envelope: DSKProtoEnvelope,
                groupNotifyEntity: DTGroupNotifyEntity,
                display: Bool,
                oldGroupModel: TSGroupModel,
                newGroupModel: TSGroupModel, 
                newGroupThread: TSGroupThread,
                timeStamp: UInt64,
                transaction: SDSAnyWriteTransaction) {
        
        if groupNotifyEntity.groupNotifyDetailedType == .groupSelfInfoChange {
            
            updateGroupSelfInfoChange(envelope: envelope,
                                      groupNotifyEntity: groupNotifyEntity,
                                      display: display,
                                      oldGroupModel: oldGroupModel,
                                      newGroupModel: newGroupModel,
                                      newGroupThread: newGroupThread,
                                      timeStamp: timeStamp,
                                      transaction: transaction
            )
            
        }
        
    }
    
    func updateGroupSelfInfoChange(envelope: DSKProtoEnvelope,
                                   groupNotifyEntity: DTGroupNotifyEntity,
                                   display: Bool,
                                   oldGroupModel: TSGroupModel,
                                   newGroupModel: TSGroupModel,
                                   newGroupThread: TSGroupThread,
                                   timeStamp: UInt64,
                                   transaction: SDSAnyWriteTransaction) {
        
        self.getPersonalConfigAPI.sendRequestWith(withGroupId: groupNotifyEntity.gid) { entity in
            
            DispatchQueue(label: "org.difft.selfInfo.GroupNotifySelfInfoChangeHandler").async {
                
                NSObject.databaseStorage.asyncWrite { writeTransaction in
                    
                    guard let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: groupNotifyEntity.gid) else { return }
                    
                    let newGroupThread = TSGroupThread.getOrCreateThread(withGroupId: groupId, transaction: writeTransaction)
                    newGroupThread.anyUpdateGroupThread(transaction: transaction) { thread in
                        thread.groupModel.notificationType = NSNumber(value: entity.notification.rawValue)
                        thread.groupModel.useGlobal = entity.useGlobal
                    }
                    
                    writeTransaction.addAsyncCompletionOnMain {
                        NotificationCenter.default.post(name: NSNotification.Name("DTPersonalGroupConfigChangedNotification"), object: nil)
                    }

                }
            }
            
        } failure: { error in
            Logger.info("error: \(error.localizedDescription)")
        }
    }
    
    
}
