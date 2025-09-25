//
//  ConversationViewController.swift
//  Signal
//
//  Created by Jaymin on 2024/2/4.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit
import Foundation
import TTMessaging
import TTServiceKit

final class ConversationViewController: OWSViewController {
    
    var viewState: CVViewState
    var conversationViewModel: ConversationViewModel
    /// 存储已经处理过的cell
    var handledMessageIds: Set<String> = []
    
    var joinCallView = ConversationJoinCallView()
    
    var curRecipientId: String?
    var curCallModel: DTLiveKitCallModel?
    
    lazy var layout: ConversationViewLayout = {
        let layout = ConversationViewLayout(conversationStyle: self.conversationStyle)
        return layout
    }()
    
    lazy var collectionView: ConversationCollectionView = {
        let collectionView = ConversationCollectionView(
            frame: self.view.bounds,
            collectionViewLayout: self.layout
        )
        return collectionView
    }()
    
    @objc init(
        thread: TSThread,
        action: ConversationViewAction,
        focusMessageId: String? = nil,
        botViewItem: ConversationViewItem? = nil,
        viewMode: ConversationViewMode = .main
    ) {
        viewState = CVViewState(
            thread: thread,
            conversationViewMode: viewMode,
            focusMessageId: focusMessageId,
            botViewItem: botViewItem
        )
        
        conversationViewModel = ConversationViewModel(
            thread: thread,
            focusMessageIdOnOpen: focusMessageId,
            conversationViewMode: viewMode,
            botViewItem: botViewItem
        )
        
        super.init()
        
        conversationViewModel.config(with: self)
        
        actionOnOpen = action
        inputAccessoryPlaceholder.delegate = self
    }
    
    deinit {
        stopRefreshUITimer()
        stopScrollUpdateTimer()
        
        NotificationCenter.default.removeObserver(self)
        
        DTConversationPreviewManager.shared().currentThread = nil
        
        OWSArchivedMessageJob.shared().inConversation = false
        OWSArchivedMessageJob.shared().startIfNecessary()
        
        curRecipientId = nil
        curCallModel = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        OWSArchivedMessageJob.shared().inConversation = true
        
        createContents()
        registerNotifications()
        conversationViewModel.viewDidLoad()
        applyThemeWithoutReloadData()
                
        fetchThreadInfo()
        
        resetPinnedMappings(animated: false)
        
        prepareForMentionMessage()
        createVirtualContactIfNeeded()
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        
        checkBotBlock()
        checkContactBlock()
        
        // We need to recheck on every appearance, since the user may have left the group in the settings VC,
        // or on another device.
        hideInputIfNeeded()
        
        isViewVisible = true
                
        updateBarButtonItems()
        updateNavigationTitle()
        
        resetContentAndLayoutWithSneakyTransaction()
        
        updateLastVisibleSortIdWithSneakyAsyncTransaction()
        
        if !viewHasEverAppeared {
            BenchManager.completeEvent(eventId: "presenting-conversation-\(thread.uniqueId)")
        }
        
        // There are cases where we don't have a navigation controller, such as if we got here through 3d touch.
        // Make sure we only register the gesture interaction if it actually exists. This helps the swipe back
        // gesture work reliably without conflict with scrolling.
        if let popGesture = navigationController?.interactivePopGestureRecognizer {
            collectionView.panGestureRecognizer.require(toFail: popGesture)
        }
        
        DTConversationPreviewManager.shared().currentThread = thread
        
        if #available(iOS 16.0, *) {
            navigationController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
        
        setupJoinBarView()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // We resize the inputToolbar whenever it's text is modified, including when setting saved draft-text.
        // However it's possible this draft-text is set before the inputToolbar (an inputAccessoryView) is mounted
        // in the view hierarchy. Since it's not in the view hierarchy, it hasn't been laid out and has no width,
        // which is used to determine height.
        // So here we unsure the proper height once we know everything's been layed out.
        inputToolbar.ensureTextViewHeight()
        
        // Ensure the message list's contentInset is properly updated after input box height changes
        if viewHasEverAppeared {
            updateInputAccessoryPlaceholderHeight()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // recover status bar when returning from PhotoPicker, which is dark (uses light status bar)
        setNeedsStatusBarAppearanceUpdate()
        
        markVisibleMessagesAsRead()
        startReadTimer()
        updateNavigationBarSubtitleLabel()
        
        if !viewHasEverAppeared {
            // To minimize time to initial apearance, we initially disable prefetching, but then
            // re-enable it once the view has appeared.
            collectionView.isPrefetchingEnabled = true
            
            syncHasReadStatus()
        }
        
        conversationViewModel.focusMessageIdOnOpen = nil
        
        isViewCompletelyAppeared = true
        viewHasEverAppeared = true
        shouldAnimateKeyboardChanges = true
        
        switch actionOnOpen {
        case .compose:
            popKeyBoard()
            
            // When we programmatically pop the keyboard here,
            // the scroll position gets into a weird state and
            // content is hidden behind the keyboard so we restore
            // it to the default position.
            scrollToDefaultPosition(animated: true)
            
        case .audioCall:
            didTapCallNavBtn()
            
        default:
            break
        }
        // Clear the "on open" state after the view has been presented.
        actionOnOpen = .none
        
        ensureScrollDownButton()
        inputToolbar.viewDidAppear()
        loadDraftInCompose()
    }
    
    // `viewWillDisappear` is called whenever the view *starts* to disappear,
    // but, as is the case with the "pan left for message details view" gesture,
    // this can be canceled. As such, we shouldn't tear down anything expensive
    // until `viewDidDisappear`.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        saveDraft()
        isViewCompletelyAppeared = false
        dismissKeyBoard()
        
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        userHasScrolled = false
        isViewVisible = false
        shouldAnimateKeyboardChanges = false
        
        stopAudioPlayer()
        
        cancelReadTimer()
        markVisibleMessagesAsRead()
        
        cellMediaCache.removeAllObjects()
        inputToolbar.clearDesiredKeyboard()
        
        isUserScrolling = false
        isWaitingForDeceleration = false
        /// 清空缓存数据
        handledMessageIds.removeAll()
        // 清理joinview
        joinCallView.isHidden = true
        joinCallView.removeFromSuperview()
    }
    
