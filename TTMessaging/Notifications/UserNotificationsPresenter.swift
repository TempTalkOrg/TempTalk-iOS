//
//  UserNotificationsPresenter.swift
//  TTMessaging
//
//  Created by hornet on 2023/8/16.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
import UserNotifications
import Intents
import TTServiceKit

public class UserNotificationConfig {

    class var allNotificationCategories: Set<UNNotificationCategory> {
        let categories = AppNotificationCategory.allCases.map { notificationCategory($0) }
        return Set(categories)
    }
    
    class func notificationActions(for category: AppNotificationCategory) -> [UNNotificationAction] {
        return category.actions.compactMap { notificationAction($0) }
    }
    
    class func notificationCategory(_ category: AppNotificationCategory) -> UNNotificationCategory {
        return UNNotificationCategory(identifier: category.identifier,
                                      actions: notificationActions(for: category),
                                      intentIdentifiers: [],
                                      options: [])
    }

    
    class func notificationAction(_ action: AppNotificationAction) -> UNNotificationAction? {

        switch action {
        case .reply:
            return textInputNotificationActionWithIdentifier(action.identifier,
                                                             title: MessageStrings.replyNotificationAction(),
                                                             options: [],
                                                             textInputButtonTitle: MessageStrings.sendButton(),
                                                             textInputPlaceholder: "",
                                                             systemImage: "arrowshape.turn.up.left")
        case .showThread:
            return notificationActionWithIdentifier(action.identifier,
                                                    title: CallStrings.showThreadButtonTitle,
                                                    options: [],
                                                    systemImage: "bubble.left.and.bubble.right")
        case .showScheduledMeetingInfo:
            return notificationActionWithIdentifier(action.identifier,
                                                    title: CallStrings.answerCallButtonTitle,
                                                    options: [],
                                                    systemImage: "phone")
        }
    }

    private class func notificationActionWithIdentifier(
        _ identifier: String,
        title: String,
        options: UNNotificationActionOptions,
        systemImage: String?) -> UNNotificationAction {
        if #available(iOS 15, *), let systemImage = systemImage {
            let actionIcon = UNNotificationActionIcon(systemImageName: systemImage)
            return UNNotificationAction(identifier: identifier,
                                        title: title,
                                        options: options,
                                        icon: actionIcon)
        } else {
            return UNNotificationAction(identifier: identifier,
                                        title: title,
                                        options: options)
        }
    }

    private class func textInputNotificationActionWithIdentifier(
        _ identifier: String,
        title: String,
        options: UNNotificationActionOptions,
        textInputButtonTitle: String,
        textInputPlaceholder: String,
        systemImage: String?) -> UNNotificationAction {
        if #available(iOS 15, *), let systemImage = systemImage {
            let actionIcon = UNNotificationActionIcon(systemImageName: systemImage)
            return UNTextInputNotificationAction(identifier: identifier,
                                                 title: title,
                                                 options: options,
                                                 icon: actionIcon,
                                                 textInputButtonTitle: textInputButtonTitle,
                                                 textInputPlaceholder: textInputPlaceholder)
        } else {
            return UNTextInputNotificationAction(identifier: identifier,
                                                 title: title,
                                                 options: options,
                                                 textInputButtonTitle: textInputButtonTitle,
                                                 textInputPlaceholder: textInputPlaceholder)
        }
    }

    public class func action(identifier: String) -> AppNotificationAction? {
        return AppNotificationAction.allCases.first { notificationAction($0)?.identifier == identifier }
    }

}


fileprivate let notificationErrorDomain = "com.difft.notification"
enum NotificationErrorCode: Int {
    case onboardingIncomplete = 1
    case failedToDonateIncomingMessage = 2
    case failedToUpdateNotificationContent = 3
    case failedToPresentingNotification = 4
   
    // 可以添加更多的错误代码
    
    var description: String {
        switch self {
        case .onboardingIncomplete:
            return "Suppressing notification since user hasn't yet completed onboarding."
        case .failedToDonateIncomingMessage:
            return "Failed to donate incoming message intent."
        case .failedToUpdateNotificationContent:
            return "Failed to update UNNotificationContent for comm style notification."
        case .failedToPresentingNotification:
            return "Failed to present notification."
        }
    }
}


class UserNotificationPresenter: Dependencies {
    typealias NotificationActionCompletion = (_ error: Error?) -> Void
    typealias NotificationReplaceCompletion = (Bool) -> Void

    private static var notificationCenter: UNUserNotificationCenter { UNUserNotificationCenter.current() }

    // Delay notification of incoming messages when it's likely to be read by a linked device to
    // avoid notifying a user on their phone while a conversation is actively happening on desktop.
    let kNotificationDelayForRemoteRead: TimeInterval = 2

