//
// Copyright 2019 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
import Intents
import TTServiceKit

/// There are two primary components in our system notification integration:
///
///     1. The `NotificationPresenter` shows system notifications to the user.
///     2. The `NotificationActionHandler` handles the users interactions with these
///        notifications.
///
/// Our `NotificationActionHandler`s need slightly different integrations for UINotifications (iOS 9)
/// vs. UNUserNotifications (iOS 10+), but because they are integrated at separate system defined callbacks,
/// there is no need for an adapter pattern, and instead the appropriate NotificationActionHandler is
/// wired directly into the appropriate callback point.

public enum AppNotificationCategory: CaseIterable {
    case incomingMessageWithActions_CanReply
    case infoOrErrorMessage
    case scheduleMeetingWithoutActions
}

public enum AppNotificationAction: String, CaseIterable {
    case reply
    case showThread
    case showScheduledMeetingInfo
}

public struct AppNotificationUserInfoKey {
    public static let threadId = "Difft.AppNotificationsUserInfoKey.threadId"
    public static let messageId = "Difft.AppNotificationsUserInfoKey.messageId"
    public static let reactionId = "Difft.AppNotificationsUserInfoKey.reactionId"
    public static let storyMessageId = "Difft.AppNotificationsUserInfoKey.storyMessageId"
    public static let storyTimestamp = "Difft.AppNotificationsUserInfoKey.storyTimestamp"
    public static let callBackAciString = "Difft.AppNotificationsUserInfoKey.callBackUuid"
    public static let callBackPhoneNumber = "Difft.AppNotificationsUserInfoKey.callBackPhoneNumber"
    public static let localCallId = "Difft.AppNotificationsUserInfoKey.localCallId"
    public static let isMissedCall = "Difft.AppNotificationsUserInfoKey.isMissedCall"
    public static let defaultAction = "Difft.AppNotificationsUserInfoKey.defaultAction"
}

 public extension AppNotificationCategory {
    var identifier: String {
        switch self {
        case .incomingMessageWithActions_CanReply:
            return "Difft.AppNotificationCategory.incomingMessageWithActions"
        case .infoOrErrorMessage:
            return "Difft.AppNotificationCategory.infoOrErrorMessage"
        case .scheduleMeetingWithoutActions:
            return "Difft.AppNotificationCategory.scheduleMeeting.localNotification"
        }
    }
    
    var actions: [AppNotificationAction] {
        switch self {
        case .incomingMessageWithActions_CanReply:
            return [.reply]
        case .infoOrErrorMessage:
            return []
        case .scheduleMeetingWithoutActions:
            return []
        }
    }
}

extension AppNotificationAction {
    var identifier: String {
        switch self {
        case .reply:
            return "Difft.AppNotifications.Action.reply"
        case .showThread:
            return "Difft.AppNotifications.Action.showThread"
        case .showScheduledMeetingInfo:
            return "Difft.AppNotifications.Action.showScheduledMeetingInfo"
        }
    }
}

let kAudioNotificationsThrottleCount = 2
let kAudioNotificationsThrottleInterval: TimeInterval = 5
//// MARK: -
//
public class NotificationPresenter: NSObject {
    
    private let presenter = UserNotificationPresenter(notifyQueue: NotificationPresenter.notificationQueue)

    public override init() {
        super.init()

        SwiftSingletons.register(self)
    }

    var previewType: NotificationType {
        return Environment.preferences().notificationPreviewType()
    }

    var shouldShowActions: Bool {
        return previewType == .namePreview
    }

    // MARK: - Notifications Permissions

    public func registerNotificationSettings() -> Guarantee<Void> {
        return presenter.registerNotificationSettings()
    }
    
    /// Classifies a timestamp based on how it should be included in a notification.
    ///
    /// In particular, a notification already comes with its own timestamp, so any information we put in has to be
    /// relevant (different enough from the notification's own timestamp to be useful) and absolute (because if a
    /// thirty-minute-old notification says "five minutes ago", that's not great).
    private enum TimestampClassification {
        case lastFewMinutes
        case last24Hours
        case lastWeek
        case other

