//
// Copyright 2020 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import TTMessaging
import TTServiceKit

public class NotificationActionHandler: Dependencies {

    class func handleNotificationResponse( _ response: UNNotificationResponse, completionHandler: @escaping () -> Void) {
        AssertIsOnMainThread()
        firstly {
            try handleNotificationResponse(response)
        }.done {
            completionHandler()
        }.catch { error in
            owsFailDebug("error: \(error)")
            completionHandler()
        }
    }

    private class func handleNotificationResponse( _ response: UNNotificationResponse) throws -> Promise<Void> {
        AssertIsOnMainThread()
        owsAssertDebug(AppReadiness.isAppReady)

        let userInfo = response.notification.request.content.userInfo
        
        let categoryIdentifier = response.notification.request.content.categoryIdentifier
        let action: AppNotificationAction

        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            if categoryIdentifier == AppNotificationCategory.scheduleMeetingWithoutActions.identifier {
                Logger.debug("default action")
                
                action = AppNotificationAction.showScheduledMeetingInfo
                
            } else {
                Logger.debug("default action")
                let defaultActionString = userInfo[AppNotificationUserInfoKey.defaultAction] as? String
                let defaultAction = defaultActionString.flatMap { AppNotificationAction(rawValue: $0) }
                action = defaultAction ?? .showThread
            }
            
           
        case UNNotificationDismissActionIdentifier:
            // TODO - mark as read?
            Logger.debug("dismissed notification")
            return Promise.value(())
        default:
            if let responseAction = UserNotificationConfig.action(identifier: response.actionIdentifier) {
                action = responseAction
            } else {
                throw OWSAssertionError("unable to find action for actionIdentifier: \(response.actionIdentifier)")
            }
        }

        if DebugFlags.internalLogging {
            Logger.info("Performing action: \(action)")
        }

