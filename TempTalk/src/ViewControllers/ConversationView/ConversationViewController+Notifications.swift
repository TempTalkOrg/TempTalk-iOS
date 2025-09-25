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
            selector: #selector(userTakeScreenshot),
            name: UIApplication.userDidTakeScreenshotNotification,
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
    }
}

// MARK: - Private

@objc
private extension ConversationViewController {
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
        viewState.isViewVisible = isCallWindowHidden
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
    }
    
    func applicationWillResignActive(_ notification: Notification) {
        self.isUserScrolling = false
        self.isWaitingForDeceleration = false
        saveDraft()
        markVisibleMessagesAsRead()
        self.cellMediaCache.removeAllObjects()
        cancelReadTimer()
        dismissPresentedViewControllerIfNecessary()
        
        updateShouldObserveDBModifications()
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        startReadTimer()
        // Invalid update: invalid number of items in section 0. The number of items contained in an existing section after the update (99) must be equal to the number of items contained in that section before the update (96), plus or minus the number of items inserted or deleted from that section (4 inserted, 2 deleted) and plus or minus the number of items moved into or out of that section (0 moved in, 0 moved out).
        /*
        1、A、B私聊互相发送多条消息
        2、A停留在私聊页面锁屏
        3、B继续给A发送多条消息
        4、A点击通知打开锁屏，停留在私聊页面
        5、B继续给A发送一条消息，A crash
         */
//        if (self.viewHasEverAppeared) {
//            [self resetContentAndLayoutWithSneakyTransaction];
//        }
        updateShouldObserveDBModifications()
        reloadAfterAppEnterForegroundIfNeed()
        
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
        databaseStorage.asyncRead { transaction in
            self.thread.anyReload(transaction: transaction)
        } completion: {
            self.checkBotBlock()
            self.checkContactBlock()
            if let conversationEntity = self.thread.conversationEntity, conversationEntity.confidentialMode == TSMessageModeType.confidential {
                self.inputToolbar.inputToolbarState = .confidential
            } else {
                self.inputToolbar.inputToolbarState = .normal
            }
            self.reloadBottomBar()
        }
    }
    
    func saveDraftDidSuccess(_ notification: Notification) {
        loadDraftInCompose()
    }
    
    func groupMessageExpiryConfigChanged(_ notification: Notification) {
        self.updateNavigationTitle()
    }
    
    func sharingConfigurationChanged(_ notification: Notification) {
        self.updateNavigationTitle()
    }
    
    func signalAccountsDidChanged(_ notification: Notification) {
        
        databaseStorage.asyncRead { transaction in
            self.thread.anyReload(transaction: transaction)
        } completion: {
            self.updateNavigationTitle()
            self.updateBarButtonItems()
            if !self.isGroupConversation {
                self.updateNavigationBarSubtitleLabel()
                self.recreateInputToolbar()
                self.reloadBottomBar()
            }
        }
    }
    
    func userTakeScreenshot(_ notification: NSNotification) {
        ThreadUtil.sendScreenShotMessage(in: thread) {} failure: {_ in }
    }
    
    func didChangeContentSizeCategory(_ notification: NSNotification) {
        reloadData()
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
}

@objc
extension NSNotification {
    // 解决 Objective-C 无法直接访问 Notification.Name 的问题
    public static let DTSaveDraftSucess = Notification.Name.DTSaveDraftSucess
}