        init(_ timestamp: Date) {
            switch -timestamp.timeIntervalSinceNow {
            case ..<0:
                owsFailDebug("Formatting a notification for an event in the future")
                self = .other
            case ...(5 * kMinuteInterval):
                self = .lastFewMinutes
            case ...kDayInterval:
                self = .last24Hours
            case ...kWeekInterval:
                self = .lastWeek
            default:
                self = .other
            }
        }
    }


    // MARK: - Notify
    public func isThreadMuted(_ thread: TSThread, transaction: SDSAnyReadTransaction) -> Bool {
        return thread.isMuted
    }
    
    public func notifyUser(
        forIncomingMessage incomingMessage: TSIncomingMessage,
        thread: TSThread,
        transaction: SDSAnyReadTransaction
    ) {
        
    }
    
    public func notifyForFailedSend(inThread thread: TSThread) {
        let notificationTitle: String?
        switch previewType {
        case .noNameNoPreview:
            notificationTitle = nil
        case .nameNoPreview, .namePreview:
            notificationTitle = Environment.shared.contactsManager.displayName(forPhoneIdentifier: thread.contactIdentifier())
        default:
            notificationTitle = nil
            OWSLogger.info("unknow type")
        }

        let notificationBody = NotificationStrings.failedToSendBody
        let threadId = thread.uniqueId
        let userInfo = [
            AppNotificationUserInfoKey.threadId: threadId
        ]

        performNotificationActionAsync { completion in
            let sound = self.requestSound(thread: thread)
            self.presenter.notify(category: .infoOrErrorMessage,
                                title: notificationTitle,
                                  body: notificationBody(),
                                threadIdentifier: nil, // show ungrouped
                                userInfo: userInfo,
                                interaction: nil,
                                sound: sound,
                                triggerTimeInterval: nil,
                                completion: completion )
        }
    }

    public func notifyUser(
        forTSMessage message: TSMessage,
        thread: TSThread,
        wantsSound: Bool,
        transaction: SDSAnyWriteTransaction
    ) {
        notifyUser(
            tsInteraction: message,
            previewProvider: { tx in
               
                if(thread.isGroupThread()){
                    if let incomingMessage = message as? TSIncomingMessage {
                        let displayName = Environment.shared.contactsManager.displayName(forPhoneIdentifier: incomingMessage.authorId, transaction: tx)
                        return "\(displayName): " + message.previewText(with: transaction)
                    }
                    
                    guard message is TSOutgoingMessage else {
                        return message.previewText(with: transaction)
                    }
                    let localNumber = TSAccountManager.shared.localNumber(with: transaction)
                    let displayName = Environment.shared.contactsManager.displayName(forPhoneIdentifier: localNumber, transaction: tx)
                       return "\(displayName): " + message.previewText(with: transaction)
                } else {
                    return message.previewText(with: transaction)
                }
            },
            thread: thread,
            wantsSound: wantsSound,
            transaction: transaction
        )
    }
    
