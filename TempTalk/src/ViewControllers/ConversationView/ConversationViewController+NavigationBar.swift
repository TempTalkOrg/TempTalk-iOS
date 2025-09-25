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
        
        if let _ = navigationController?.presentingViewController, navigationController?.viewControllers.count == 1 {
            
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
        let newButton = UIBarButtonItem(
            barButtonSystemItem: .stop,
            target: self,
            action: #selector(dismissConversationButtonClick)
        )
        viewState.threadBackButton = newButton
        return newButton
    }
    
    var quickGroupBtn: UIBarButtonItem {
        if let button = viewState.quickGroupBtn {
            return button
        }
        let quickGroupBtn = UIButton(type: .custom)
        quickGroupBtn.tintColor = Theme.primaryIconColor
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
        askFriendBtn.tintColor = Theme.primaryIconColor
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
        let callImage = UIImage(named: "user_voice_call")
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
        func titleForContactThread(_ thread: TSContactThread) -> NSAttributedString? {
            if thread.isNoteToSelf {
                headerView.isExternal = false
                return NSAttributedString(
                    string: MessageStrings.noteToSelf(),
                    attributes: [.foregroundColor: Theme.primaryTextColor]
                )
            }
            
            let contactIdentifier = thread.contactIdentifier()
            var attributedName: NSAttributedString?
            databaseStorage.read { transaction in
                attributedName = self.contactsManager.attributedContactOrProfileName(
                    forPhoneIdentifier: contactIdentifier,
                    primaryFont: self.headerView.titlePrimaryFont,
                    secondaryFont: self.headerView.titleSecondaryFont,
                    transaction: transaction
                )
                self.thread.anyReload(transaction: transaction)
            }
            headerView.isExternal = SignalAccount.isExt(contactIdentifier)
            return attributedName
        }
        
        func titleForGroupThread() -> NSAttributedString? {
            var threadName: String = .empty
            databaseStorage.read { transaction in
                self.thread.anyReload(transaction: transaction)
                threadName = self.thread.name(with: transaction)
            }
            
            guard let groupThread = self.thread as? TSGroupThread else {
                return nil
            }
            
            var membersCount = groupThread.recipientIdentifiers.count
            let isLocalUserInGroup = groupThread.isLocalUserInGroup()
            
            var name: String
            if membersCount == 0 {
                name = threadName
            } else {
                membersCount = isLocalUserInGroup ? membersCount + 1 : membersCount
                name = "\(threadName)(\(membersCount))"
            }
            
            headerView.isExternal = false
            
            return NSAttributedString(string: name, attributes: [.foregroundColor: Theme.primaryTextColor])
        }
        
        
        if let groupThread = self.thread as? TSGroupThread, viewState.conversationViewMode == .normalPresent {
            
            self.title = groupThread.name(with: nil)
            return
        }
        
        let attributedTitle: NSAttributedString? = {
            
            var title: NSAttributedString?
            if let contractThread = self.thread as? TSContactThread {
                title = titleForContactThread(contractThread)
            }
            if self.thread is TSGroupThread {
                title = titleForGroupThread()
            }
            if let currentTitle = title,
               thread.messageExpiresInSeconds() > 0 {
                title = DTConversactionSettingUtils.msgDisappearingTipsOnThread(messageExpiry: TimeInterval(thread.messageExpiresInSeconds()), threadName: currentTitle, font: headerView.titlePrimaryFont)
            }
            return title
        }()
        
        self.title = nil
        
        if attributedTitle != headerView.attributedTitle {
            headerView.attributedTitle = attributedTitle
        }
    }
    
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
        
        let subtitleColor = Theme.navbarTitleColor.withAlphaComponent(0.9)
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
        
        if conversationViewMode == .normalPresent {
            navigationItem.leftBarButtonItem = threadBackButton
        } else {
            navigationItem.leftBarButtonItem = navigationItem.backBarButtonItem
        }
        
        if isUserLeftGroup {
            navigationItem.rightBarButtonItems = []
            return
        }
        
        let showFriendAction = isFriend && !isBot && !thread.isNoteToSelf
        var barBtnItems: [UIBarButtonItem] = []
        if thread.isGroupThread() ||
            showFriendAction {
            barBtnItems.append(createCallBarButtonItem())
        }
        if let groupThread = self.thread as? TSGroupThread,
           GroupPermissions.hasPermissionToAddGroupMembers(groupModel: groupThread.groupModel) {
            barBtnItems.append(quickGroupBtn)
        } else if !self.thread.isGroupThread() && showFriendAction {
            barBtnItems.append(quickGroupBtn)
        } else if !self.thread.isGroupThread() && !self.isFriend {
            barBtnItems.append(askFriendBtn)
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

        navigationController?.dismiss(animated: true)
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
                                                sourceType: .inUserCard,
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
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyBoard))
        viewState.tapGestureRecognizer = tapGesture
        return tapGesture
    }
    
    func enterMultiSelectMode(viewItem: ConversationViewItem) {
        addForwardMessage(viewItem)
        
        isMultiSelectMode = true
        tapGestureRecognizer.isEnabled = false
        collectionView.allowsMultipleSelection = true
        collectionView.reloadData()
        dismissKeyBoard()
        reloadBottomBar()
        forwardToolbar.updateActionItemsSelectedCount(1, maxCount: 50, enableCounts: [1, 2, 1])
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
