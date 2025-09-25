//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation

@objc
public class ThreadViewModel: NSObject {
    @objc public let hasUnreadMessages: Bool
    @objc public let lastMessageDate: Date?
    @objc public let isGroupThread: Bool
    @objc public let threadRecord: TSThread
    @objc public let unreadCount: UInt
    @objc public let contactIdentifier: String?
    @objc public let name: String
    @objc public let isMuted: Bool
    @objc public let isSticked: Bool
    @objc public let isCallingSticked: Bool
    
    var isContactThread: Bool {
        return !isGroupThread
    }

    @objc public let lastMessageText: String?
    @objc public let atPersons: String?
//    @objc public let lastMessageForInbox: TSInteraction?

    @objc
    public init(thread: TSThread, transaction: SDSAnyReadTransaction? = nil) {
        self.threadRecord = thread
        self.lastMessageDate = thread.lastMessageDate
        self.isGroupThread = thread.isGroupThread()
        self.name = thread.name(with: transaction)
        self.isMuted = thread.isMuted
        self.isSticked = thread.isSticked
        self.isCallingSticked = thread.isCallingSticked
        self.lastMessageText = thread.lastMessageText(transaction: transaction)
        self.atPersons = thread.atPersons(transaction: transaction);
//        self.lastMessageForInbox = thread.lastInteractionForInbox(transaction: transaction)

        if let contactThread = thread as? TSContactThread {
            self.contactIdentifier = contactThread.contactIdentifier()
        } else {
            self.contactIdentifier = nil
        }

//        thread.updateUnreadMessageCount(with: transaction)
        self.unreadCount = thread.unreadMessageCount
        self.hasUnreadMessages = unreadCount > 0
    }

    @objc
    override public func isEqual(_ object: Any?) -> Bool {
        guard let otherThread = object as? ThreadViewModel else {
            return super.isEqual(object)
        }

        return threadRecord.isEqual(otherThread.threadRecord)
    }
}
