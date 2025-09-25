//
//  NotificationService.swift
//  NSE
//
//  Created by Felix on 2022/1/13.
//

import UserNotifications
import TTServiceKit
import TTMessaging

typealias ContentHandler = (UNNotificationContent) -> Void

struct ContentHandlerObject {
    let identifier: String
    let contentHandler: ContentHandler
    
    init(identifier: String, contentHandler: @escaping ContentHandler) {
        self.identifier = identifier
        self.contentHandler = contentHandler
    }
}

// We keep a global `environment` singleton to ensure that our app context,
// database, logging, etc. are only ever setup once per *process*
let environment = NSEEnvironment()

let hasShownFirstUnlockError = AtomicBool(false, lock: .sharedGlobal)

class NotificationService: UNNotificationServiceExtension {
    
    private var contentHandlers = AtomicArray<ContentHandlerObject>(lock: .sharedGlobal)
    private var plainAttemptContents = AtomicDictionary<String, UNNotificationContent>(lock: .sharedGlobal)
    
    var threadHelper: DTThreadHelper {
        return DTThreadHelper.sharedManager()
    }
    
    // MARK: -

    private static let unfairLock = UnfairLock()
    private static var _logTimer: OffMainThreadTimer?
    private static var _nseCounter: Int = 0
    private let defaultNewMessageBody = Localized("new_message", comment: "")
    
    private static func nseDidStart() -> Int {
        unfairLock.withLock {
//            if DebugFlags.internalLogging,
              if _logTimer == nil {
                _logTimer = OffMainThreadTimer(timeInterval: 1.0, repeats: true) { _ in
                    Logger.info("... memoryUsage: \(LocalDevice.memoryUsageString)")
                }
            }

            _nseCounter = _nseCounter + 1
            return _nseCounter
        }
    }

    private static func nseDidComplete() -> Int {
        unfairLock.withLock {
            _nseCounter = _nseCounter > 0 ? _nseCounter - 1 : 0

            if _nseCounter == 0, _logTimer != nil {
                _logTimer?.invalidate()
                _logTimer = nil
            }
            return _nseCounter
        }
    }
    
    // MARK: -

    // This method is thread-safe.
    func completeWithNameNoPreview(timeHasExpired: Bool = false) {

        let nseCount = Self.nseDidComplete()

        guard let contentHandlerObject = contentHandlers.popHead() else {
            Logger.warn("No contentHandlerObject, memoryUsage: \(LocalDevice.memoryUsageString), nseCount: \(nseCount).")
            Logger.flush()
            return
        }
        
        guard let plainAttemptContent = plainAttemptContents.pop(contentHandlerObject.identifier) else {
            Logger.warn("No contentHandler, memoryUsage: \(LocalDevice.memoryUsageString), nseCount: \(nseCount).")
            Logger.flush()
            return
        }
        
        if let mutablePlainAttemptContent = plainAttemptContent.mutableCopy() as? UNMutableNotificationContent {
            ///allUnMutedUnreadCount 回调可能为负
            threadHelper.syncLoadUnReadThreadForNSE{ allUnMutedUnreadCount in
                
                if allUnMutedUnreadCount >= 0 {
                    let latestBadge = allUnMutedUnreadCount
                    Logger.info("latestBadge \(latestBadge).")
                    
                    // Modify the notification content
                    mutablePlainAttemptContent.badge = NSNumber(value: latestBadge)
                }
                contentHandlerObject.contentHandler(mutablePlainAttemptContent)
                
            }
        } else {
            
            contentHandlerObject.contentHandler(plainAttemptContent)
        }
        
        Logger.info("Invoking contentHandler, memoryUsage: \(LocalDevice.memoryUsageString), nseCount: \(nseCount).")
        Logger.flush()
    }
    