    override var canBecomeFirstResponder: Bool {
        true
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        
        // If we become the first responder, it means that the
        // input toolbar is not the first responder. As such,
        // we should clear out the desired keyboard since an
        // interactive dismissal may have just occured and we
        // need to update the UI to reflect that fact. We don't
        // actually ever want to be the first responder, so resign
        // immediately. We just want to know when the responder
        // state of our children changed and that information is
        // conveniently bubbled up the responder chain.
        if result {
            resignFirstResponder()
            inputToolbar.resignFirstResponder()
            inputToolbar.clearDesiredKeyboard()
        }
        
        return result
    }
    
    override var inputAccessoryView: UIView? {
        inputAccessoryPlaceholder
    }
    
    override var textInputContextIdentifier: String? {
        thread.uniqueId
    }
    
    override func present(
        _ viewControllerToPresent: UIViewController,
        animated flag: Bool,
        completion: (() -> Void)? = nil
    ) {
        dismissKeyBoard()
        super.present(viewControllerToPresent, animated: flag, completion: completion)
    }
    
    static func setNeedsRefreshGroupInfo(for serverGroupId: String) {
        guard !serverGroupId.isEmpty else { return }
        CVViewState.conversationTagInfo[serverGroupId] = false
    }
}

// MARK: - Initiliazers

extension ConversationViewController {
    private func createContents() {
        setupCollectionView()
        setupBottomBar()
        
        resetShowLoadMore()
        setupRemindView()
        setupBlockView()
        
        createConversationScrollButtons()
        
        createHeaderViews()
        updateBarButtonItems()
        
        reloadBottomBar()
    }
}

// MARK: - Orientation

extension ConversationViewController {
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        updateBarButtonItems()
        updateNavigationBarSubtitleLabel()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        
        updateContentInsets(animated: false)
    }
}

// MARK: Thread Info

extension ConversationViewController {
    private func fetchThreadInfo() {
        if isGroupConversation {
            getGroupInfo()
        } else {
            fetchThreadConfig()
            requestContactInfo()
        }
    }
    
    // Tips: 群组信息中可以获得当前群组的消息过期时间
    private func getGroupInfo() {
        guard let groupThread = thread as? TSGroupThread else {
            return
        }
        guard let serverGroupId, !serverGroupId.isEmpty else {
            return
        }
        
        let needSkipUpdateGroupInfo = conversationTagInfo[serverGroupId] ?? false
        if needSkipUpdateGroupInfo,
           !TSAccountManager.sharedInstance().isChangeGlobalNotificationType {
            return
        }
        
        // TODO: Jaymin 待验证
        getGroupInfoAPI.sendRequest(withGroupId: serverGroupId) { [weak self] entity in
            
            guard let self else { return }
            
            let needSystemMessage = groupThread.recipientIdentifiers.isEmpty
            self.databaseStorage.asyncWrite { transaction in
                let newThread = self.groupUpdateMessageProcessor.generateOrUpdateConveration(
                    withGroupId: groupThread.groupModel.groupId,
                    needSystemMessage: needSystemMessage,
                    generate: false,
                    envelope: nil,
                    groupInfo: entity,
                    groupNotifyEntity: nil,
                    transaction: transaction
                )
                transaction.addAsyncCompletionOnMain {
                    guard let newThread else {
                        self.navigationController?.popViewController(animated: true)
                        return
                    }
                    self.thread = newThread
                    self.updateNavigationTitle()
                }
            }
            self.conversationTagInfo[serverGroupId] = true
            
        } failure: { [weak self] error in
            
            guard let self else { return }
            
            let errorCode = (error as NSError).code
            guard let responseStatus = DTAPIRequestResponseStatus(rawValue: errorCode) else {
                return
            }
            switch responseStatus {
            case .noSuchGroup, .noPermission:
                var memberIds = Array(groupThread.groupModel.groupMemberIds)
                guard let localNumber = TSAccountManager.localNumber(),
                      let index = memberIds.firstIndex(of: localNumber) else {
                    return
                }
                memberIds.remove(at: index)
                self.databaseStorage.asyncWrite { transaction in
                    groupThread.anyUpdateGroupThread(transaction: transaction) { instance in
                        instance.groupModel.groupMemberIds = Array(memberIds)
                    }
                }
                
            default:
                break
            }
        }
        
        // 打开 app 首次拉取 pinned message
        DTPinnedDataSource.shared().syncPinnedMessage(withServer: serverGroupId)
    }
    