    private let notifyQueue: DispatchQueue
    
    init(notifyQueue: DispatchQueue) {
        self.notifyQueue = notifyQueue
        SwiftSingletons.register(self)
    }

    /// Request notification permissions.
    func registerNotificationSettings() -> Guarantee<Void> {
        
        var options: UNAuthorizationOptions!
        let isWea = TSConstants.appDisplayName.lowercased().contains("cc us")
        if isWea {
            options = [.badge, .sound, .alert]
        } else {
            options = [.badge, .sound, .alert, .criticalAlert]
        }
        
        return Guarantee { done in
            Self.notificationCenter.requestAuthorization(options: options) { (granted, error) in
                Self.notificationCenter.setNotificationCategories(UserNotificationConfig.allNotificationCategories)

                if granted {
                    Logger.info("User granted notification permission")
                } else if let error {
                    Logger.error("Notification permission request failed with error: \(error)")
                } else {
                    Logger.info("User denied notification permission")
                }

                done(())
            }
        }
    }

    // MARK: - Notify

    func notify(
        category: AppNotificationCategory,
        title: String?,
        body: String,
        threadIdentifier: String?,
        userInfo: [AnyHashable: Any],
        interaction: INInteraction?,
        sound: OWSSound?,
        replacingIdentifier: String? = nil,
        triggerTimeInterval: TimeInterval?,
        completion: NotificationActionCompletion?
    ) {
        guard  TSAccountManager.sharedInstance().isRegistered() else {
            
            let error = self.createNotificationError(for: .onboardingIncomplete)
            completion?(error)
            
            return
        }

        let content = UNMutableNotificationContent()
        content.categoryIdentifier = category.identifier
        content.userInfo = userInfo
        
        let isAppActive = CurrentAppContext().isAppForegroundAndActive()//self.fetchIsAppActive()
        
        if let sound, sound != OWSSound.none {
            Logger.info("[Notification Sounds] presenting notification with sound")
            content.sound = sound.notificationSound(isQuiet: isAppActive)
        } else {
            Logger.info("[Notification Sounds] presenting notification without sound")
        }

        var notificationIdentifier: String = UUID().uuidString
        if let replacingIdentifier = replacingIdentifier {
            notificationIdentifier = replacingIdentifier
            Logger.debug("replacing notification with identifier: \(notificationIdentifier)")
            cancelNotificationSync(identifier: notificationIdentifier)
        }

        let trigger: UNNotificationTrigger?
        var triggerTimeInterval_t = kNotificationDelayForRemoteRead
        if let  triggerTimeInterval = triggerTimeInterval {
            triggerTimeInterval_t = triggerTimeInterval
        }
        
        trigger = UNTimeIntervalNotificationTrigger(timeInterval: triggerTimeInterval_t, repeats: false)

        if shouldPresentNotification(category: category, userInfo: userInfo) {
            if let displayableTitle = title?.filterForDisplay {
                content.title = displayableTitle
            }
            if !body.isEmpty {
                content.body = body.filterForDisplay
            }
        } else {
            // Play sound and vibrate, but without a `body` no banner will show.
            Logger.debug("suppressing notification body")
        }

        if let threadIdentifier = threadIdentifier {
            content.threadIdentifier = threadIdentifier
        }

        var contentToUse: UNNotificationContent = content
        if #available(iOS 15, *), let interaction = interaction {
            interaction.donate(completion: { error in

                if let error = error {
                    
                    Logger.error("Failed to donate incoming message intent \(error)")
                    let error = self.createNotificationError(for: .failedToDonateIncomingMessage)
                    completion?(error)
                    
                    return
                }
            })

            if let intent = interaction.intent as? UNNotificationContentProviding {
                do {
                    try contentToUse = content.updating(from: intent)
                } catch {
                    
                    Logger.error("Failed to update UNNotificationContent for comm style notification")
                    let error = self.createNotificationError(for: .failedToUpdateNotificationContent)
                    completion?(error)
                    
                    return
                }
            }
        }

        let request = UNNotificationRequest(identifier: notificationIdentifier, content: contentToUse, trigger: trigger)

