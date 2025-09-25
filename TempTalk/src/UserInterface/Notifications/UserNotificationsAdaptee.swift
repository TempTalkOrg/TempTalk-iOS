//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

/**
 * TODO This is currently unused code. I started implenting new notifications as UserNotifications rather than the deprecated
 * LocalNotifications before I realized we can't mix and match. Registering notifications for one clobbers the other.
 * So, for now iOS10 continues to use LocalNotifications until we can port all the NotificationsManager stuff here.
 */
import Foundation
import UserNotifications

@available(iOS 10.0, *)
struct AppNotifications {
    enum Category {
        case missedCall,
             missedCallFromNoLongerVerifiedIdentity

        // Don't forget to update this! We use it to register categories.
        static let allValues = [ missedCall, missedCallFromNoLongerVerifiedIdentity ]
    }

    enum Action {
        case callBack,
             showThread
    }

    static var allCategories: Set<UNNotificationCategory> {
        let categories = Category.allValues.map { category($0) }
        return Set(categories)
    }

    static func category(_ type: Category) -> UNNotificationCategory {
        switch type {
        case .missedCall:
            return UNNotificationCategory(identifier: "org.difft.wea.AppNotifications.Category.missedCall",
                                          actions: [ action(.callBack) ],
                                          intentIdentifiers: [],
                                          options: [])

        case .missedCallFromNoLongerVerifiedIdentity:
            return UNNotificationCategory(identifier: "org.difft.wea.AppNotifications.Category.missedCallFromNoLongerVerifiedIdentity",
                                          actions: [ action(.showThread) ],
                                          intentIdentifiers: [],
                                          options: [])
        }
    }

    static func action(_ type: Action) -> UNNotificationAction {
        switch type {
        case .callBack:
            return UNNotificationAction(identifier: "org.difft.wea.AppNotifications.Action.callBack",
                                        title: CallStrings.callBackButtonTitle,
                                        options: .authenticationRequired)
        case .showThread:
            return UNNotificationAction(identifier: "org.difft.wea.AppNotifications.Action.showThread",
                                        title: CallStrings.showThreadButtonTitle,
                                        options: .authenticationRequired)
        }
    }
}

@available(iOS 10.0, *)
@objcMembers
public class UserNotificationsAdaptee: NSObject, UNUserNotificationCenterDelegate {
    let TAG = "[UserNotificationsAdaptee]"

    private let center: UNUserNotificationCenter

    var previewType: NotificationType {
        return Environment.shared.preferences.notificationPreviewType()
    }

    override init() {
        self.center = UNUserNotificationCenter.current()

        super.init()

        SwiftSingletons.register(self)

        center.delegate = self

        // FIXME TODO only do this after user has registered.
        // maybe the PushManager needs a reference to the NotificationsAdapter.
        requestAuthorization()

        center.setNotificationCategories(AppNotifications.allCategories)
    }

    public func requestAuthorization() {
#warning ("--- cc us暂时不支持criticalAlert ---")
        var options: UNAuthorizationOptions!
        let isWea = TSConstants.appDisplayName.lowercased().contains("cc us")
        if isWea {
            options = [.badge, .sound, .alert]
        } else {
            options = [.badge, .sound, .alert, .criticalAlert]
        }
        center.requestAuthorization(options: options) { (granted, error) in
            if granted {
                Logger.debug("\(self.TAG) \(#function) succeeded.")
            } else if error != nil {
                Logger.error("\(self.TAG) \(#function) failed with error: \(error!)")
            } else {
                Logger.error("\(self.TAG) \(#function) failed without error.")
            }
        }
    }
}