    private func notifyUser(
        tsInteraction: TSInteraction,
        previewProvider: (SDSAnyWriteTransaction) -> String,
        thread: TSThread,
        wantsSound: Bool,
        transaction: SDSAnyWriteTransaction
    ) {
//        Environment.preferences().notificationPreviewType()
        guard !isThreadMuted(thread, transaction: transaction) else { return }
//
        let notificationTitle: String?
        let threadIdentifier: String?
        switch self.previewType {
        case .noNameNoPreview:
            notificationTitle = Environment.shared.contactsManager.displayName(for: thread, transaction: transaction)
            threadIdentifier = thread.uniqueId
        case .namePreview, .nameNoPreview:
            notificationTitle =  Environment.shared.contactsManager.displayName(for: thread, transaction: transaction)
            threadIdentifier = thread.uniqueId
        @unknown default:
            notificationTitle = Environment.shared.contactsManager.displayName(for: thread, transaction: transaction)
            threadIdentifier = thread.uniqueId
        }
        

        let notificationBody: String
        switch previewType {
        case .noNameNoPreview, .nameNoPreview:
            notificationBody = NotificationStrings.genericIncomingMessageNotification()
        case .namePreview:
            notificationBody = previewProvider(transaction)
        @unknown default:
            notificationBody = NotificationStrings.genericIncomingMessageNotification()
        }

//        let isGroupCallMessage = tsInteraction is OWSGroupCallMessage
//        let preferredDefaultAction: AppNotificationAction = isGroupCallMessage ? .showCallLobby : .showThread
        let preferredDefaultAction: AppNotificationAction = .showThread
//
        let threadId = thread.uniqueId
        let userInfo = [
            AppNotificationUserInfoKey.threadId: threadId,
            AppNotificationUserInfoKey.messageId: tsInteraction.uniqueId,
            AppNotificationUserInfoKey.defaultAction: preferredDefaultAction.rawValue
        ]
//
//        // Some types of generic messages (locally generated notifications) have a defacto
//        // "sender". If so, generate an interaction so the notification renders as if it
//        // is from that user.
//        var interaction: INInteraction?
        performNotificationActionInAsyncCompletion(transaction: transaction) { completion in
            let sound = wantsSound ? self.requestSound(thread: thread) : nil
            self.presenter.notify(category: .incomingMessageWithActions_CanReply,
                                title: notificationTitle,
                                body: notificationBody,
                                threadIdentifier: threadIdentifier,
                                userInfo: userInfo,
                                interaction: nil,
                                sound: sound,
                                triggerTimeInterval: 0,
                                completion: completion)
        }
    }


    /// Note that this method is not serialized with other notifications
    /// actions.
    public func postGenericIncomingMessageNotification() -> Promise<Void> {
        presenter.postGenericIncomingMessageNotification()
    }

    // MARK: - Cancellation

    public func cancelNotifications(threadId: String) {
        performNotificationActionAsync { completion in
            self.presenter.cancelNotifications(threadId: threadId, completion: completion)
        }
    }

    public func cancelNotifications(messageIds: [String]) {
        performNotificationActionAsync { completion in
            self.presenter.cancelNotifications(messageIds: messageIds, completion: completion)
        }
    }

    public func cancelNotifications(reactionId: String) {
        performNotificationActionAsync { completion in
            self.presenter.cancelNotifications(reactionId: reactionId, completion: completion)
        }
    }

    public func cancelNotificationsForMissedCalls(threadUniqueId: String) {
        performNotificationActionAsync { completion in
            self.presenter.cancelNotificationsForMissedCalls(withThreadUniqueId: threadUniqueId, completion: completion)
        }
    }

   
    // MARK: - Serialization

    private static let serialQueue = DispatchQueue(label: "org.Difft.notifications.action")
    private static var notificationQueue: DispatchQueue {
        // The NSE can safely post notifications off the main thread, but the
        // main app cannot.
        if CurrentAppContext().isNSE {
            return serialQueue
        }

        return .main
    }
    private var notificationQueue: DispatchQueue { Self.notificationQueue }

    private static let pendingTasks = PendingTasks(label: "Notifications")

    public static func pendingNotificationsPromise() -> Promise<Void> {
        // This promise blocks on all pending notifications already in flight,
        // but will not block on new notifications enqueued after this promise
        // is created. That's intentional to ensure that NotificationService
        // instances complete in a timely way.
        pendingTasks.pendingTasksPromise()
    }

    private func performNotificationActionAsync(
        _ block: @escaping (@escaping UserNotificationPresenter.NotificationActionCompletion) -> Void
    ) {
        let pendingTask = Self.pendingTasks.buildPendingTask(label: "NotificationAction")
        notificationQueue.async {
            block {error in 
                pendingTask.complete()
            }
        }
    }

    private func performNotificationActionInAsyncCompletion(
        transaction: SDSAnyWriteTransaction,
        _ block: @escaping (@escaping UserNotificationPresenter.NotificationActionCompletion) -> Void
    ) {
        let pendingTask = Self.pendingTasks.buildPendingTask(label: "NotificationAction")
        transaction.addAsyncCompletion(queue: notificationQueue) {
            block {error in 
                pendingTask.complete()
            }
        }
    }

    // MARK: -

