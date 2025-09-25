//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import TTServiceKit

@objc
public class NoopNotificationsManager: NSObject, NotificationsProtocol {

    public func notifyUser(for incomingMessage: TSIncomingMessage, in thread: TSThread, transaction: TTServiceKit.SDSAnyWriteTransaction) {
        owsFailDebug("\(self.logTag) in \(#function).")
    }
    

    public func notifyUser(for incomingMessage: TSIncomingMessage, in thread: TSThread, contactsManager: ContactsManagerProtocol, transaction: SDSAnyReadTransaction) {
        owsFailDebug("\(self.logTag) in \(#function).")
    }

    public func notifyUser(for error: TSErrorMessage, thread: TSThread, transaction: SDSAnyWriteTransaction) {
        Logger.warn("\(self.logTag) in \(#function), skipping notification for: \(error.description)")
    }

    public func notifyUser(forThreadlessErrorMessage error: TSErrorMessage, transaction: SDSAnyWriteTransaction) {
        Logger.warn("\(self.logTag) in \(#function), skipping notification for: \(error.description)")
    }
    
    public func clearAllNotifications(except categoryIdentifiers: [String]?) {
        
        Logger.warn("\(self.logTag) in \(#function), skipping notification")
    }
    
    public func syncApnSoundIfNeeded() {
        Logger.warn("\(self.logTag) in \(#function), skipping syncApnSound")
    }
    
    public func notifyForScheduleMeeting(withTitle title: String?, body: String, userInfo: [AnyHashable : Any] = [:], replacingIdentifier: String?, triggerTimeInterval: TimeInterval) async throws {
        Logger.warn("\(self.logTag) in \(#function), schedule meeting")
    }
}
