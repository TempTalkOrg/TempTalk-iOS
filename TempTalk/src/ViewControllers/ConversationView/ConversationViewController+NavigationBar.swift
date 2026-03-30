//
//  ConversationViewController+NavigationBar.swift
//  Signal
//
//  Created by Jaymin on 2024/2/3.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

// MARK: - HeaderView

@objc
extension ConversationViewController: ConversationHeaderViewDelegate {
    var headerView: ConversationHeaderView {
        if let view = viewState.headerView {
            return view
        }
        let newView = ConversationHeaderView(
            thread: self.thread,
            contactsManager: self.contactsManager
        )
        newView.delegate = self
        newView.accessibilityIdentifier = "headerView"
        viewState.headerView = newView
        return newView
    }
    
    func createHeaderViews() {
        navigationItem.titleView = headerView

        // 如果是从PersonalCard浮动窗口打开，始终使用headerView
        if isFromPersonalCard {
            navigationItem.titleView = headerView
        } else if let _ = navigationController?.presentingViewController, navigationController?.viewControllers.count == 1 {
            navigationItem.titleView = nil
            var threadName: String?
            databaseStorage.read { [weak self] transaction in
                guard let self else { return }
                threadName = self.thread.name(with: transaction)
            }
            navigationItem.title = threadName
        } else {
            navigationItem.titleView = headerView
        }
        
        #if DEBUG
        headerView.addGestureRecognizer(UILongPressGestureRecognizer(
            target: self,
            action: #selector(navigationTitleLongPressed(_:)))
        )
        #endif
        
        updateNavigationBarSubtitleLabel()
    }
    
    public func didTapConversationHeaderView(_ conversationHeaderView: ConversationHeaderView) {
        if isGroupConversation {
            guard !isUserLeftGroup else { return }
            showConversationSettings()
        } else {
            if isFriend {
                showConversationSettings()
            }
        }
    }
    
    #if DEBUG
    private func navigationTitleLongPressed(_ sender: UIGestureRecognizer) {
        if sender.state == .began {
            let text = ""
            sendCardMessage(text: text, thread: self.thread)
        }
    }
    
    private func sendCardMessage(text: String, thread: TSThread) {
        let message = DTHyperlinkOutgoingMessage.outgoingHyperlinkMessage(
            withText: text,
            thread: thread
        )
        messageSender.enqueue(message) {
            Logger.info("Successfully sent message.")
        } failure: { error in
            Logger.warn("Failed to deliver message with error: \(error)")
        }
    }
    #endif
}

// MARK: - BarButtons

@objc
extension ConversationViewController {
    var threadBackButton: UIBarButtonItem {
        if let button = viewState.threadBackButton {
            return button
        }
        let closeButton = UIButton(type: .custom)
        closeButton.tintColor = Theme.iconColor
        let closeImage = UIImage(named: "nav_bar_close")?.withRenderingMode(.alwaysTemplate)
        closeButton.setImage(closeImage, for: .normal)
        closeButton.addTarget(self, action: #selector(dismissConversationButtonClick), for: .touchUpInside)

        // 设置图片向左偏移，并扩大点击区域到 44x44
        closeButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -12, bottom: 0, right: 12)
        closeButton.frame = CGRect(x: 0, y: 0, width: 36, height: 44)

        let newButton = UIBarButtonItem(customView: closeButton)
        viewState.threadBackButton = newButton
        return newButton
    }

    // 半屏状态的返回按钮（< 样式）
    var threadPopBackButton: UIBarButtonItem {
        if let button = viewState.threadPopBackButton {
            return button
        }
        let backButton = UIButton(type: .custom)
        backButton.tintColor = Theme.iconColor
        let backImage = UIImage(named: "NavBarBack")?.withRenderingMode(.alwaysTemplate)
        backButton.setImage(backImage, for: .normal)
        backButton.addTarget(self, action: #selector(popConversationButtonClick), for: .touchUpInside)
        backButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -12, bottom: 0, right: 12)
        backButton.frame = CGRect(x: 0, y: 0, width: 36, height: 44)

        let newButton = UIBarButtonItem(customView: backButton)
        viewState.threadPopBackButton = newButton
        return newButton
    }
    
