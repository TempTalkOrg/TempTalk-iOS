//
//  ConversationViewController+Notifications.swift
//  Signal
//
//  Created by Jaymin on 2024/1/26.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit

// MARK: - Public

@objc
extension ConversationViewController {
    func registerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(videoPlayerWillStartPlaying),
            name: OWSVideoPlayer.willStartPlayingNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowManagerCallDidChange),
            name: .OWSWindowManagerCallDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(identityStateDidChange),
            name: .DTIdentityStateDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didChangePreferredContentSize),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillEnterForeground),
            name: .OWSApplicationWillEnterForeground,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: .OWSApplicationDidEnterBackground,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: .OWSApplicationWillResignActive,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: .OWSApplicationDidBecomeActive,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(otherUsersProfileDidChange),
            name: .DTOtherUsersProfileDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(conversationSettingDidChange),
            name: .DTConversationDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(conversationSettingDidChange),
            name: .DTConversationUpdateFromSocketMessage,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(saveDraftDidSuccess),
            name: .DTSaveDraftSucess,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(groupMessageExpiryConfigChanged),
            name: .DTGroupMessageExpiryConfigChanged,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sharingConfigurationChanged),
            name: .DTConversationSharingConfigurationChange,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(signalAccountsDidChanged),
            name: .OWSContactsManagerSignalAccountsDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didChangeContentSizeCategory),
            name: UIContentSizeCategory.didChangeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didChangeRefreshJoinBarStatus),
            name: .DTRefreshJoinBarStatusChange,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textSizeDidChange),
            name: .textSizeDidChange,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(groupCryptoKeyDidArrive(_:)),
            name: DTGroupCryptoConstants.groupCryptoKeyDidArriveNotification,
            object: nil
        )
    }

    func registerScreenshotObserver() {
        // viewIsAppearing fires on every appearance (e.g. returning from image viewer);
        // remove any existing observer first to avoid stacking duplicates.
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userTakeScreenshot(_:)),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
    }
}

// MARK: - Private

@objc
private extension ConversationViewController {
    func videoPlayerWillStartPlaying(_ notification: Notification) {
        pauseAudioPlayer()
    }