    func configWithNameAndPreview(title: String = "", body: String = "") {
        
        Logger.info("Invoking configWithNameAndPreview, memoryUsage: \(LocalDevice.memoryUsageString).")
                
        guard let contentHandlerObject = contentHandlers.first else {
            Logger.warn("No contentHandlerObject, memoryUsage: \(LocalDevice.memoryUsageString).")
            Logger.flush()
            return
        }
        
        guard let plainAttemptContent = plainAttemptContents[contentHandlerObject.identifier] else {
            Logger.warn("No contentHandler, memoryUsage: \(LocalDevice.memoryUsageString).")
            Logger.flush()
            return
        }
        
        if let mutablePlainAttemptContent = plainAttemptContent.mutableCopy() as? UNMutableNotificationContent {
            // Modify the notification content
            if title.count > 0 {
                mutablePlainAttemptContent.title = title
            }
            if body.count > 0 {
                mutablePlainAttemptContent.body = body
            }
            
            Logger.info("processPlainNotification title: \(title).\n\(body)")
            
            plainAttemptContents[contentHandlerObject.identifier] = mutablePlainAttemptContent
        }
    }
    
    func configWithNoNameNoPreView() {
        Logger.info("Invoking configWithNoNameNoPreView, memoryUsage: \(LocalDevice.memoryUsageString).")
        
        guard let contentHandlerObject = contentHandlers.first else {
            Logger.warn("No contentHandlerObject, memoryUsage: \(LocalDevice.memoryUsageString).")
            Logger.flush()
            return
        }
        
        guard let plainAttemptContent = plainAttemptContents[contentHandlerObject.identifier] else {
            Logger.warn("No contentHandler, memoryUsage: \(LocalDevice.memoryUsageString).")
            Logger.flush()
            return
        }
        
        if let mutablePlainAttemptContent = plainAttemptContent.mutableCopy() as? UNMutableNotificationContent {
            // Modify the notification content
            mutablePlainAttemptContent.title = ""
            mutablePlainAttemptContent.body = defaultNewMessageBody
            
            plainAttemptContents[contentHandlerObject.identifier] = mutablePlainAttemptContent
        }
    }

    var isUpdating = false
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        let attemptContent = request.content
        
        let isCall = isCallNotification(attemptContent: attemptContent)
        // 如果是 call 相关的直接展示 notification，不拉数据
        guard !isCall else {
            Logger.info("call 相关的直接展示 notification，不拉数据")
            Logger.flush()
            contentHandler(attemptContent)
            return
        }
        
        let identifier = request.identifier
        plainAttemptContents.set([identifier: attemptContent])
        
        let contentHandleObject = ContentHandlerObject(identifier: identifier, contentHandler: contentHandler)
        contentHandlers.append(contentHandleObject)
        
        // This should be the first thing we do.
        environment.ensureAppContext()
        
        if NSEEnvironment.verifyDBKeysAvailable() != nil {
            if hasShownFirstUnlockError.tryToSetFlag() {
                Logger.error("DB Keys not accessible; showing error.")
            } else {
                // Only show a single error if we receive multiple pushes
                // before first device unlock.
                Logger.error("DB Keys not accessible; completing silently.")
            }
            self.completeWithNameNoPreview()
            return
        }
        
        if environment.setupIfNecessary() != nil {
            // This should not occur; see above.  If we've reached this
            // point, the NSEEnvironment.isSetup flag is already set,
            // but the environment has _not_ been setup successfully.
            // We need to terminate the NSE to return to a good state.
            Logger.warn("Posting error notification and skipping processing.")
            Logger.flush()
            self.completeWithNameNoPreview()
            return
        }

        let nseCount = Self.nseDidStart()
        
        Logger.info("Received notification in class: \(self), thread: \(Thread.current), pid: \(ProcessInfo.processInfo.processIdentifier), memoryUsage: \(LocalDevice.memoryUsageString), nseCount: \(nseCount)")
        