    private func fetchThreadConfig() {
        guard let contactThread = thread as? TSContactThread else {
            return
        }
        
        let contactIdentifier = contactThread.contactIdentifier()
        fetchThreadConfigAPI.fetchThreadConfigRequest(withNumber: contactThread.generateConversationId()) { [weak self] entity in
            
            guard let self, let entity else { return }
            
            self.databaseStorage.asyncWrite { transaction in
                self.thread.anyUpdate(transaction: transaction) { instance in
                    if let threadConfig_t = instance.threadConfig {
                        entity.endTimestamp = threadConfig_t.endTimestamp
                    }
                    instance.threadConfig = entity
                    
                    // 查询contact会话更新
                    DataUpdateUtil.shared.updateConversation(thread: instance,
                                                             expireTime: entity.messageExpiry,
                                                             messageClearAnchor: NSNumber(value: entity.messageClearAnchor))
                }
                
                if entity.askedVersion > 0 {
                    TSContactThread.update(withRecipientId: contactIdentifier,
                                           friendContactVersion: entity.askedVersion,
                                           receivedFriendReq: true,
                                           updateAtTheSameVersion: false,
                                           transaction: transaction)
                }
                
            }
            
        } failure: { error in
            OWSLogger.error("fetchThreadConfig error: \(error)")
        }
    }
    
    func requestContactInfo() {
        guard let contactThread = thread as? TSContactThread else {
            return
        }
        let recipientId = contactThread.contactIdentifier()
        TSAccountManager.sharedInstance().getContactMessageV1(byPhoneNumber: [recipientId]) { [weak self] contacts in
            guard let self = self, let newContact = contacts.first as? Contact else { return }
            
            self.databaseStorage.asyncWrite { transaction in
                guard let contactsManager = Environment.shared.contactsManager else {return}
                
                let account = contactsManager.signalAccount(forRecipientId: recipientId, transaction: transaction)
                
                if let account, let contact = account.contact, !contact.isEqual(newContact){
                    account.contact = newContact
                    contactsManager.updateSignalAccount(withRecipientId: recipientId, withNewSignalAccount: account, with: transaction)
                } else if account == nil {
                    let newAccount = SignalAccount(recipientId: recipientId)
                    newAccount.contact = newContact
                    contactsManager.updateSignalAccount(withRecipientId: recipientId, withNewSignalAccount: newAccount, with: transaction)
                }
            }
            
        } failure: { error in
            Logger.info("requestContactInfo fail")
        }
    }
}

// MARK: Timer

extension ConversationViewController {
    var readTimer: Timer? {
        get { viewState.readTimer }
        set { viewState.readTimer = newValue }
    }
    
    var isMarkingAsRead: Bool {
        get { viewState.isMarkingAsRead }
        set { viewState.isMarkingAsRead = newValue }
    }
    
    func startReadTimer() {
        readTimer?.invalidate()
        readTimer = Timer.weakScheduledTimer(
            withTimeInterval: 0.1,
            target: self,
            selector: #selector(readTimerDidFire),
            userInfo: nil,
            repeats: true
        )
    }
    
    @objc func readTimerDidFire() {
        markVisibleMessagesAsRead()
    }
    
    func cancelReadTimer() {
        readTimer?.invalidate()
        readTimer = nil
    }
    
