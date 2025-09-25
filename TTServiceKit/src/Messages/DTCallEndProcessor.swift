//
//  DTCallEndProcessor.swift
//  TTServiceKit
//
//  Created by Ethan on 2022/7/6.
//

import Foundation

open class DTCallEndProcessor: NSObject {
    
    @objc public class func sendCallEndInfoMessage(thread: TSThread,
                                                   duration: String,
                                                   serverTimestamp: UInt64,
                                                   transaction: SDSAnyWriteTransaction) {
        
        let now = NSDate.ows_millisecondTimeStamp()
        let customMessage = callEndFeedbackAttributeString(duration: duration)
        let infoMessage = TSInfoMessage(actionInfoMessageWith: .callEnd, timestamp: now, serverTimestamp:serverTimestamp, in: thread, customMessage: customMessage)
        infoMessage.anyInsert(transaction: transaction)
    }

    // 使用时增加 serverTimestamp
    @objc public class func sendMeetingMemberJoinInfoMessage(thread: TSThread,
                                                             event: String,
                                                             timestamp: TimeInterval,
                                                             receiptId: String,
                                                             transaction: SDSAnyWriteTransaction) {
        
        guard let localNumber = self.tsAccountManager.localNumber() else {
            Logger.error("no localNumber")
            return
        }
        
        var date = Date()
        if timestamp > 0 {
            date = Date(millisecondsSince1970: UInt64(timestamp/1000))
        }
        
        let dateformatter = DateFormatter()
        dateformatter.dateFormat = "HH:mm:ss"
        let timeString = dateformatter.string(from: date)
            
        var name: String
        if receiptId == localNumber {
            name = Localized("YOU", comment: "local number")
        } else {
            let contactsManager = TextSecureKitEnv.shared().contactsManager
            name = contactsManager.displayName(forPhoneIdentifier: receiptId, transaction: transaction)
        }
        
        var joinOrLeft: String?
        if event == "join" {
            joinOrLeft = Localized("MEETING_MEMBER_JOIN_INFO_MESSAGE", comment: "MEMBER JOIN INFO MESSAGE")
        } else if event == "leave" {
            joinOrLeft = Localized("MEETING_MEMBER_LEFT_INFO_MESSAGE", comment: "MEMBER LEFT INFO MESSAGE")
        }
        
        guard let joinOrLeft = joinOrLeft else { return }
        
        let customMessage = NSAttributedString(string: "\(name)\(joinOrLeft)\(timeString)")
        let now = NSDate.ows_millisecondTimeStamp()
        
        let infoMessage = TSInfoMessage(actionInfoMessageWith: .callEnd, timestamp: now, serverTimestamp: 0, in: thread, customMessage: customMessage)
        infoMessage.anyInsert(transaction: transaction)
    }
    
    private class func callEndFeedbackAttributeString(duration: String) -> NSAttributedString {
        //Meeting ended 16m 15s. Please click here to share your feedback about the meeting.
        let prefix = "Meeting ended" + duration + ". Please"
        let middle = " click here "
        let suffix = "to share your feedback about the meeting."

        let attrtbuteText = NSMutableAttributedString(string: prefix + middle + suffix)
        attrtbuteText.addAttribute(.foregroundColor, value: UIColor(red: 76.0/255, green: 97.0/255, blue: 140.0/255, alpha: 1.0), range: NSRange(location: prefix.count, length: middle.count))
        
        return attrtbuteText.copy() as! NSAttributedString
    }
    
}