    var quickGroupBtn: UIBarButtonItem {
        if let button = viewState.quickGroupBtn {
            return button
        }
        let quickGroupBtn = UIButton(type: .custom)
        quickGroupBtn.tintColor = Theme.iconColor
        quickGroupBtn.setImage(UIImage(named: "quick_group")?.withRenderingMode(UIImage.RenderingMode.alwaysTemplate), for: .normal)
        quickGroupBtn.addTarget(self, action: #selector(self.quickGroupAction), for: .touchUpInside)
        quickGroupBtn.frame = CGRectMake(0, 0, 19, 19)
        let barButtonItem = UIBarButtonItem.init(customView: quickGroupBtn)
        viewState.quickGroupBtn = barButtonItem
        return barButtonItem
    }
    
    var askFriendBtn: UIBarButtonItem {
        if let button = viewState.askFriendBtn {
            return button
        }
        let askFriendBtn = UIButton(type: .custom)
        askFriendBtn.tintColor = Theme.iconColor
        askFriendBtn.setImage(UIImage(named: "ask_friend")?.withRenderingMode(UIImage.RenderingMode.alwaysTemplate), for: .normal)
        askFriendBtn.addTarget(self, action: #selector(self.askFriendAction), for: .touchUpInside)
        askFriendBtn.frame = CGRectMake(0, 0, 19, 19)
        let barButtonItem = UIBarButtonItem.init(customView: askFriendBtn)
        viewState.askFriendBtn = barButtonItem
        return barButtonItem
    }
    
    private func createCallBarButtonItem() -> UIBarButtonItem {
        // We use UIButtons with [UIBarButtonItem initWithCustomView:...] instead of
        // UIBarButtonItem in order to ensure that these buttons are spaced tightly.
        // The contents of the navigation bar are cramped in this view.
        let callButton = UIButton(type: .custom)
        callButton.tintColor = Theme.iconColor
        let callImage = UIImage(named: "user_voice_call")?.withRenderingMode(.alwaysTemplate)
        callButton.setImage(callImage, for: .normal)
        callButton.accessibilityLabel = Localized("CALL_LABEL")
        callButton.addTarget(self, action: #selector(startCallAction), for: .touchUpInside)
        
        callButton.isEnabled = true
        callButton.isUserInteractionEnabled = true
        
        // We normally would want to use left and right insets that ensure the button
        // is square and the icon is centered.  However UINavigationBar doesn't offer us
        // control over the margins and spacing of its content, and the buttons end up
        // too far apart and too far from the edge of the screen. So we use a smaller
        // right inset tighten up the layout.
        var imageEdgeInsets: UIEdgeInsets = .zero
        let imageWidth: CGFloat = callImage?.size.width ?? .zero
        let imageHeight: CGFloat = callImage?.size.height ?? .zero
        let hasCompactHeader = traitCollection.verticalSizeClass == .compact
        if !hasCompactHeader {
            let kBarButtonSize: CGFloat = 44
            imageEdgeInsets.left = round((kBarButtonSize - imageWidth) * 0.5)
            imageEdgeInsets.right = round((kBarButtonSize - (imageWidth + imageEdgeInsets.left)) * 0.5)
            imageEdgeInsets.top = round((kBarButtonSize - imageHeight) * 0.5)
            imageEdgeInsets.bottom = round(kBarButtonSize - (imageHeight + imageEdgeInsets.top))
        }
        callButton.imageEdgeInsets = imageEdgeInsets
        let callButtonWidth = round(imageWidth + imageEdgeInsets.left + imageEdgeInsets.right)
        let callButtonHeight = round(imageHeight + imageEdgeInsets.top + imageEdgeInsets.bottom)
        callButton.frame = CGRectMake(0, 0, callButtonWidth, callButtonHeight)
        
        let callBarButtonItem = UIBarButtonItem(customView: callButton, accessibilityIdentifier: "call")
        return callBarButtonItem
    }

    
    func updateNavigationTitle() {
        func titleForContactThread(_ thread: TSContactThread) -> (title: NSAttributedString?, isBot: Bool) {
            if thread.isNoteToSelf {
                headerView.isExternal = false
                return (NSAttributedString(
                    string: MessageStrings.noteToSelf(),
                    attributes: [.foregroundColor: Theme.tprimaryColor]
                ), false)
            }

            let contactIdentifier = thread.contactIdentifier()
            var attributedName: NSAttributedString?
            var account: SignalAccount?
            databaseStorage.read { transaction in
                attributedName = self.contactsManager.attributedContactOrProfileName(
                    forPhoneIdentifier: contactIdentifier,
                    primaryFont: self.headerView.titlePrimaryFont,
                    secondaryFont: self.headerView.titleSecondaryFont,
                    transaction: transaction
                )
                account = self.contactsManager.signalAccount(forRecipientId: contactIdentifier, transaction: transaction)
                self.thread.anyReload(transaction: transaction)
            }
            let isBot = account?.isBot() ?? false
            headerView.isExternal = SignalAccount.isExt(contactIdentifier)
            return (attributedName, isBot)
        }

        func titleForGroupThread(_ thread: TSGroupThread) -> NSAttributedString? {
            var groupThread: TSGroupThread?
            databaseStorage.read { transaction in
                groupThread = TSGroupThread.anyFetchGroupThread(
                    uniqueId: thread.uniqueId,
                    transaction: transaction
                )
                self.thread.anyReload(transaction: transaction)
                Logger.info("[Conversation] current groupThread threadId is \(groupThread?.uniqueId) current thread \(self.thread.uniqueId)")
            }
            guard let groupThread else {
                Logger.error("[Conversation] current groupThread is empty")
                return nil
            }

            headerView.isExternal = false

            return NSAttributedString(
                string: groupThread.groupThreadNameWithMemberCount(),
                attributes: [.foregroundColor: Theme.tprimaryColor]
            )
        }


        if let groupThread = self.thread as? TSGroupThread, viewState.conversationViewMode == .normalPresent {

            self.title = groupThread.name(with: nil)
            return
        }

        let attributedTitle: NSAttributedString? = {

            var title: NSAttributedString?
            var isBot = false
            if let contractThread = self.thread as? TSContactThread {
                let result = titleForContactThread(contractThread)
                title = result.title
                isBot = result.isBot
                Logger.info("[Conversation] contactThread theadName \(title)")
            } else if let groupThread = self.thread as? TSGroupThread {
                title = titleForGroupThread(groupThread)
                Logger.info("[Conversation] groupThread theadName \(title)")
            } else {
                Logger.error("[Conversation] failure: unexpected thread: \(self.thread)")
            }

            guard let currentTitle = title else { return nil }

            // Add bot icon if needed (even without expiry time)
            if isBot {
                title = currentTitle.appendingBotIcon(font: headerView.titlePrimaryFont)
            }

            // Add expiry time if needed
            if thread.messageExpiresInSeconds() > 0, let titleWithIcon = title {
                title = DTConversactionSettingUtils.msgDisappearingTipsOnThread(messageExpiry: TimeInterval(thread.messageExpiresInSeconds()), threadName: titleWithIcon, font: headerView.titlePrimaryFont)
            }

            return title
        }()

        // Ensure UI updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.title = nil
            // Force update to ensure UI refresh when contact name changes
            self.headerView.attributedTitle = attributedTitle
        }
    }
    
    // 更新子标题的数据
    func updateNavigationBarSubtitleLabel() {
        let hasCompactHeader = traitCollection.verticalSizeClass == .compact
        if hasCompactHeader {
            headerView.attributedSubtitle = nil
            return
        }
        
        let subtitle: String = {
            guard !isUserLeftGroup else {
                return Localized("GROUP_YOU_LEFT")
            }
            
            return ""
        }()
        
        let subtitleColor = Theme.tprimaryColor.withAlphaComponent(0.9)
        let attributedTitle = NSAttributedString(
            string: subtitle,
            attributes: [.font: headerView.subtitleFont, .foregroundColor: subtitleColor]
        )
        headerView.attributedSubtitle = attributedTitle
    }
    
    func updateBarButtonItems() {
        navigationItem.hidesBackButton = false

        if isMultiSelectMode {
            navigationItem.leftBarButtonItem = cancelMultiButton
            navigationItem.rightBarButtonItems = []
            return
        }

        // If from personal card and in compact mode (50%), show close button (X)
        if isFromPersonalCard && floatingWindowIsCompactMode {
            navigationItem.leftBarButtonItem = threadBackButton
            navigationItem.rightBarButtonItems = [createFullScreenBarButtonItem()]
            return
        }

        // If from personal card and in expanded mode (90%), show close button (X)
        if isFromPersonalCard && !floatingWindowIsCompactMode && !isFullScreenMode {
            navigationItem.leftBarButtonItem = threadBackButton
            navigationItem.rightBarButtonItems = [createFullScreenBarButtonItem()]
            return
        }

        // If from personal card and in fullscreen mode (100%), show back arrow button (<) + normal right buttons
        if isFromPersonalCard && isFullScreenMode {
            navigationItem.leftBarButtonItem = threadPopBackButton
            setupNormalRightBarButtonItems()
            return
        }

        // Set left bar button based on conversation view mode
        if conversationViewMode == .normalPresent {
            navigationItem.leftBarButtonItem = threadBackButton
        } else {
            navigationItem.leftBarButtonItem = navigationItem.backBarButtonItem
        }

        if isUserLeftGroup {
            navigationItem.rightBarButtonItems = []
            return
        }

        setupNormalRightBarButtonItems()
    }

    // 设置正常的右侧按钮（通话、建群等）
    private func setupNormalRightBarButtonItems() {
        let showFriendAction = isFriend && !isBot && !thread.isNoteToSelf
        var barBtnItems: [UIBarButtonItem] = []

        // 先添加快速建群/添加群组按钮
        if let groupThread = self.thread as? TSGroupThread,
           GroupPermissions.hasPermissionToAddGroupMembers(groupModel: groupThread.groupModel) {
            barBtnItems.append(quickGroupBtn)
        } else if !self.thread.isGroupThread() && showFriendAction {
            barBtnItems.append(quickGroupBtn)
        } else if !self.thread.isGroupThread() && !self.isFriend {
            barBtnItems.append(askFriendBtn)
        }

        // 再添加通话/发起会议按钮
        if thread.isGroupThread() ||
            showFriendAction {
            barBtnItems.append(createCallBarButtonItem())
        }

        self.navigationItem.rightBarButtonItems = barBtnItems

    }
    
    func updateLeftBarItem() {
        // We use the default back button from conversation list, which animates nicely with interactive transitions
        // like the interactive pop gesture and the "slide left" for info.
        navigationItem.leftBarButtonItem = nil
    }
    
    func dismissConversationButtonClick() {
        view.endEditing(true)

        // 如果是从PersonalCard打开的
        if isFromPersonalCard {
            // 50% compact模式和90% expanded模式都使用从上往下的present风格dismiss
            if let navController = navigationController,
               let floatingVC = navController.parent as? FloatingConversationViewController {
                floatingVC.dismiss(animated: true)
            } else {
                navigationController?.dismiss(animated: true)
            }
        } else {
            navigationController?.dismiss(animated: true)
        }
    }

    // 从浮动模式返回Home（退出浮动窗口，直接回到HomeViewController）
    private func navigateToNormalConversation() {
        // 使用push风格dismiss浮动窗口，直接返回HomeViewController
        if let navController = navigationController,
           let floatingVC = navController.parent as? FloatingConversationViewController {
            floatingVC.dismissWithPushStyleAndReturnToHome()
        }
    }

    // 100%全屏模式或其他模式的返回按钮点击事件
    @objc
    func popConversationButtonClick() {
        view.endEditing(true)

        // 100%全屏模式：直接返回HomeViewController
        if isFullScreenMode {
            navigateToNormalConversation()
            return
        }

        // 其他情况：不应该执行到这里，因为100%全屏时才使用threadPopBackButton
        if let navController = navigationController,
           let floatingVC = navController.parent as? FloatingConversationViewController {
            floatingVC.dismissWithPopStyle()
        } else {
            navigationController?.dismiss(animated: true)
        }
    }

    func quickGroupAction() {
        if self.thread.isGroupThread() {
            if let groupThread = self.thread as? TSGroupThread, GroupPermissions.hasPermissionToAddGroupMembers(groupModel: groupThread.groupModel) {
                let addToGroupVC = AddToGroupViewController()
                addToGroupVC.thread = groupThread
                addToGroupVC.conversationSettingsViewDelegate = self
                self.navigationController?.pushViewController(addToGroupVC, animated: true)
            }
        } else {
            let newGroupVC = NewGroupViewController()
            newGroupVC.createType = .contact
            newGroupVC.thread = self.thread
            self.navigationController?.pushViewController(newGroupVC, animated: true)
        }
    }
    
    func askFriendAction() {
        guard let contactThread = self.thread as? TSContactThread else {
            return
        }
        AddFriendHandler.handleRequestAddFriend(identifier: contactThread.contactIdentifier(),
                                                sourceType: .unknow,
                                                sourceConversationID: nil,
                                                shareContactCardUId: nil,
                                                action: nil,
                                                failure:  { errorString in
            OWSLogger.error("ask friend error in conversation: \(errorString)")
        })
    }
    
    func startCallAction() {
        didTapCallNavBtn()
    }

    private func createFullScreenBarButtonItem() -> UIBarButtonItem {
        let button = UIButton(type: .custom)
        button.tintColor = Theme.iconColor
        let image = UIImage(named: "ic_expand_screen")?.withRenderingMode(.alwaysTemplate)
        button.setImage(image, for: .normal)
        button.accessibilityLabel = isFullScreenMode ? "Exit full screen" : "Full screen"
        button.addTarget(self, action: #selector(toggleFullScreen), for: .touchUpInside)
        button.isEnabled = true
        button.isUserInteractionEnabled = true

        let imageWidth: CGFloat = 24
        let imageHeight: CGFloat = 24
        let imageEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        button.imageEdgeInsets = imageEdgeInsets
        let buttonWidth = round(imageWidth + imageEdgeInsets.left + imageEdgeInsets.right)
        let buttonHeight = round(imageHeight + imageEdgeInsets.top + imageEdgeInsets.bottom)
        button.frame = CGRectMake(0, 0, buttonWidth, buttonHeight)

        return UIBarButtonItem(customView: button, accessibilityIdentifier: "fullscreen")
    }

    @objc private func toggleFullScreen() {
        // 查找FloatingConversationViewController
        if let navController = navigationController,
           let floatingVC = navController.parent as? FloatingConversationViewController {
            // 通知FloatingConversationViewController切换到全屏
            floatingVC.switchToFullScreen()
        }
    }
}

// MARK: - OWSNavigationChildController

extension ConversationViewController: OWSNavigationChildController {
    var shouldCancelNavigationBack: Bool {
        if conversationViewMode == .main {
            view.endEditing(true)
        }
        return false
    }
    
    // TODO: 下面的方法在 OC 全部转成 Swift 后删除，extension 中已经提供了全部实现
    
    public var childForOWSNavigationConfiguration: OWSNavigationChildController? { nil }
    
    public var preferredNavigationBarStyle: OWSNavigationBarStyle { .solid }

    public var navbarBackgroundColorOverride: UIColor? { nil }

    public var navbarTintColorOverride: UIColor? { nil }

    public var prefersNavigationBarHidden: Bool { false }
}

// MARK: Multi Select Mode

@objc extension ConversationViewController {
    var cancelMultiButton: UIBarButtonItem {
        if let button = viewState.cancelMultiButton {
            return button
        }
        let newButton = UIBarButtonItem(
            barButtonSystemItem: .stop,
            target: self,
            action: #selector(cancelMultiSelectMode)
        )
        viewState.cancelMultiButton = newButton
        return newButton
    }
    
    var tapGestureRecognizer: UITapGestureRecognizer {
        if let gesture = viewState.tapGestureRecognizer {
            return gesture
        }
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapToDismissKeyboard))
        viewState.tapGestureRecognizer = tapGesture
        return tapGesture
    }

    @objc private func handleTapToDismissKeyboard() {
        // 用户点击页面收起键盘，标记为用户操作
        dismissKeyBoard(byUserAction: true)
    }
    
    func enterMultiSelectMode(viewItem: ConversationViewItem) {
        addForwardMessage(viewItem)

        isMultiSelectMode = true
        tapGestureRecognizer.isEnabled = false
        collectionView.allowsMultipleSelection = true
        collectionView.reloadData()
        dismissKeyBoard(byUserAction: true)  // 用户进入多选模式，标记为用户操作
        reloadBottomBar()
        let recallableCount = countRecallableMessages()
        forwardToolbar.updateActionItemsSelectedCount(
            1,
            maxCount: 50,
            enableCounts: [1, 2, 1, NSNumber(value: recallableCount > 0 ? 1 : UInt.max)],
            recallableCount: UInt(recallableCount)
        )
        leftEdgePanGestureDisabled(true)

        scrollDownButton.alpha = 0
        headerView.isUserInteractionEnabled = false
        updateBarButtonItems()
    }
    
    func cancelMultiSelectMode() {
        clearAllForwardMessages()
        
        isMultiSelectMode = false
        tapGestureRecognizer.isEnabled = true
        collectionView.allowsMultipleSelection = false
        UIView.performWithoutAnimation {
            self.collectionView.reloadData()
        }
        reloadBottomBar()
        leftEdgePanGestureDisabled(false)
        
        scrollDownButton.alpha = 1
        headerView.isUserInteractionEnabled = true
        updateBarButtonItems()
    }
}
