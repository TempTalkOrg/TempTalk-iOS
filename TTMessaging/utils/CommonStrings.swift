//
//  Copyright (c) 2020 Open Whisper Systems. All rights reserved.
//

import Foundation

/**
 * Strings re-used in multiple places should be added here.
 */

@objc public class CommonStrings: NSObject {
    @objc class public func backButton() -> String {
        return Localized("BACK_BUTTON", comment: "return to the previous screen")
    }
    
    @objc class public func continueButton() -> String {
        return Localized("BUTTON_CONTINUE", comment: "Label for 'continue' button.")
    }
    
    @objc class public func dismissButton() -> String {
        return Localized("DISMISS_BUTTON_TEXT", comment: "Short text to dismiss current modal / actionsheet / screen")
    }

    @objc class public func skipButton() -> String {
        return Localized("NAVIGATION_ITEM_SKIP_BUTTON", comment: "skip button title")
    }
    
    @objc class public func cancelButton() -> String {
        return Localized("TXT_CANCEL_TITLE", comment: "Label for the cancel button in an alert or action sheet.")
    }
        
    @objc class public func doneButton() -> String {
        return Localized("BUTTON_DONE", comment: "Label for generic done button.")
    }
    
    @objc class public func okButton() -> String {
        return Localized("BUTTON_OK", comment: "Label for generic done button.")
    }
    
    @objc class public func nextButton() -> String {
        return Localized("BUTTON_NEXT", comment: "Label for the 'next' button.")
    }
    
    @objc class public func retryButton() -> String {
        return Localized("RETRY_BUTTON_TEXT", comment: "Generic text for button that retries whatever the last action was.")
    }

    @objc class public func openSettingsButton() -> String {
        return Localized("OPEN_SETTINGS_BUTTON", comment: "Button text which opens the settings app")
    }
     
    @objc class public func errorAlertTitle() -> String {
        return  Localized("ALERT_ERROR_TITLE", comment: "")
    }

}

@objc
public class CommonFormats: NSObject {
    @objc
    static public func formatUsername(_ username: String) -> String? {
        let username = username.filterForDisplay
        return Localized("USERNAME_PREFIX",
                                 comment: "A prefix appeneded to all usernames when displayed") + username
    }
}

@objc
public class MessageStrings: NSObject {

    @objc class public func conversationIsBlocked() -> String {
        return  Localized("CONTACT_CELL_IS_BLOCKED", comment: "An indicator that a contact or group has been blocked.")
    }
    
    @objc class public func newGroupDefaultTitle() -> String {
        return  Localized("NEW_GROUP_DEFAULT_TITLE", comment: "Used in place of the group name when a group has not yet been named.")
    }

    @objc class public func replyNotificationAction() -> String {
        return  Localized("PUSH_MANAGER_REPLY", comment: "Notification action button title")
    }
    
    @objc class public func markAsReadNotificationAction() -> String {
        return  Localized("PUSH_MANAGER_MARKREAD", comment: "Notification action button title")
    }
    
    @objc class public func sendButton() -> String {
        return  Localized("SEND_BUTTON_TITLE", comment: "Label for the button to send a message")
    }
    
    @objc class public func noteToSelf() -> String {
        return Localized("LOCAL_ACCOUNT_DISPLAYNAME", comment: "Label for 1:1 conversation with yourself.")
    }
    
    @objc class public func viewOnceViewPhoto() -> String {
        return  Localized("PER_MESSAGE_EXPIRATION_VIEW_PHOTO", comment: "Label for view-once messages indicating that user can tap to view the message's contents.")
    }
    
    @objc class public func viewOnceViewVideo() -> String {
        return  Localized("PER_MESSAGE_EXPIRATION_VIEW_VIDEO", comment: "Label for view-once messages indicating that user can tap to view the message's contents.")
    }
}

@objc
public class NotificationStrings: NSObject {
    
    @objc class public func failedToSendBody() -> String {
        return Localized("SEND_FAILED_NOTIFICATION_BODY", comment: "notification body")
    }
    
    @objc class public func genericIncomingMessageNotification() -> String {
        return Localized("GENERIC_INCOMING_MESSAGE_NOTIFICATION", comment: "notification body")
    }
}

@objc public class CallStrings: NSObject {
    
    static public var showThreadButtonTitle: String {
        Localized("SHOW_THREAD_BUTTON_TITLE", comment: "notification action")
    }
    
    static public var answerCallButtonTitle: String {
        Localized("ANSWER_CALL_BUTTON_TITLE", comment: "notification action")
    }
    
    static public var callBackButtonTitle: String {
        Localized("CALLBACK_BUTTON_TITLE", comment: "notification action")
    }

}

@objc public class MediaStrings: NSObject {
    @objc class public func allMedia() -> String {
        return Localized("MEDIA_DETAIL_VIEW_ALL_MEDIA_BUTTON", comment: "nav bar button item")
    }
}

@objc public class SafetyNumberStrings: NSObject {
    @objc class public func confirmSendButton() -> String {
        return Localized("SAFETY_NUMBER_CHANGED_CONFIRM_SEND_ACTION",
                         comment: "button title to confirm sending to a recipient whose safety number recently changed")
    }
}