        AppReadiness.runNowOrWhenAppDidBecomeReadySync({
            environment.askMainAppToHandleReceipt { [weak self] mainAppHandledReceipt in
                
                guard let self else {
                    contentHandler(attemptContent)
                    return
                }
                
                // 处理明文通知
                let notiType = Environment.preferences().notificationPreviewType()
                self.handleNotificationEnvelop(notiType: notiType, attemptContent: attemptContent)
                
                let scheduleResult = scheduleUpdateNotification(attemptContent: attemptContent)
                Logger.debug("calendar event update: \(scheduleResult.0), version:\(scheduleResult.1 ?? -1)")
                if scheduleResult.0 == true, let serverVersion = scheduleResult.1 {
                    Logger.info("\(logTag) calendar update")
                    isUpdating = true
                    DTCalendarManager.shared.updateLocalNotification(serverVersion: serverVersion, completion: { [weak self] in
                        guard let self else { return }
                        isUpdating = false
                    })
                    
                    return
                }

                guard !mainAppHandledReceipt else {
                    Logger.info("Received notification handled by main application, memoryUsage: \(LocalDevice.memoryUsageString).")
                    self.completeWithNameNoPreview()
                    return
                }

                guard !isUpdating else { return }
                Logger.info("Processing received notification, memoryUsage: \(LocalDevice.memoryUsageString).")

                self.fetchAndProcessMessages()
            }
        })
    }
    
    // Called just before the extension will be terminated by the system.
    override func serviceExtensionTimeWillExpire() {
        Logger.error("NSE expired before messages could be processed")

        // We complete silently here so that nothing is presented to the user.
        // By default the OS will present whatever the raw content of the original
        // notification is to the user otherwise.
        completeWithNameNoPreview(timeHasExpired: true)
    }
    
    // This method is thread-safe.
    private func fetchAndProcessMessages() {

        environment.processingMessageCounter.increment()

        Logger.info("Beginning message fetch.")
        
        let fetchPromise = messageFetcherJob.run().promise
        fetchPromise.timeout(seconds: 20, description: "Message Fetch Timeout.") {
            NotificationServiceError.timeout
        }.catch(on: DispatchQueue.global()) { [weak self] _ in
            // Do nothing, Promise.timeout() will log timeouts.
            environment.processingMessageCounter.decrementOrZero()
            self?.completeWithNameNoPreview()
        }

        fetchPromise.then(on: DispatchQueue.global()) { [weak self] () -> Promise<Void> in
            Logger.info("Waiting for processing to complete.")
            
            guard let self else { return Promise.value(()) }
                        
            let runningAndCompletedPromises = AtomicArray<(String, Promise<Void>)>(lock: .sharedGlobal)
            
            let processingCompletePromise = firstly { () -> Promise<Void> in
                let promise = self.messageProcessor.processingCompletePromise()
                runningAndCompletedPromises.append(("MessageProcessorCompletion", promise))
                return promise
            }.then(on: DispatchQueue.global()) { () -> Promise<Void> in
                Logger.info("Initial message processing complete.")
                // Wait until all async side effects of message processing are complete.
                let completionPromises: [(String, Promise<Void>)] = [
                    // Wait until all ACKs are complete.
                    ("Pending messageFetch ack", Self.messageFetcherJob.pendingAcksPromise()),
//                    // Wait until all outgoing receipt sends are complete.
//                    ("Pending receipt sends", Self.outgoingReceiptManager.pendingSendsPromise()),
//                    // Wait until all outgoing messages are sent.
//                    ("Pending outgoing message", Self.messageSender.pendingSendsPromise()),
//                    // Wait until all sync requests are fulfilled.
//                    ("Pending sync request", OWSMessageManager.pendingTasksPromise())
                ]
                let joinedPromise = Promise.when(resolved: completionPromises.map { (name, promise) in
                    promise.done(on: DispatchQueue.global()) {
                        Logger.info("\(name) complete.")
                    }
                })
                completionPromises.forEach { runningAndCompletedPromises.append($0) }
                return joinedPromise.asVoid()
            }
            processingCompletePromise.timeout(seconds: 20, ticksWhileSuspended: true, description: "Message Processing Timeout.") {
                runningAndCompletedPromises.get().filter { $0.1.isSealed == false }.forEach {
                    Logger.warn("Completion promise: \($0.0) did not finish.")
                }
                return NotificationServiceError.timeout
            }.catch { _ in
                // Do nothing, Promise.timeout() will log timeouts.
            }
            return processingCompletePromise
        }.ensure(on: DispatchQueue.global()) { [weak self] in
            
            Logger.info("Message fetch and decryptionAndProcessing completed.")
            
            environment.processingMessageCounter.decrementOrZero()
            self?.completeWithNameNoPreview()
        }.catch (on: DispatchQueue.global()) { [weak self] error in
            Logger.error("Error: \(error)")
            
            environment.processingMessageCounter.decrementOrZero()
            self?.completeWithNameNoPreview()
        }
    }
    
    private enum NotificationServiceError: Error {
        case timeout
    }

    // 是否 call 相关
    func isCallNotification(attemptContent :UNNotificationContent) -> Bool {
        
        let userInfo = attemptContent.userInfo
        if let aps = userInfo["aps"] as? Dictionary<String, Any> {
    
            guard let alert = aps["alert"] as? Dictionary<String, Any> else {
                return false
            }
            
            guard let lockey = alert["loc-key"] as? String else {
                return false
            }
            
            switch lockey {
            case "PERSONAL_CALL",
                "PERSONAL_CALL_CANCEL",
                "PERSONAL_CALL_TIMEOUT",
                "GROUP_CALL",
                "GROUP_CALL_COLSE",
                "GROUP_CALL_OVER",
                "MEETING-POPUPS":
                return true
            default:
                return false
            }
            
        } else {
            return false
        }
    }
    
    func scheduleUpdateNotification(attemptContent :UNNotificationContent) -> (Bool, Int?) {
        
        let userInfo = attemptContent.userInfo
        guard let aps = userInfo["aps"] as? Dictionary<String, Any> else {
            return (false, nil)
        }
        
        guard let alert = aps["alert"] as? Dictionary<String, Any>, let locKey = alert["loc-key"] as? String else {
            return (false, nil)
        }
        
        guard locKey == "CALENDAR_FULL_UPDATE" else {
            return (false, nil)
        }
        
        if let json = aps["passthrough"] as? String, let jsonData = json.data(using: .utf8) {
            do {
                guard let passthrough = try JSONSerialization.jsonObject(with: jsonData, options: []) as? Dictionary<String, Any>, let version = passthrough["version"] as? Int else {
                    return (true, nil)
                }
                return (true, version)
            } catch {
                Logger.error("parse JSON error: \(error.localizedDescription)")
                return (true, nil)
            }
        } else {
            return (true, nil)
        }
        
    }
    
    func handleNotificationEnvelop(notiType: NotificationType, attemptContent :UNNotificationContent) {
        
        let userInfo = attemptContent.userInfo
        if let aps = userInfo["aps"] as? Dictionary<String, Any> {
            Logger.debug("\(logTag) aps = \(aps)")

            guard let msg = aps["msg"] as? String else {
                processNotification(displayName: "", notiType: notiType, aps: aps, dataMessage: nil)
                return
            }
            
            guard let data = Data(base64Encoded: msg) else { return }
            
            guard let signalingKey = TSAccountManager.signalingKey() else { return }
            
            guard let decryptedPayload = SSKCryptography.decryptAppleMessagePayload(data as Data, withSignalingKey: signalingKey) else {
                return
            }
            
            guard let envelope = try? DSKProtoEnvelope(serializedData: decryptedPayload) else {
                return
            }
            
            guard envelope.hasContent else {
                return
            }
            
            guard envelope.type == .plaintext || envelope.type == .etoee else {
                return
            }
            
            guard var plaintextData = envelope.content else {
                return
            }
            
            if envelope.type == .etoee {
                var decryptSuccess = false
                self.databaseStorage.write { writeTransaction in
                    let result = Self.messageDecrypter.decryptEnvelope(
                        envelope,
                        envelopeData: decryptedPayload,
                        transaction: writeTransaction
                    )
                    switch result {
                    case .success(let result):
                        if let resultData = result.plaintextData {
                            plaintextData = resultData
                            decryptSuccess = true
                        }
                    case .failure(_):
                        return
                    }
                }
                if !decryptSuccess {
                    return
                }
                
            }
            
            
            guard let content = try? DSKProtoContent(serializedData: plaintextData) else {
                return
            }
            
            if let callMessage = content.callMessage {
                if let hangup = callMessage.hangup, let roomID = hangup.roomID { // 挂断 call
                    Logger.debug("\(logTag) NSE receive hangup")
                    Environment.preferences().endCallKitCall(withRoomId: roomID)
                    configWithNameAndPreview(title: "TempTalk", body: "The call has ended")
                } else if let reject = callMessage.reject, let roomID = reject.roomID {
                    Logger.debug("\(logTag) NSE receive reject")
                    Environment.preferences().endCallKitCall(withRoomId: roomID)
                    configWithNameAndPreview(title: "TempTalk", body: "The call has been rejected")
                } else if let cancel = callMessage.cancel, let roomID = cancel.roomID {
                    Logger.debug("\(logTag) NSE receive cancel")
                    Environment.preferences().endCallKitCall(withRoomId: roomID)
                    configWithNameAndPreview(title: "TempTalk", body: "The call has been canceled")
                }
            }
              
            guard let dataMessage = content.dataMessage else {
                return
            }
            
            Logger.info("Msg.timestamp = \(envelope.timestamp), \(envelope.source ?? "nil").\(envelope.sourceDevice)")
            var displayName = ""
            if let source = envelope.source {
                databaseStorage.read { transaction in
                    displayName = Environment.shared.contactsManager.displayName(forPhoneIdentifier: source, transaction: transaction)
                }
            }
            
            
            
            processNotification(displayName: displayName, notiType: notiType, aps: aps, dataMessage: dataMessage)
        }
    }
    
    func processNotification(displayName:String, notiType: NotificationType, aps: Dictionary<String, Any>, dataMessage: DSKProtoDataMessage?) {
        guard let alert = aps["alert"] as? Dictionary<String, Any> else {
            return
        }
        
        guard let lockey = alert["loc-key"] as? String, let locargs = alert["loc-args"] as? Array<String> else {
            return
        }
        
        let result = processPlainNotification(displayName: displayName, notiType: notiType, title: alert["title"] as? String, body: alert["body"] as? String, lockey: lockey, locargs: locargs, dataMessage: dataMessage)
        Logger.info("result = \(result)")
    }
    
    // TODO: 将后面处理 envelop 逻辑移出
    func processPlainNotification(displayName: String, notiType: NotificationType, title: String? = nil, body: String? = nil, lockey: String, locargs: Array<String>, dataMessage: DSKProtoDataMessage?) -> Bool {
        Logger.info("processPlainNotification notiType: \(notiType)")
        
        switch notiType {
        case .noNameNoPreview:
            configWithNoNameNoPreView()
            return true
            
        case .nameNoPreview:
            if showNameNoPreviewNotification(displayName: displayName, title: title, body: body, lockey: lockey, locargs: locargs, dataMessage: dataMessage) == true {
                return true
            } else {
                return false
            }
            
        case .namePreview:
            if showNameAndPreviewNotification(displayName: displayName, lockey: lockey, locargs: locargs, dataMessage: dataMessage) == true {
                return true
            } else {
                return false
            }
            
        @unknown default:
            return false
        }
    }
    
    func showNameNoPreviewNotification(displayName: String, title: String? = nil, body: String? = nil, lockey: String, locargs: Array<String>, dataMessage: DSKProtoDataMessage?) -> Bool {
        var plainTitle = ""
        var plainBody = defaultNewMessageBody
        
        switch lockey {
        case "PERSONAL_NORMAL",
            "PERSONAL_FILE",
            "PERSONAL_CALL",
            "PERSONAL_REPLY",
            "PERSONAL_CALL_CANCEL",
            "PERSONAL_CALL_TIMEOUT",
            "GROUP_MENTIONS_DESTINATION",
            "GROUP_REPLY_DESTINATION",
            "GROUP_MENTIONS_OTHER",
            "GROUP_REPLY_OTHER",
            "GROUP_MENTIONS_ALL",
            "GROUP_NORMAL",
            "GROUP_FILE",
            "GROUP_CALL",
            "GROUP_CALL_COLSE",
            "GROUP_CALL_OVER",
            "GROUP_ADD_ANNOUNCEMENT",
            "GROUP_UPDATE_ANNOUNCEMENT",
            "RECALL_MSG",
            "RECALL_MENTIONS_MSG",
            "TASK_MSG",
            "CREATE_TASK",
            "DELETE_TASK",
            "UPDATE_TASK",
            "JOIN_TASK",
            "KICK_OUT_TASK",
            "FOLLOW_TASK",
            "UN_FOLLOW_TASK",
            "TASK_NAME_CHANGE",
            "TASK_DESCRIPTION_CHANGE",
            "TASK_PRIORITY_CHANGE",
            "TASK_DUE_TIME_CHANGE",
            "TASK_ASSIGNEE_CHANGE",
            "TASK_FOLLOW_CHANGE",
            "TASK_STATUS_DONE",
            "TASK_STATUS_REFUSE",
            "TASK_STATUS_RECOVER",
            "TASK_REMIND",
            "TASK_ARCHIVED",
            "CALENDAR_FULL_UPDATE":
            if locargs.count == 1 {
                let fromRecipient = locargs.first ?? "TempTalk"
                if displayName.isEmpty {
                    plainTitle = fromRecipient
                } else {
                    plainTitle = displayName
                }
                plainBody = defaultNewMessageBody
            } else if (locargs.count > 1) {
                var plainTitle = locargs.first ?? "TempTalk"
                var fromRecipient = locargs[1]
                if !displayName.isEmpty {
                    fromRecipient = displayName
                }
                plainBody = "\(fromRecipient) : \(defaultNewMessageBody)"
            }
        default:
            break
        }
        
        configWithNameAndPreview(title: plainTitle, body: plainBody)
        return true
    }
    
    func showNameAndPreviewNotification(displayName: String, lockey: String = "", locargs: Array<String>, dataMessage: DSKProtoDataMessage?) -> Bool {
        var plainTitle = ""
        var plainBody = ""
        
        switch lockey {
        case "PERSONAL_NORMAL",
            "PERSONAL_REPLY",
            "CALENDAR_FULL_UPDATE":
            if let fromRecipient = locargs.first {
                var plainTitle = ""
                if displayName.isEmpty {
                    plainTitle = fromRecipient
                } else {
                    plainTitle = displayName
                }
                if let dataMessage = dataMessage {
                    
                    if ((dataMessage.screenShot?.source) != nil) {
                        plainBody = "[\(NSLocalizedString("took a screenshot!", comment: ""))]"
                    } else {
                        var body = ""
                        
                        if dataMessage.forwardContext != nil {
                            body = Localized("MESSAGE_PREVIEW_TYPE_HISTORY", comment: "")
                        } else if dataMessage.hasMessageMode && dataMessage.messageMode == DSKProtoDataMessageMessageMode.confidential.rawValue {
                            body = "\(NSLocalizedString("MESSAGE_PREVIEW_TYPE_CONFIDENTIAL", comment: ""))"
                        } else if let card = dataMessage.card, let content = card.content {
                            if content.contains("$FORMAT-LOCAL-TIME") {
                                body = DateUtil.replacingFormatTime(body: content)?.removeMarkdownStyle() ?? ""
                            } else {
                                body = content.removeMarkdownStyle()
                            }
                        } else if dataMessage.contact.count > 0 {
                            body = Localized("MESSAGE_PREVIEW_TYPE_CONTACT_CARD", comment: "")
                        } else {
                            body = dataMessage.body ?? ""
                        }
                        plainBody = "\(plainTitle) : \(body)"
                    }
                } else {
                    
                    plainBody = "\(plainTitle)"
                }
            }
        case "PERSONAL_FILE":
            if let fromRecipient = locargs.first {
                
                var plainTitle = ""
                if displayName.isEmpty {
                    plainTitle = fromRecipient
                } else {
                    plainTitle = displayName
                }
                
                if let dataMessage = dataMessage {
                    plainBody = "\(plainTitle) : "
                    
                    if dataMessage.hasMessageMode && dataMessage.messageMode == DSKProtoDataMessageMessageMode.confidential.rawValue {
                        plainBody.append("\(NSLocalizedString("MESSAGE_PREVIEW_TYPE_CONFIDENTIAL", comment: ""))")
                    } else {
                        if let attachmentProto = dataMessage.attachments.first {
                            let contentType = getContentType(attachmentProto: attachmentProto)
                            plainBody.append(contentType)
                        }
                        
                        if let body = dataMessage.body {
                            plainBody.append(" \(body)")
                        }
                    }
                    
                } else {
                    
                    let body = Localized("QUOTED_REPLY_TYPE_ATTACHMENT", comment: "")
                    plainBody = "\(plainTitle) : \(body)"
                }
            } else {
                return false
            }
        case "PERSONAL_CALL",
            "PERSONAL_CALL_CANCEL",
            "PERSONAL_CALL_TIMEOUT":
            return false;
            
        case "GROUP_NORMAL":
            if locargs.count > 1 {
                var body = ""
                if let dataMessage = dataMessage {
                    if ((dataMessage.screenShot?.source) != nil) {
                        body = "[\(NSLocalizedString("took a screenshot!", comment: ""))]"
                    } else if dataMessage.hasMessageMode && dataMessage.messageMode == DSKProtoDataMessageMessageMode.confidential.rawValue {
                        body = "\(NSLocalizedString("MESSAGE_PREVIEW_TYPE_CONFIDENTIAL", comment: ""))"
                    } else if dataMessage.forwardContext != nil {
                        body = Localized("MESSAGE_PREVIEW_TYPE_HISTORY", comment: "")
                    } else if let card = dataMessage.card, let content = card.content {
                        if content.contains("$FORMAT-LOCAL-TIME") {
                            body = DateUtil.replacingFormatTime(body: content)?.removeMarkdownStyle() ?? ""
                        } else {
                            body = content.removeMarkdownStyle()
                        }
                    } else if dataMessage.contact.count > 0 {
                        body = Localized("MESSAGE_PREVIEW_TYPE_CONTACT_CARD", comment: "")
                    } else {
                        body = dataMessage.body ?? ""
                    }
                    
                    plainTitle = locargs.first ?? "TempTalk"
                    var fromRecipient = locargs[1]
                    if !displayName.isEmpty {
                        fromRecipient = displayName
                    }
                    plainBody = "\(fromRecipient) : \(body)"
                    
                } else {
                    
                    if let fromRecipient = locargs.first {
                        plainBody = "\(fromRecipient)"
                    }
                }
            }
        case "GROUP_FILE":
            
            if locargs.count >= 2 {
                
                plainTitle = locargs.first ?? "TempTalk"
                var fromRecipient = locargs[1]
                if !displayName.isEmpty {
                    fromRecipient = displayName
                }
                
                plainBody = "\(fromRecipient) : "
                
                if let dataMessage = dataMessage {
                    
                    if dataMessage.hasMessageMode && dataMessage.messageMode == DSKProtoDataMessageMessageMode.confidential.rawValue {
                        plainBody = "\(NSLocalizedString("MESSAGE_PREVIEW_TYPE_CONFIDENTIAL", comment: ""))"
                    } else {
                        if let attachmentProto = dataMessage.attachments.first {
                            let contentType = getContentType(attachmentProto: attachmentProto)
                            plainBody.append(contentType)
                        }
                        
                        if let body = dataMessage.body {
                            plainBody.append(" \(body)")
                        }
                    }
                    
                } else {
                    
                    let body = Localized("QUOTED_REPLY_TYPE_ATTACHMENT", comment: "")
                    plainBody = "\(fromRecipient) : \(body)"
                }
            }
            
        case "GROUP_CALL",
            "GROUP_CALL_COLSE",
            "GROUP_CALL_OVER",
            "GROUP_ADD_ANNOUNCEMENT",
            "GROUP_UPDATE_ANNOUNCEMENT",
            "MEETING-POPUPS":
            return false
            
        case "GROUP_MENTIONS_DESTINATION",
            "GROUP_REPLY_DESTINATION":
            // TODO: @ 不展示附带文本，因为 body 里有 @ 人信息，不能去重
            if locargs.count >= 2 {
                
                plainTitle = locargs.first ?? "TempTalk"
                var fromRecipient = locargs[1]
                if !displayName.isEmpty {
                    fromRecipient = displayName
                }
                
                //                let body = dataMessage.body
                plainBody = "\(fromRecipient) " + Localized("APN_SOMEONE_MENTION_YOU_TEXT", comment: "")
            }
            
        case "GROUP_MENTIONS_OTHER",
            "GROUP_REPLY_OTHER":
            // TODO: @ 不展示附带文本，因为 body 里有 @ 人信息，不能去重
            if locargs.count >= 3 {
                plainTitle = locargs.first ?? "TempTalk"
                var fromRecipient = locargs[1]
                if !displayName.isEmpty {
                    fromRecipient = displayName
                }
                let atRecipient = locargs[2]
                //                let body = dataMessage.body
                plainBody = "\(fromRecipient) @\(atRecipient)"
            }
        case "GROUP_MENTIONS_ALL":
            //            // TODO: @ 不展示附带文本，因为 body 里有 @ 人信息，不能去重
            if locargs.count >= 2 {
                plainTitle = locargs.first ?? "TempTalk"
                var fromRecipient = locargs[1]
                if !displayName.isEmpty {
                    fromRecipient = displayName
                }
                //                let body = dataMessage.body
                plainBody = "\(fromRecipient) " + Localized("APN_SOMEONE_MENTION_ALL_TEXT", comment: "")
            }
        case "RECALL_MSG",
            "RECALL_MENTIONS_MSG",
            "TASK_MSG",
            "CREATE_TASK",
            "DELETE_TASK",
            "UPDATE_TASK",
            "JOIN_TASK",
            "KICK_OUT_TASK",
            "FOLLOW_TASK",
            "UN_FOLLOW_TASK",
            "TASK_NAME_CHANGE",
            "TASK_DESCRIPTION_CHANGE",
            "TASK_PRIORITY_CHANGE",
            "TASK_DUE_TIME_CHANGE",
            "TASK_ASSIGNEE_CHANGE",
            "TASK_FOLLOW_CHANGE",
            "TASK_STATUS_DONE",
            "TASK_STATUS_REFUSE",
            "TASK_STATUS_RECOVER",
            "TASK_REMIND",
            "TASK_ARCHIVED":
            return false
        default:
            return false
        }
        
        if plainTitle.count > 0 || plainBody.count > 0 {
            configWithNameAndPreview(title: plainTitle, body: plainBody)
            return true
        } else {
            return false
        }
    }
    
    func getContentType(attachmentProto: DSKProtoAttachmentPointer) -> String {
        var attachmentString = Localized("QUOTED_REPLY_TYPE_ATTACHMENT", comment: "")
        
        if let contentType = attachmentProto.contentType {
            if MIMETypeUtil.isAudio(contentType) {
                
                if MIMETypeUtil.isVoiceMessage(attachmentProto) || (TSAttachment.hasFileSource(attachmentProto.fileName)) {
                    attachmentString = Localized("ATTACHMENT_TYPE_VOICE_MESSAGE", comment: "Short text label for a voice message attachment, used for thread preview and on the lock screen")
                } else {
                    attachmentString = Localized("QUOTED_REPLY_TYPE_AUDIO", comment: "")
                }
                
            } else if MIMETypeUtil.isImage(contentType) {
                attachmentString = Localized("QUOTED_REPLY_TYPE_IMAGE", comment: "")
            } else if MIMETypeUtil.isVideo(contentType) {
                attachmentString = Localized("QUOTED_REPLY_TYPE_VIDEO", comment: "")
            } else if MIMETypeUtil.isAnimated(contentType) {
                attachmentString = Localized("QUOTED_REPLY_TYPE_GIF", comment: "")
            } else {
                attachmentString = Localized("QUOTED_REPLY_TYPE_ATTACHMENT", comment: "")
            }
        }
        
        return attachmentString
    }
    
    func getUniversalScheme() -> String {
        
        if TSConstants.appDisplayName.lowercased().contains("cc") {
            return "ccm"
        }
        
        return "wea"
    }
    
}