        switch action {
        case .reply:
            guard let textInputResponse = response as? UNTextInputNotificationResponse else {
                throw OWSAssertionError("response had unexpected type: \(response)")
            }

            return try reply(userInfo: userInfo, replyText: textInputResponse.userText)
        case .showThread:
            return try showThread(userInfo: userInfo)
        case .showScheduledMeetingInfo:
            return try showScheduledMeetingInfo(userInfo: userInfo)
        }
    }

    private class func markAsRead(userInfo: [AnyHashable: Any]) throws -> Promise<Void> {
        return firstly {
            self.notificationMessage(forUserInfo: userInfo)
        }.then(on: DispatchQueue.global()) { (notificationMessage: NotificationMessage) in
            self.markMessageAsRead(notificationMessage: notificationMessage)
        }
    }

    private class func reply(userInfo: [AnyHashable: Any], replyText: String) throws -> Promise<Void> {
        return firstly { () -> Promise<NotificationMessage> in
            self.notificationMessage(forUserInfo: userInfo)
        }.then(on: DispatchQueue.global()) { (notificationMessage: NotificationMessage) -> Promise<Void> in
            let thread = notificationMessage.thread
            return firstly(on: DispatchQueue.global()) { () -> Promise<Void> in
               
                return Promise { seal in
                      self.databaseStorage.asyncWrite(block: { transaction in
                          let outgoingMessage = TSOutgoingMessage(in: notificationMessage.thread, messageBody: replyText, atPersons: nil, mentions: nil, attachmentId: nil)
                          self.messageSender.enqueue(outgoingMessage, success: {
                              seal.resolve()
                          }, failure: { error in
                              seal.reject(error)
                          })
                      })
                  }
            }.recover(on: DispatchQueue.global()) { error -> Promise<Void> in
                Logger.warn("Failed to send reply message from notification with error: \(error)")
                self.notificationPresenter.notifyForFailedSend(inThread: thread)
                throw error
            }.then(on: DispatchQueue.global()) { () -> Promise<Void> in
                self.markMessageAsRead(notificationMessage: notificationMessage)
            }
        }
    }

    private class func showThread(userInfo: [AnyHashable: Any]) throws -> Promise<Void> {
        return firstly { () -> Promise<NotificationMessage> in
            self.notificationMessage(forUserInfo: userInfo)
        }.done(on: DispatchQueue.main) { notificationMessage in
            if notificationMessage.isGroupStoryReply {
                self.showGroupStoryReplyThread(notificationMessage: notificationMessage)
            } else {
                self.showThread(notificationMessage: notificationMessage)
            }
        }
    }

    private class func showThread(notificationMessage: NotificationMessage) {
        // If this happens when the app is not visible we skip the animation so the thread
        // can be visible to the user immediately upon opening the app, rather than having to watch
        // it animate in from the homescreen.
            let thread = notificationMessage.thread
            SignalApp.shared().presentTargetConversation(for: thread, action:.none, focusMessageId: nil)
        
    }
    
    private class func showScheduledMeetingInfo(userInfo: [AnyHashable: Any]) throws -> Promise<Void> {
        return firstly { () -> Promise<DTListMeeting> in
            firstly(on: DispatchQueue.global()) { () throws -> DTListMeeting in
                return try MTLJSONAdapter.model(of: DTListMeeting.self, fromJSONDictionary: userInfo) as! DTListMeeting
            }
        }.done(on: DispatchQueue.main) { event in
            presentEventDetail(event)
        }
    }
    
    class func presentEventDetail(_ event: DTListMeeting) {
        
        if let channelName = event.channelName, !channelName.isEmpty, !event.isLiveStream || (event.isLiveStream && event.role != MeetingAttendeeRole.audience.rawValue) {
            
            let now = Date().timeIntervalSince1970
            guard now - event.start < 70 else {
                Logger.info("click meeting popups late: \(event.topic), \(channelName)")
                return
            }
            // 会议预约唤醒方法
            return
        }
            
        let topWindow = OWSWindowManager.shared().getToastSuitableWindow()
        if topWindow.windowLevel == UIWindowLevel_CallView() {
//            DTMultiCallManager.shared().showToast("Unable to view schedule details when you on a call")
            return
        }
        
    }


    private class func showGroupStoryReplyThread(notificationMessage: NotificationMessage) {
//        guard notificationMessage.isGroupStoryReply, let storyMessage = notificationMessage.storyMessage else {
//            return owsFailDebug("Unexpectedly missing story message")
//        }
//
//        guard let frontmostViewController = CurrentAppContext().frontmostViewController() else { return }
//
//        if let replySheet = frontmostViewController as? StoryGroupReplier {
//            if replySheet.storyMessage.uniqueId == storyMessage.uniqueId {
//                return // we're already in the right place
//            } else {
//                // we need to drop the viewer before we present the new viewer
//                replySheet.presentingViewController?.dismiss(animated: false) {
//                    showGroupStoryReplyThread(notificationMessage: notificationMessage)
//                }
//                return
//            }
//        } else if let storyPageViewController = frontmostViewController as? StoryPageViewController {
//            if storyPageViewController.currentMessage?.uniqueId == storyMessage.uniqueId {
//                // we're in the right place, just pop the replies sheet
//                storyPageViewController.currentContextViewController.presentRepliesAndViewsSheet()
//                return
//            } else {
//                // we need to drop the viewer before we present the new viewer
//                storyPageViewController.dismiss(animated: false) {
//                    showGroupStoryReplyThread(notificationMessage: notificationMessage)
//                }
//                return
//            }
//        }
//
//        let vc = StoryPageViewController(
//            context: storyMessage.context,
//            // Fresh state when coming in from a notification; no need to share.
//            spoilerState: SpoilerRenderState(),
//            loadMessage: storyMessage,
//            action: .presentReplies
//        )
//        frontmostViewController.present(vc, animated: true)
    }

    private struct NotificationMessage {
        let thread: TSThread
        let interaction: TSInteraction?
        let isGroupStoryReply: Bool
        let hasPendingMessageRequest: Bool
    }

    private class func notificationMessage(forUserInfo userInfo: [AnyHashable: Any]) -> Promise<NotificationMessage> {
            firstly(on: DispatchQueue.global()) { () throws -> NotificationMessage in
                let apnsInfo = self.apnsInfo(userInfo: userInfo)
                guard let threadId = apnsInfo?.conversationId else {
                    throw OWSAssertionError("threadId was unexpectedly nil")
                }
                
                return try self.databaseStorage.read(block: { transaction in
                    
                    var thread : TSThread?
                    if (threadId.hasPrefix("+")) {
                        
                        let uniqueIdentifier = TSContactThread.threadId(fromContactId: threadId)
                        thread = TSContactThread.anyFetchContactThread(uniqueId: uniqueIdentifier, transaction: transaction)
                        
                    } else {
                        
                        let groupId = NSData(fromBase64String: threadId)
                        guard let groupId = groupId else {
                            throw OWSAssertionError("Failed to get groupId: \(String(describing: groupId))")
                        }
                        
                        thread = TSGroupThread(groupId: groupId as Data, transaction: transaction)
                    }
                    
                    guard  let thread = thread else {
                        throw OWSAssertionError("Failed to get or create thread with threadId: \(threadId)")
                    }
                    
                    let hasPendingMessageRequest = false

                    return NotificationMessage(
                        thread: thread,
                        interaction: nil,
                        isGroupStoryReply: false,
                        hasPendingMessageRequest: hasPendingMessageRequest
                    )
                })
            }
    }
    //TODO: Follow up optimization based on requirements to see if this feature is needed
    private class func markMessageAsRead(notificationMessage: NotificationMessage) -> Promise<Void> {
//        guard notificationMessage.interaction != nil else {
//            return Promise(error: OWSAssertionError("missing interaction"))
//        }
        let (promise, _) = Promise<Void>.pending()
//        self.receiptManager.markAsReadLocally(
//            beforeSortId: interaction.sortId,
//            thread: notificationMessage.thread,
//            hasPendingMessageRequest: notificationMessage.hasPendingMessageRequest
//        ) {
//            future.resolve()
//        }
        return promise
    }
    
    private class func apnsInfo(userInfo: [AnyHashable: Any]?) -> DTApnsInfo? {
            guard let userInfo = userInfo else {
                Logger.error("Error: no userInfo")
                return nil
            }
            
            do {
                let apnsInfo = try MTLJSONAdapter.model(of: DTApnsInfo.self, fromJSONDictionary: userInfo)
                return apnsInfo as? DTApnsInfo
            } catch {
                Logger.error("Error constructing apnsInfo: \(error)")
                return nil
            }
        }
}
