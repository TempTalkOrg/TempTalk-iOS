//
//  DTConversactionSettingUtils.swift
//  Signal
//
//  Created by Kris.s on 2024/9/5.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

@objc
public class DTConversactionSettingUtils: NSObject {
    
    @objc
    public class func msgDisappearingTips(messageExpiry: TimeInterval) -> String {
        let dayNum = Int(messageExpiry/kDayInterval)
        let hourNum = Int(messageExpiry/kHourInterval)
        let minuteNum = Int(messageExpiry/kMinuteInterval)
        var tips = ""
        if messageExpiry > 0 {
            if dayNum > 0 {
                tips = "\(dayNum)" + Localized("CONVERSATION_SETTINGS_ARCHIVE_DAY")
            } else if dayNum == 0 && hourNum > 0 {
                tips = "\(hourNum)" + Localized("CONVERSATION_SETTINGS_ARCHIVE_HOUR")
            } else if dayNum == 0 && hourNum == 0 && minuteNum > 0 {
                tips = "\(minuteNum)" + Localized("CONVERSATION_SETTINGS_ARCHIVE_MINUTER")
            }
        } else {
            tips = Localized("CONVERSATION_SETTINGS_NEVER_ARCHIVE")
        }
        
        return tips
        
    }
    
    @objc
    public class func msgDisappearingTipsOnThread(messageExpiry: TimeInterval, threadName: NSAttributedString, font: UIFont) -> NSAttributedString? {
        var msgDisappearingTips = msgDisappearingTips(messageExpiry: messageExpiry)
        if !msgDisappearingTips.isEmpty {
            msgDisappearingTips = " [\(msgDisappearingTips)]"
            return threadName.stringByAppendingString(msgDisappearingTips, attributes: [.foregroundColor: Theme.ternaryTextColor,
                                                                         .font: font])
        }
        return nil
    }
}