    private let unfairLock = UnfairLock()
//    private var notificationVibrationHistory = TruncatedList<Date>(maxLength: kAudioNotificationsThrottleCount)
    private var notificationAudioHistory: [Date] = []
    private var notificationVibrationHistory: [Date] = []
    

    private func requestSound(thread: TSThread) -> OWSSound? {
        shouldPlaySound() ? OWSSounds.notificationSound(for: thread) : nil
    }

    private func requestGlobalSound() -> OWSSound? {
        shouldPlaySound() ? OWSSounds.globalNotificationSound() : nil
    }
    
    func shouldPlaySound() -> Bool {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        // 5秒内最多播放两次通知音
        let kNotificationWindowSeconds: CGFloat = 5.0
        let kMaxNotificationRate = 1

        // 从通知历史记录中删除过时的时间戳
        while self.notificationAudioHistory.count > 0 {
            if let notificationTimestamp = self.notificationAudioHistory.first {
                let notificationAgeSeconds = abs(notificationTimestamp.timeIntervalSinceNow)
                if notificationAgeSeconds > Double(kNotificationWindowSeconds) {
                    self.notificationAudioHistory.remove(at: 0)
                } else {
                    break
                }
            }
        }

        // 判断是否应该播放通知音
//        let meetingStatus = DTMultiCallManager.shared.getCurrentMeetingStatus()
        let inMeeting = TextSecureKitEnv.shared().meetingManager?.isInMeeting()
        
        let shouldPlaySound = self.notificationAudioHistory.count < kMaxNotificationRate && !(inMeeting ?? false)

        if shouldPlaySound {
            // 将新的通知时间戳添加到历史记录中
            let newNotificationTimestamp = Date()
            self.notificationAudioHistory.append(newNotificationTimestamp)
            return true
        } else {
            Logger.debug("Skipping sound for notification")
            return false
        }
    }
    
    func shouldPlayVibration() -> Bool {
            objc_sync_enter(self)
            defer { objc_sync_exit(self) }

            // 在 5 秒的时间窗内，最多允许 1 次震动通知
            let kNotificationWindowSeconds: CGFloat = 5.0
            let kMaxNotificationRate = 1

            // 从通知历史记录中删除过时的时间戳
            while self.notificationVibrationHistory.count > 0 {
                if let notificationTimestamp = self.notificationVibrationHistory.first {
                    let notificationAgeSeconds = abs(notificationTimestamp.timeIntervalSinceNow)
                    if notificationAgeSeconds > Double(kNotificationWindowSeconds) {
                        self.notificationVibrationHistory.remove(at: 0)
                    } else {
                        break
                    }
                }
            }

            // 获取当前会议状态
//            let meetingStatus = TextSecureKitEnv.shared().meetingManager?.getCurrentMeetingStatus()
        let inMeeting = TextSecureKitEnv.shared().meetingManager?.isInMeeting()

            let shouldVibration = self.notificationVibrationHistory.count < kMaxNotificationRate && !(inMeeting ?? false)

            if shouldVibration {
                // 将新的通知时间戳添加到历史记录中
                let newNotificationTimestamp = Date()
                self.notificationVibrationHistory.append(newNotificationTimestamp)
                return true
            } else {
                Logger.debug("Skipping vibration for notification")
                return false
            }
        }
    
}

extension NotificationPresenter : NotificationsProtocol {
    
    public func notifyUser(for incomingMessage: TSIncomingMessage, in thread: TSThread, transaction: TTServiceKit.SDSAnyWriteTransaction) {
        notifyUser(forTSMessage: incomingMessage, thread: thread, wantsSound: false, transaction: transaction )
    }
    
    public func notifyUser(for incomingMessage: TSIncomingMessage, in thread: TSThread,  contactsManager: any ContactsManagerProtocol, transaction: TTServiceKit.SDSAnyReadTransaction) {
        
        notifyUserInternal(
            forIncomingMessage: incomingMessage,
            thread: thread,
            transaction: transaction
        )
    }
    
    public func notifyUser(for error: TSErrorMessage, thread: TSThread, transaction: TTServiceKit.SDSAnyWriteTransaction) {
        
    }
    
