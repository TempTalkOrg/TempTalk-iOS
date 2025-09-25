//
//  GroupNotifyContext.swift
//  TTServiceKit
//
//  Created by user on 2024/7/22.
//

import Foundation

class GroupNotifyContext {
    private var handler: GroupNotifyHandler

    init(handler: GroupNotifyHandler) {
        self.handler = handler
    }

    func executeStrategy(envelope: DSKProtoEnvelope,
                         groupNotifyEntity: DTGroupNotifyEntity,
                         display: Bool,
                         oldGroupModel: TSGroupModel,
                         newGroupModel: TSGroupModel,
                         newGroupThread: TSGroupThread,
                         timeStamp: UInt64,
                         transaction: SDSAnyWriteTransaction) {
        // 可以在这里添加额外的逻辑，例如日志记录、异常处理等
        return handler.handle(envelope: envelope,
                              groupNotifyEntity: groupNotifyEntity,
                              display: display,
                              oldGroupModel: oldGroupModel,
                              newGroupModel: newGroupModel, 
                              newGroupThread: newGroupThread,
                              timeStamp: timeStamp,
                              transaction: transaction)
    }
}
