//
//  AppDelegate.swift
//  Signal
//
//  Created by Kris.s on 2022/10/1.
//  Copyright © 2022 Difft. All rights reserved.
//

import Foundation
import UserNotifications
import Mantle
import TTServiceKit

@objc
enum LaunchFailure: UInt, CustomStringConvertible {
    case none
    case couldNotLoadDatabase
    case unknownDatabaseVersion
    case couldNotRestoreTransferredData
    case databaseUnrecoverablyCorrupted
    case lastAppLaunchCrashed
    case lowStorageSpaceAvailable

    public var description: String {
        switch self {
        case .none:
            return "LaunchFailure_None"
        case .couldNotLoadDatabase:
            return "LaunchFailure_CouldNotLoadDatabase"
        case .unknownDatabaseVersion:
            return "LaunchFailure_UnknownDatabaseVersion"
        case .couldNotRestoreTransferredData:
            return "LaunchFailure_CouldNotRestoreTransferredData"
        case .databaseUnrecoverablyCorrupted:
            return "LaunchFailure_DatabaseUnrecoverablyCorrupted"
        case .lastAppLaunchCrashed:
            return "LaunchFailure_LastAppLaunchCrashed"
        case .lowStorageSpaceAvailable:
            return "LaunchFailure_NoDiskSpaceAvailable"
        }
    }
}


extension AppDelegate  {
    @objc(checkSomeDiskSpaceAvailable)
    func checkSomeDiskSpaceAvailable() -> Bool {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .path
        let succeededCreatingDir = OWSFileSystem.ensureDirectoryExists(tempDir)

        // Best effort at deleting temp dir, which shouldn't ever fail
        if succeededCreatingDir && !OWSFileSystem.deleteFile(tempDir) {
            owsFailDebug("Failed to delete temp dir used for checking disk space!")
        }

        return succeededCreatingDir
    }
    
    @objc
    public func initializeMeetingManager() {
        let _ = DTMeetingManager.shared
    }
}

extension AppDelegate {
    
    /// The user must unlock the device once after reboot before the database encryption key can be accessed.
    @objc func verifyDBKeysAvailableBeforeBackgroundLaunch() {
        guard UIApplication.shared.applicationState == .background else {
            return
        }
        if StorageCoordinator.hasGrdbFile && GRDBDatabaseStorageAdapter.isKeyAccessible {
            return 
        }

        Logger.warn("Exiting because we are in the background and the database password is not accessible.")

        let notificationContent = UNMutableNotificationContent()
        notificationContent.body = String (
            format: OWSLocalizedString (
                "NOTIFICATION_BODY_PHONE_LOCKED_FORMAT",
                comment: "Lock screen notification text presented after user powers on their device without unlocking. Embeds {{device model}} (either 'iPad' or 'iPhone')"
            ),
            UIDevice.current.localizedModel
        )

        let notificationRequest = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: notificationContent,
            trigger: nil
        )

        let application: UIApplication = .shared
        let userNotificationCenter: UNUserNotificationCenter = .current()

        userNotificationCenter.removeAllPendingNotificationRequests()
        application.applicationIconBadgeNumber = 0

        userNotificationCenter.add(notificationRequest)
        application.applicationIconBadgeNumber = 1

        // Wait a few seconds for XPC calls to finish and for rate limiting purposes.
        Thread.sleep(forTimeInterval: 3)
        Logger.flush()
        exit(0)
    }
    
    @objc func clearAllNotificationsAndRestoreBadgeCount() {
        AssertIsOnMainThread()

        AppReadiness.runNowOrWhenAppDidBecomeReadySync {
            let oldBadgeValue = UIApplication.shared.applicationIconBadgeNumber
            let ignoreCategory = [AppNotificationCategory.scheduleMeetingWithoutActions.identifier]
            AppEnvironment.shared.notificationPresenter.clearAllNotifications(except: ignoreCategory)
            UIApplication.shared.applicationIconBadgeNumber = oldBadgeValue
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
        
    @objc
    func addLocalNotificationDelegate() {
        let center =  UNUserNotificationCenter.current()
        AppEnvironment.shared.notificationPresenterRef.registerNotificationSettings().asPromise().observe { result in
            switch result {
            case .success:
                Logger.info("localNotification register sucess.")
            case .failure(_):
                Logger.info("localNotification register fail.")
            }
        }
       
        center.delegate = self
    }
    
    // 处理通知
    // TODO:  应用在前台的时候才会调用这个方法，目前仅有meeting在使用本地通知，如果增加其他类型需要做区分
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    
        let userInfo = notification.request.content.userInfo
        guard !userInfo.isEmpty else {
            Logger.error("\(logTag) userInfo is empty.")
            return
        }
        
        let categoryIdentifier = notification.request.content.categoryIdentifier
        guard categoryIdentifier == AppNotificationCategory.scheduleMeetingWithoutActions.identifier else {
            Logger.info("\(logTag) categoryIdentifier not schedule meeting.")
            return
        }
        
        do {
            let event = try MTLJSONAdapter.model(of: DTListMeeting.self, fromJSONDictionary: userInfo) as! DTListMeeting
            if UIApplication.shared.applicationState == .active {
                var alertType: DTAlertCallType!
                // TODO：预约会议相关DTListMeeting
            } else {
                NotificationActionHandler.presentEventDetail(event)
            }
        } catch {
            Logger.error("\(logTag) dictionary converting to event: \(error)")
        }

    }
    
    // The method will be called on the delegate when the user responded to the notification by opening the application,
    // dismissing the notification or choosing a UNNotificationAction. The delegate must be set before the application
    // returns from application:didFinishLaunchingWithOptions:.
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Logger.info("")
        AppReadiness.runNowOrWhenAppDidBecomeReadySync {
            NotificationActionHandler.handleNotificationResponse(response, completionHandler: completionHandler)
        }
    }
}


//AppLink
extension AppDelegate  {
    
    @objc
    func handleUniversalLink(url: URL) -> Bool {
        return AppLinkManager.handle(url: url, fromExternal: true)
    }
    
    @objc
    func handleCustomSchemes(url: URL) -> Bool {
        return AppLinkManager.handle(url: url, fromExternal: true)
    }
    
}