    func windowManagerCallDidChange(_ notification: Notification) {
        updateBarButtonItems()
        
        guard let userInfo = notification.userInfo else {
            return
        }
        guard (tabBarController?.selectedIndex ?? 0) == 0 else {
            return
        }
        guard let visibleViewController = navigationController?.visibleViewController, visibleViewController === self else {
            return
        }
        let isCallWindowHidden = userInfo["isCallWindowHidden"] as? Bool ?? false
        // self.isViewVisible = isCallWindowHidden
        // Ethan: fix 1on1 call crash after hangup
        Logger.info("[Conversation] call window isCallWindowHidden is \(isCallWindowHidden)")
        viewState.isViewVisible = isCallWindowHidden

        // Mark that we're returning from call window to prevent auto-scroll in layoutDidUpdateWhenViewWillAppear
        if isCallWindowHidden {
            isReturningFromCallWindow = true
        }

        // Fix keyboard layout issue when returning from call window
        // The keyboard frame may have changed during orientation changes in call view
        // and InputAccessoryViewPlaceholder may not have received proper keyboard notifications
        if isCallWindowHidden && viewHasEverAppeared {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                // Sync keyboard state first
                self.inputAccessoryPlaceholder.syncKeyboardState()

                // Force update the keyboard layout
                self.updateInputAccessoryPlaceholderHeight()
                self.updateBottomBarPosition()
                self.updateContentInsets(animated: false, allowAutoScroll: false)

                // If keyboard is visible, ensure proper positioning
                if self.inputToolbar.isInputViewFirstResponder {
                    // Small delay to ensure keyboard frame is stable after window transition
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        guard let self = self else { return }
                        self.updateBottomBarPosition()
                        self.updateContentInsets(animated: false, allowAutoScroll: false)
                    }
                }
            }
        }
    }
    
    func identityStateDidChange(_ notification: Notification) {
        AssertIsOnMainThread()
        
        updateNavigationBarSubtitleLabel()
    }
    
    /// Called whenever the user manually changes the dynamic type options inside Settings.
    func didChangePreferredContentSize(_ notification: Notification) {
        OWSLogger.info("didChangePreferredContentSize")
        
        self.inputToolbar.updateFontSizes()
    }
    
    func applicationWillEnterForeground(_ notification: Notification) {
        startReadTimer()
        updateCellsVisible()
        
        // Prepare keyboard state sync before app becomes active
        if viewHasEverAppeared {
            inputAccessoryPlaceholder.syncKeyboardState()
        }
    }
    
    func applicationDidEnterBackground(_ notification: Notification) {
        cancelReadTimer()
        updateCellsVisible()
        self.cellMediaCache.removeAllObjects()
        viewState.wasInputToolbarFirstResponderBeforeResignActive = false
    }
    
    func applicationWillResignActive(_ notification: Notification) {
        self.isUserScrolling = false
        self.isWaitingForDeceleration = false
        viewState.wasInputToolbarFirstResponderBeforeResignActive = inputToolbar.isInputViewFirstResponder
        saveDraft()
        markVisibleMessagesAsRead()
        self.cellMediaCache.removeAllObjects()
        cancelReadTimer()
        dismissPresentedViewControllerIfNecessary()
        
        updateShouldObserveDBModifications()
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        startReadTimer()
        updateShouldObserveDBModifications()
        reloadAfterAppEnterForegroundIfNeed()
        
        if viewHasEverAppeared, viewState.wasInputToolbarFirstResponderBeforeResignActive {
            viewState.wasInputToolbarFirstResponderBeforeResignActive = false
            Logger.info("[Keyboard] applicationDidBecomeActive: restoring keyboard after resign-active")
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isViewVisible else { return }
                self.inputToolbar.beginEditingMessage()
            }
        }

        // Fix keyboard layout issues when returning from background
        // The keyboard state might not sync properly between background/foreground transitions
        if viewHasEverAppeared {
            DispatchQueue.main.async { [weak self] in
                self?.fixKeyboardLayoutAfterForeground()
            }
        }
    }
    
    func otherUsersProfileDidChange(_ notification: Notification) {
        AssertIsOnMainThread()
        
        guard let recipientId = notification.userInfo?[kNSNotificationKey_ProfileRecipientId] as? String, !recipientId.isEmpty else {
            return
        }
        guard self.thread.recipientIdentifiers.contains(recipientId) else {
            return
        }
        if self.thread.isKind(of: TSContactThread.self) {
            updateNavigationTitle()
        }
        if self.isGroupConversation {
            // Reload all cells if this is a group conversation,
            // since we may need to update the sender names on the messages.
            resetContentAndLayoutWithSneakyTransaction()
        }
    }
    
    func conversationSettingDidChange(_ notification: Notification) {
        AssertIsOnMainThread()
        databaseStorage.uiRead { transaction in
            self.thread.anyReload(transaction: transaction)
        }
        self.checkBotBlock()
        self.safeUpdateBlockStatus()
        if let conversationEntity = self.thread.conversationEntity, conversationEntity.confidentialMode == TSMessageModeType.confidential {
            self.inputToolbar.inputToolbarState = .confidential
        } else {
            self.inputToolbar.inputToolbarState = .normal
        }
        self.reloadBottomBar()

        // Check and update confidential message availability when conversation settings change
        // This handles group member changes (join/leave)
        self.checkAndUpdateConfidentialMessageAvailability()
    }
    
    func saveDraftDidSuccess(_ notification: Notification) {
        guard !isUserActivelyTyping else {
            Logger.info("[Keyboard] saveDraftDidSuccess skipped: user is typing")
            return
        }
        loadDraftInCompose()
    }
    
    func groupMessageExpiryConfigChanged(_ notification: Notification) {
        self.updateNavigationTitle()
    }
    
    func sharingConfigurationChanged(_ notification: Notification) {
        self.updateNavigationTitle()
    }
    
    func signalAccountsDidChanged(_ notification: Notification) {
        AssertIsOnMainThread()
        databaseStorage.uiRead { transaction in
            self.thread.anyReload(transaction: transaction)
        }
        self.updateNavigationTitle()
        self.updateBarButtonItems()

        if !self.isGroupConversation {
            self.updateNavigationBarSubtitleLabel()
            if self.isUserActivelyTyping {
                Logger.info("[Keyboard] signalAccountsDidChanged: skipping recreateInputToolbar (user is typing)")
                self.viewState.needsInputToolbarRecreation = true
            } else {
                Logger.info("[Keyboard] signalAccountsDidChanged → recreateInputToolbar")
                self.recreateInputToolbar()
                self.reloadBottomBar()
            }
        }

        self.resetContentAndLayoutWithSneakyTransaction()
    }
    
    func userTakeScreenshot(_ notification: NSNotification) {
        // Don't send screenshot message if screen lock is showing
        guard !OWSScreenLockUI.sharedManager().isShowingScreenLockUI else {
            Logger.info("[Conversation] Screenshot taken while screen lock is showing, ignoring")
            return
        }

        var targetThread = thread
        let currentCall = DTMeetingManager.shared.currentCall

        if DTMeetingManager.shared.hasMeeting,
           !DTMeetingManager.shared.isMinimize,  // ✅ 添加小窗模式检查
           let conversationId = currentCall.conversationId,
           !conversationId.isEmpty {

            if currentCall.callType == .private || currentCall.callType == .group {
                Logger.info("[Conversation] Active call in full screen (not minimized) detected, redirecting screenshot to call conversation")

                databaseStorage.write { transaction in
                    if currentCall.callType == .private {
                        if let contactThread = TSContactThread.getThread(contactId: conversationId, transaction: transaction) {
                            targetThread = contactThread
                            Logger.info("[Conversation] Redirecting screenshot to private call thread: \(conversationId)")
                        }
                    } else if currentCall.callType == .group {
                        if let localGroupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: conversationId),
                           let groupThread = TSGroupThread.getWithGroupId(localGroupId, transaction: transaction) {
                            targetThread = groupThread
                            Logger.info("[Conversation] Redirecting screenshot to group call thread: \(conversationId)")
                        }
                    }
                }
            }
        } else if DTMeetingManager.shared.hasMeeting && DTMeetingManager.shared.isMinimize {
            Logger.info("[Conversation] Call is minimized, screenshot will be sent to current conversation: \(thread.uniqueId)")
        }

        ThreadUtil.sendScreenShotMessage(in: targetThread) {} failure: {_ in }
    }
    
    func didChangeContentSizeCategory(_ notification: NSNotification) {
        reloadData()
    }

    func textSizeDidChange(_ notification: NSNotification) {
        reloadData()
    }

    func groupCryptoKeyDidArrive(_ notification: Notification) {
        guard let gid = notification.userInfo?[DTGroupCryptoConstants.groupCryptoKeyGidKey] as? String,
              !gid.isEmpty,
              let groupThread = thread as? TSGroupThread,
              groupThread.serverThreadId == gid else { return }
        updateNavigationTitle()
    }

}