    func markVisibleMessagesAsRead() {
        // Don't mark messages as read until the message request has been processed
        guard presentedViewController == nil else { return }
        guard !OWSWindowManager.shared().shouldShowCallView else { return }
        guard navigationController?.topViewController === self else { return }
        
        updateLastVisibleSortIdWithSneakyAsyncTransaction()
        
        let lastVisibleSortId = self.lastVisibleSortId
        if lastVisibleSortId == 0 {
            // No visible messages yet. New Thread.
            return
        }
        if (thread.readPositionEntity?.maxServerTime ?? 0) >= lastVisibleSortId {
            return
        }
        
        AssertIsOnMainThread()
        
        if isMarkingAsRead {
            return
        }
        isMarkingAsRead = true
        
        var groupId: Data? = nil
        if isGroupConversation, let groupThread = thread as? TSGroupThread {
            groupId = groupThread.groupModel.groupId
        }
        
        let readPosition = DTReadPositionEntity(
            groupId: groupId,
            readAt: NSDate.ows_millisecondTimeStamp(),
            maxServerTime: lastVisibleSortId,
            notifySequenceId: self.lastNotifySequenceId,
            maxSequenceId: self.lastMsgSequenceId
        )
        Logger.info("conversation view sendReadRecipet:\(readPosition)")
        
        OWSReadReceiptManager.shared().sendReadRecipet(
            withReadPosition: readPosition,
            thread: self.thread,
            wasLocal: true
        ) { [weak self] in
            
            AssertIsOnMainThread()
            
            guard let self else { return }
            self.isMarkingAsRead = false
            self.refreshMentionMessageCount()
            
        }
    }
}

// MARK: - Private

extension ConversationViewController {
    // 发送同步设备的已读回执
    func syncHasReadStatus() {
        guard conversationViewModel.viewState.unreadIndicatorIndex == nil else {
            return
        }
        var incommingMessage: TSIncomingMessage?
        databaseStorage.asyncRead(block: { [weak self] readTransaction in
            guard let self else { return }
            
            incommingMessage = InteractionFinder(
                threadUniqueId: self.thread.uniqueId
            ).lastestIncomingInteraction(transaction: readTransaction)
            
        }, completionQueue: .main) {
            if let incommingMessage {
                OWSReadReceiptManager.shared().messageWasReadLocally(
                    incommingMessage,
                    shouldSendReadReceipt: true
                )
            }
        }
    }
    
    func createVirtualContactIfNeeded() {
        guard !isGroupConversation, let contactIdentifier = thread.contactIdentifier() else {
            return
        }
        var currentSignalAccount: SignalAccount?
        databaseStorage.read { transaction in
            currentSignalAccount = self.contactsManager.signalAccount(
                forRecipientId: contactIdentifier,
                transaction: transaction
            )
        }
        if let currentSignalAccount, !(currentSignalAccount.contact?.isExternal ?? false) {
            return
        }
        
        let needSkipCreate = conversationTagInfo[contactIdentifier] ?? false
        if needSkipCreate {
            return
        }
        
        let request = OWSRequestFactory.getV1ContactExtId(contactIdentifier)
        let baseAPI = DTBaseAPI()
        baseAPI.send(request) { [weak self] entity in
            
            guard let self else { return }
            guard entity.status == 0 else { return }
           
            var newSignalAccount: SignalAccount
            if let currentSignalAccount {
                newSignalAccount = currentSignalAccount
                newSignalAccount.contact?.isExternal = true
                newSignalAccount.contact?.number = contactIdentifier
                newSignalAccount.contact?.extId = (entity.data["extId"] as? NSNumber) ?? NSNumber(value: 0)
            } else {
                newSignalAccount = SignalAccount(recipientId: contactIdentifier)
                let contact = Contact(recipientId: contactIdentifier)
                contact.isExternal = true
                contact.extId = (entity.data["extId"] as? NSNumber) ?? NSNumber(value: 0)
                newSignalAccount.contact = contact
            }
            
            self.databaseStorage.asyncWrite { transaction in
                self.contactsManager.updateSignalAccount(
                    withRecipientId: contactIdentifier,
                    withNewSignalAccount: newSignalAccount,
                    with: transaction
                )
                transaction.addAsyncCompletionOnMain {
                    self.updateNavigationTitle()
                    self.conversationTagInfo[contactIdentifier] = true
                }
            }
            
        } failure: { _ in }
    }
}

// MARK: - Theme

extension ConversationViewController {
    override func applyTheme() {
        
        applyThemeWithoutReloadData()
        applyThemeForReminderView()
        
        conversationViewModel.cleanCardCaches()
        reloadData()
        applyThemeForInputToolBar()
        setupBackgroundView()
    }
    
    private func applyThemeWithoutReloadData() {
        AssertIsOnMainThread()
        
        view.backgroundColor = Theme.toolbarBackgroundColor
        collectionView.backgroundColor = Theme.backgroundColor
        
        headerView.applyTheme()
        applyThemeForPinView()
        updateNavigationBarSubtitleLabel()
        
        applyThemeForForwardToolbar()
        
        friendReqBar.applyTheme()
    }
    
    private func applyThemeForInputToolBar() {
        dismissKeyBoard()
        recreateInputToolbar()
        reloadBottomBar()
    }
}