        Logger.info("Presenting notification with identifier \(notificationIdentifier)")
        Self.notificationCenter.add(request) { (error: Error?) in
            if let error = error {
                Logger.error("Error presenting notification with identifier \(notificationIdentifier): \(error)")
                let error = self.createNotificationError(for: .failedToPresentingNotification)
                completion?(error)
            } else {
                Logger.info("Presented notification with identifier \(notificationIdentifier)")
                completion?(nil)
            }
        }
    }

    // This method is thread-safe.
    func postGenericIncomingMessageNotification() -> Promise<Void> {
        let content = UNMutableNotificationContent()
//        content.categoryIdentifier = AppNotificationCategory.incomingMessageGeneric.identifier
        //TODO: 待删除
        content.categoryIdentifier = AppNotificationCategory.incomingMessageWithActions_CanReply.identifier
        content.userInfo = [:]
        // We use a fixed identifier so that if we post multiple "generic"
        // notifications, they replace each other.
        let notificationIdentifier = "org.signal.genericIncomingMessageNotification"
        content.body = NotificationStrings.genericIncomingMessageNotification()
        let request = UNNotificationRequest(identifier: notificationIdentifier, content: content, trigger: nil)

        Logger.info("Presenting generic incoming message notification with identifier \(notificationIdentifier)")

        let (promise, future) = Promise<Void>.pending()
        Self.notificationCenter.add(request) { (error: Error?) in
            if let error = error {
                Logger.error("Error presenting generic incoming message notification with identifier \(notificationIdentifier): \(error)")
            } else {
                Logger.info("Presented notification with identifier \(notificationIdentifier)")
            }

            future.resolve(())
        }

        return promise
    }

    private func shouldPresentNotification(category: AppNotificationCategory, userInfo: [AnyHashable: Any]) -> Bool {
        let isAppActive = CurrentAppContext().isAppForegroundAndActive() //self.fetchIsAppActive()
        //TODO: 待删除
        switch category {
        case .incomingMessageWithActions_CanReply:
            // Only show these notification if:
            // - The app is not foreground
            // - The app is foreground, but the corresponding conversation is not open
            guard isAppActive else { return true }
            
            guard let notificationThreadId = userInfo[AppNotificationUserInfoKey.threadId] as? String else {
                owsFailDebug("threadId was unexpectedly nil")
                return true
            }

            guard let conversationSplitVC = CurrentAppContext().frontmostViewController() as? ConversationSplit else {
                return true
            }

            // Show notifications for any *other* thread than the currently selected thread
            return conversationSplitVC.visibleThread?.uniqueId != notificationThreadId

        case .infoOrErrorMessage:
            ///TODO: 待处理
            guard isAppActive else { return true }
            guard let notificationThreadId = userInfo[AppNotificationUserInfoKey.threadId] as? String else {
                owsFailDebug("threadId was unexpectedly nil")
                return true
            }

            guard let conversationSplitVC = CurrentAppContext().frontmostViewController() as? ConversationSplit else {
                return true
            }

            // Show notifications for any *other* thread than the currently selected thread
            return conversationSplitVC.visibleThread?.uniqueId != notificationThreadId
            
        case .scheduleMeetingWithoutActions:
            return true
        }
    
    }
    
    func fetchIsAppActive() -> Bool {
        if Thread.isMainThread {
            return CurrentAppContext().isMainAppAndActive
        } else {
            return DispatchQueue.main.sync {
                CurrentAppContext().isMainAppAndActive
            }
        }
    }
    // MARK: - Replacement

    func replaceNotification(messageId: String, completion: @escaping NotificationReplaceCompletion) {
        getNotificationsRequests { requests in
            let didFindNotification = self.cancelSync(
                notificationRequests: requests,
                matching: .messageIds([messageId])
            )
            completion(didFindNotification)
        }
    }

    // MARK: - Cancellation

    func cancelNotifications(threadId: String, completion: @escaping NotificationActionCompletion) {
        cancel(cancellation: .threadId(threadId), completion: completion)
    }

    func cancelNotifications(messageIds: [String], completion: @escaping NotificationActionCompletion) {
        cancel(cancellation: .messageIds(Set(messageIds)), completion: completion)
    }

    func cancelNotifications(reactionId: String, completion: @escaping NotificationActionCompletion) {
        cancel(cancellation: .reactionId(reactionId), completion: completion)
    }

    func cancelNotificationsForMissedCalls(withThreadUniqueId threadId: String, completion: @escaping NotificationActionCompletion) {
        cancel(cancellation: .missedCalls(inThreadWithUniqueId: threadId), completion: completion)
    }
    
    /// 移除pending的通知
    /// - Parameter categoryIdentifier: 需要忽略的通知种类(预约事件的通知在账户登录状态下需要保留)
    func clearAllNotifications(except categoryIdentifiers: [String]?) {
        Logger.warn("Clearing all notifications")

        Self.notificationCenter.removeAllDeliveredNotifications()
        if let categoryIdentifiers, !categoryIdentifiers.isEmpty {
            UNUserNotificationCenter.current().getPendingNotificationRequests { pendingRequests in
                var needRemoveIdentifiers = [String]()
                for pendingRequest in pendingRequests {
                    let needRemove = !categoryIdentifiers.contains(pendingRequest.content.categoryIdentifier)
                    if (needRemove) {
                        needRemoveIdentifiers.append(pendingRequest.identifier)
                    }
                }
                Logger.debug("Need remove notifications count: \(needRemoveIdentifiers.count)")
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: needRemoveIdentifiers)
            }
        } else {
            Self.notificationCenter.removeAllPendingNotificationRequests()
        }
    }

    private enum CancellationType: Equatable, Hashable {
        case threadId(String)
        case messageIds(Set<String>)
        case reactionId(String)
        case missedCalls(inThreadWithUniqueId: String)
    }

    private func getNotificationsRequests(completion: @escaping ([UNNotificationRequest]) -> Void) {
        Self.notificationCenter.getDeliveredNotifications { delivered in
            Self.notificationCenter.getPendingNotificationRequests { pending in
                completion(delivered.map { $0.request } + pending)
            }
        }
    }

    private func cancel(
        cancellation: CancellationType,
        completion: @escaping NotificationActionCompletion
    ) {
        getNotificationsRequests { requests in
            self.cancelSync(notificationRequests: requests, matching: cancellation)
            completion(nil)
        }
    }

    @discardableResult
    private func cancelSync(
        notificationRequests: [UNNotificationRequest],
        matching cancellationType: CancellationType
    ) -> Bool {
        let requestMatchesPredicate: (UNNotificationRequest) -> Bool = { request in
            switch cancellationType {
            case .threadId(let threadId):
                if
                    let requestThreadId = request.content.userInfo[AppNotificationUserInfoKey.threadId] as? String,
                    requestThreadId == threadId
                {
                    return true
                }
            case .messageIds(let messageIds):
                if
                    let requestMessageId = request.content.userInfo[AppNotificationUserInfoKey.messageId] as? String,
                    messageIds.contains(requestMessageId)
                {
                    return true
                }
            case .reactionId(let reactionId):
//                if
//                    let requestReactionId = request.content.userInfo[AppNotificationUserInfoKey.reactionId] as? String,
//                    requestReactionId == reactionId
//                {
                    return true
//                }
            case .missedCalls(let threadUniqueId):
//                if
//                    (request.content.userInfo[AppNotificationUserInfoKey.isMissedCall] as? Bool) == true,
//                    let requestThreadId = request.content.userInfo[AppNotificationUserInfoKey.threadId] as? String,
//                    threadUniqueId == requestThreadId
//                {
                    return true
//                }
            }

            return false
        }

        let identifiersToCancel: [String] = {
            notificationRequests.compactMap { request in
                if requestMatchesPredicate(request) {
                    return request.identifier
                }

                return nil
            }
        }()

        guard !identifiersToCancel.isEmpty else {
            return false
        }

        Logger.info("Removing delivered/pending notifications with identifiers: \(identifiersToCancel)")

        Self.notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiersToCancel)
        Self.notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiersToCancel)

        return true
    }

    // This method is thread-safe.
    private func cancelNotificationSync(identifier: String) {
        Logger.warn("Canceling notification for identifier: \(identifier)")

        Self.notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
        Self.notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
    
    func createNotificationError(for code: NotificationErrorCode) -> NSError {
        return NSError(domain: notificationErrorDomain, code: code.rawValue, userInfo: [
            NSLocalizedDescriptionKey: code.description
        ])
    }
}

public protocol ConversationSplit {
    var visibleThread: TSThread? { get }
}

public protocol StoryGroupReplier: UIViewController {
//    var storyMessage: StoryMessage { get }
    var threadUniqueId: String? { get }
}

extension OWSSound {
    func notificationSound(isQuiet: Bool) -> UNNotificationSound {
//        guard let filename = filename(quiet: isQuiet) else {
        guard let filename = OWSSounds.filename(for: self, quiet: isQuiet) else {
            owsFailDebug("[Notification Sounds] sound filename was unexpectedly nil")
            return UNNotificationSound.default
        }
        if
            !FileManager.default.fileExists(atPath: (OWSSounds.soundsDirectory() as NSString).appendingPathComponent(filename))
            && !FileManager.default.fileExists(atPath: (Bundle.main.bundlePath as NSString).appendingPathComponent(filename))
        {
            Logger.info("[Notification Sounds] sound file doesn't exist!")
        }
        return UNNotificationSound(named: UNNotificationSoundName(rawValue: filename))
    }
}

extension UNAuthorizationStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .authorized: return "Authorized"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        @unknown default:
            Logger.error("New case! Please update the method")
            return "Raw value: \(rawValue)"
        }
    }
}
