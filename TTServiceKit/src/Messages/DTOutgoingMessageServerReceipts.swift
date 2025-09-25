//
//  DTOutgoingMessageServerReceipts.swift
//  TTServiceKit
//
//  Created by Felix on 2022/6/25.
//

import Foundation

@objc open class DTOutgoingMessageServerReceipts : NSObject {
    
    @objc public let needsSync: Bool
    @objc public let sequenceId: UInt64
    @objc public let systemShowTimestamp: TimeInterval
    @objc public let notifySequenceId: UInt64
    
    @objc public init(response: NSDictionary?) {
        self.needsSync = response?["needsSync"] as? Bool ?? false
        self.sequenceId = response?["sequenceId"] as? UInt64 ?? 0
        self.systemShowTimestamp = response?["systemShowTimestamp"] as? TimeInterval ?? 0
        self.notifySequenceId = response?["notifySequenceId"] as? UInt64 ?? 0
        
        super.init()
    }
    
    @objc public init(needsSync: Bool = false, sequenceId: UInt64 = 0, systemShowTimestamp: TimeInterval, notifySequenceId: UInt64 = 0) {
        self.needsSync = needsSync
        self.sequenceId = sequenceId
        self.systemShowTimestamp = systemShowTimestamp
        self.notifySequenceId = notifySequenceId
        
        super.init()
    }
}