    public func notifyUser(forThreadlessErrorMessage error: TSErrorMessage, transaction: TTServiceKit.SDSAnyWriteTransaction) {
        
    }
    
    public func notifyForScheduleMeeting(withTitle title: String?, body: String, userInfo: [AnyHashable : Any] = [:], replacingIdentifier: String?, triggerTimeInterval: TimeInterval, completion: ((Error?) -> Void)? = nil) {
        
        self.presenter.notify(category: .scheduleMeetingWithoutActions, title: title, body: body, threadIdentifier: nil, userInfo: userInfo, interaction: nil, sound: nil,  replacingIdentifier: replacingIdentifier, triggerTimeInterval: triggerTimeInterval ) {error in 
            completion?(error)
        }
    }
    
    public func clearAllNotifications(except categoryIdentifiers: [String]?) {
        self.presenter.clearAllNotifications(except: categoryIdentifiers)
    }
    
    public func syncApnSoundIfNeeded() {
        
        let synced = CurrentAppContext().appUserDefaults().bool(forKey: "hasSyncApnSound")
        guard !synced else { return }
        
        let currentSound = OWSSounds.globalNotificationSound()
        guard let soundFilename = OWSSounds.filename(for: currentSound), !soundFilename.isEmpty else {
            return
        }

        let request = OWSRequestFactory.putV1Profile(withParams: ["privateConfigs":["notificationSound":soundFilename]])
        self.networkManager.makeRequest(request) { response in
            
            if let responseJson = response.responseBodyJson as? [String: Any] {
                do {
                    let entity = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self, fromJSONDictionary: responseJson) as! DTAPIMetaEntity
                    
                    if entity.status == DTAPIRequestResponseStatus.OK.rawValue {
                        
                        Logger.info("sync apn sound success, current \(soundFilename).")
                        CurrentAppContext().appUserDefaults().set(true, forKey: "hasSyncApnSound")
                        
                    } else {
                        
                        let error = DTErrorWithCodeDescription(DTAPIRequestResponseStatus(rawValue: entity.status) ?? DTAPIRequestResponseStatus.dataError, entity.reason)
                        Logger.error("sync apn sound fail: \(error).")
                        
                    }
                } catch let error {
                    
                    Logger.error("sync apn sound fail: \(error).")
                    
                }
            } else {
                
                Logger.error("sync apn sound fail: response data error.")
                
            }
            
        } failure: { errorWrapper in
            Logger.error("sync apn sound fail: \(errorWrapper.asNSError.description)");
        }

    }
    
    private func notifyUserInternal(
        forIncomingMessage incomingMessage: TSIncomingMessage,
        thread: TSThread,
        transaction: SDSAnyReadTransaction) {
            
            guard !thread.isMuted else {
                return
            }
            
            let rawMessageText = incomingMessage.previewText(with: transaction)
            
            var messageText = DisplayableText.filterNotificationText(rawMessageText)
            if incomingMessage.isCardMessage() {
                messageText = messageText?.removeMarkdownStyle()
            }
            
            guard CurrentAppContext().isAppForegroundAndActive(), let messageText = messageText,  !messageText.isEmpty else {
                return
            }
            
            let shouldPlaySound = shouldPlaySound()
            let shouldPlayVibration = shouldPlaySound ? false : shouldPlayVibration()
            let shouldPlayAll = true
            
            if let groupThread = thread as? TSGroupThread {
                
                if isUseGlobalNotification(groupThread), isGlobalNotificationOff(){
                    return
                }
                
                if isGroupNotificationTypeOff(groupThread) {
                    return
                }
                
                if !shouldNotifyForGroupMessage(incomingMessage, inThread: groupThread) {
                    return
                }
                
            } else {
                if isGlobalNotificationOff() {
                    return
                }
            }
            
            if shouldPlayAll, shouldPlaySound {
                playAudio(withThread: thread)
                return
            }
            
            if shouldPlayAll, shouldPlaySound {
                playVibration(withThread: thread)
                return
            }
        }
    
    private func shouldNotifyForGroupMessage(_ incomingMessage: TSIncomingMessage, inThread thread: TSGroupThread) -> Bool {
        let globalNotiType = self.globalNotificationType()
        let isUseGlobal = thread.groupModel.useGlobal.boolValue
        let isGroupSettingAtMe = self.isGroupNotificationTypeAtMe(thread)
        let isMessageAtMe = isAtMe(message: incomingMessage)

        if isUseGlobal && globalNotiType == .MENTION && !isMessageAtMe {
            return false
        }

        if !isUseGlobal && isGroupSettingAtMe && !isMessageAtMe {
            return false
        }
        
        return true
    }

    
    private func playAudio(withThread thread: TSThread) {
        let sound = OWSSounds.notificationSound(for: thread)
        let soundId = OWSSounds.systemSoundID(for: sound, quiet: true)
        // 震动，遵循静音开关，遵循“警告”音量而非媒体音量。
        AudioServicesPlayAlertSound(soundId)
    }

    private func playVibration(withThread thread: TSThread) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    private func isAtMe(message: TSIncomingMessage) -> Bool {
        var isAtMe = false
        if let atPersons = message.atPersons, !atPersons.isEmpty, let atPersons = message.atPersons?.components(separatedBy: ";"), let localNumber = TSAccountManager.localNumber() {
            isAtMe = atPersons.contains(localNumber) || atPersons.contains(MENTIONS_ALL)
        }
        return isAtMe
    }

    private func globalNotificationType() -> DTGlobalNotificationType {
        let contact = getLocalNumberContactInfoFromDataBase()
        return DTGlobalNotificationType(rawValue: contact?.privateConfigs?.globalNotification?.intValue ?? 0) ?? DTGlobalNotificationType.OFF
    }

    
    private func isGroupNotificationTypeAtMe(_ groupThread: TSGroupThread) -> Bool {
        return groupThread.groupModel.notificationType.intValue == TSGroupNotificationType.atMe.rawValue
    }
    
    private func isUseGlobalNotification(_ groupThread: TSGroupThread) -> Bool {
            let useGlobal = groupThread.groupModel.useGlobal.intValue
            return useGlobal != 0
        }

    private func isGroupNotificationTypeOff(_ groupThread: TSGroupThread) -> Bool {
            let notificationType = TSGroupNotificationType(rawValue: groupThread.groupModel.notificationType.intValue)
            let useGlobal = groupThread.groupModel.useGlobal.intValue
            if useGlobal == 0 && notificationType == .off {
                return true
            }
            return false
        }

    private  func isGlobalNotificationOff() -> Bool {
            if let contact = getLocalNumberContactInfoFromDataBase(), let privateConfigs = contact.privateConfigs {
                if let globalNotification = privateConfigs.globalNotification, globalNotification.intValue == DTGlobalNotificationType.OFF.rawValue {
                    return true
                }
            }
            return false
        }

        // 获取自己的联系人相关信息
    private func getLocalNumberContactInfoFromDataBase() -> Contact? {
        
        
        guard let contactsManager = Environment.shared.contactsManager, let recipientId = TSAccountManager.shared.localNumber() else {
            return nil
        }
        guard var account = contactsManager.signalAccount(forRecipientId: recipientId) else {
            var account_t : SignalAccount?;
            self.databaseStorage.read { transaction in
                if let localNumber = TSAccountManager.shared.localNumber(with: transaction) {
                    account_t = SignalAccount(recipientId: localNumber, transaction: transaction)
                }
            }
            guard account_t != nil  else {
                return nil
            }
            return account_t?.contact
        }
        
        return account.contact
    }
}

struct TruncatedList<Element> {
    let maxLength: Int
    private var contents: [Element] = []

    init(maxLength: Int) {
        self.maxLength = maxLength
    }

    mutating func append(_ newElement: Element) {
        var newElements = self.contents
        newElements.append(newElement)
        self.contents = Array(newElements.suffix(maxLength))
    }
}

extension TruncatedList: Collection {
    typealias Index = Int

    var startIndex: Index {
        return contents.startIndex
    }

    var endIndex: Index {
        return contents.endIndex
    }

    subscript (position: Index) -> Element {
        return contents[position]
    }

    func index(after i: Index) -> Index {
        return contents.index(after: i)
    }
}