// MARK: - Private

private extension ConversationViewController {
    func dismissPresentedViewControllerIfNecessary() {
        guard let presentedViewController else {
            OWSLogger.debug("presentedViewController was nil")
            return
        }
        if presentedViewController.isKind(of: ActionSheetController.self) || presentedViewController.isKind(of: UIAlertController.self) {
            dismiss(animated: false)
        }
    }
}

extension Notification.Name {
    public static let DTIdentityStateDidChange = Notification.Name(kNSNotificationName_IdentityStateDidChange)

    public static let DTOtherUsersProfileDidChange = Notification.Name(kNSNotificationName_OtherUsersProfileDidChange)

    public static let DTConversationDidChange = Notification.Name("kConversationDidChangeNotification")

    public static let DTConversationUpdateFromSocketMessage = Notification.Name("kConversationUpdateFromSocketMessageNotification")

    public static let DTSaveDraftSucess = Notification.Name("DTSaveDraftSucessNotification")

    public static let DTRefreshJoinBarStatusChange = Notification.Name("DTRefreshJoinBarStatusChangeNotification")

    // 会话共享配置变更通知（消息过期时间等）
    public static let DTConversationSharingConfigurationChange = Notification.Name("kDTconversationSharingConfigurationChangeNotification")

    // 群组消息过期配置变更通知
    public static let DTGroupMessageExpiryConfigChanged = Notification.Name("kDTGroupMessageExpiryConfigChangedNotification")
}

@objc
extension NSNotification {
    // 解决 Objective-C 无法直接访问 Notification.Name 的问题
    public static let DTSaveDraftSucess = Notification.Name.DTSaveDraftSucess
}
