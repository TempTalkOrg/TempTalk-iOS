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
import PanModal

final class ConversationViewController: OWSViewController {
    
    var viewState: CVViewState
    var conversationViewModel: ConversationViewModel
    /// 存储已经处理过的cell
    var handledMessageIds: Set<String> = []
    /// 存储已查看的机密占位消息ID（用于离开会话时批量删除兜底）
    private var viewedPlaceholderIds: Set<String> = []
    /// 存储机密占位消息的定时删除 timer，key 为 uniqueId
    private var placeholderDismissTimers: [String: Timer] = [:]

    var joinCallView = ConversationJoinCallView()

    var curRecipientId: String?
    var curCallModel: DTLiveKitCallModel?

    /// 标记是否已经执行过未读数矫正（每次会话打开时重置）
    private var hasCorrectUnreadCount = false

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
        viewMode: ConversationViewMode = .main,
        isFromPersonalCard: Bool = false
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

        Logger.info("[Conversation] init threadId=\(thread.uniqueId) isViewVisible is \(isViewVisible) conversation controller \(self)")

        self.isFromPersonalCard = isFromPersonalCard
        conversationViewModel.delegate = self
        conversationViewModel.loadInitialMessages()

        actionOnOpen = action
        inputAccessoryPlaceholder.delegate = self
    }
    
    deinit {
        Logger.info("[Conversation] deinit threadId=\(thread.uniqueId) isViewVisible is \(isViewVisible) conversation controller \(self)")
        
        stopRefreshUITimer()
        stopScrollUpdateTimer()
        cancelPendingInitialMessagesIfNeeded()

        NotificationCenter.default.removeObserver(self)
        
        DTConversationPreviewManager.shared().currentThread = nil
        
        OWSArchivedMessageJob.shared().inConversation = false
        OWSArchivedMessageJob.shared().startIfNecessary()
        
        curRecipientId = nil
        curCallModel = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Logger.info("[Conversation] viewDidLoad threadId=\(thread.uniqueId) isViewVisible=\(isViewVisible) shouldBeVisible=\(thread.shouldBeVisible) isArchived=\(thread.isArchived) hasEverHadMessage=\(thread.hasEverHadMessage) archivalDate=\(String(describing: thread.archivalDate)) creationDate=\(String(describing: thread.creationDate))")
        
        OWSArchivedMessageJob.shared().inConversation = true
        
        createContents()
        registerNotifications()
        conversationViewModel.viewDidLoad()
        applyThemeWithoutReloadData()
                
        fetchThreadInfo()
        
        prepareForMentionMessage()
        
        checkAndUpdateConfidentialMessageAvailability()
    }
    
    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        Logger.info("[Conversation] viewIsAppearing threadId=\(thread.uniqueId) isViewVisible is \(isViewVisible) conversation controller \(self)")
        registerScreenshotObserver()
        checkBotBlock()
        safeUpdateBlockStatus()
        
        // We need to recheck on every appearance, since the user may have left the group in the settings VC,
        // or on another device.
        hideInputIfNeeded()
        
        isViewVisible = true

        updateBarButtonItems()
        updateNavigationTitle()

        // If a pending initial-load snapshot is waiting, refreshing it already runs resetContentAndLayout,
        // so skip the sneaky reset to avoid two back-to-back resets.
        if !processPendingInitialMessagesIfNeeded() {
            resetContentAndLayoutWithSneakyTransaction()
        }
        
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

        // DEBUG: viewIsAppearing
        Logger.info("[Conversation] viewIsAppearing isViewVisible is \(isViewVisible) conversation controller \(self)")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        updateWarningHeaderLayout()

        guard !isInteractivePopTransitioning else { return }

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

        Logger.info("[Conversation] viewDidAppear threadId=\(thread.uniqueId) isViewVisible is \(isViewVisible) conversation controller \(self)")

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

        syncBottomBarWithKeyboardState()

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

        Logger.info("[Conversation] viewWillDisappear threadId=\(thread.uniqueId) isViewVisible is \(isViewVisible) conversation controller \(self)")

        saveDraft()
        isViewCompletelyAppeared = false
        forceDissmissKeyBoard()  // 页面即将消失，强制收起键盘

        if let transitionCoordinator, transitionCoordinator.isInteractive {
            isInteractivePopTransitioning = true
            transitionCoordinator.animate(alongsideTransition: nil) { [weak self] context in
                guard let self else { return }
                self.isInteractivePopTransitioning = false
                if context.isCancelled {
                    self.view.setNeedsLayout()
                    self.view.layoutIfNeeded()
                    self.syncBottomBarWithKeyboardState()
                }
            }
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        Logger.info("[Conversation] viewDidDisappear threadId=\(thread.uniqueId) isViewVisible is \(isViewVisible) conversation controller \(self)")

        userHasScrolled = false
        isViewVisible = false
        shouldAnimateKeyboardChanges = false
        
        stopAudioPlayer()

        // Cancel any in-flight voice-memo recording when the user navigates
        // away (back button, swipe-to-pop, etc.). Previously the recorder
        // kept running in the background and the candidate files were
        // dropped on the floor without releasing the mic; matches Android's
        // `onDetachedFromWindow` cleanup. Uses the same `voiceMemoIsActive`
        // accessor as `applicationWillResignActive` so adding new "is
        // recording?" state in the future only requires one edit.
        if voiceMemoIsActive {
            self.inputToolbar.hideVoiceMemoUI(animated: false)
            cancelRecordingVoiceMemo()
        }
        
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

        if navigationController?.viewControllers.contains(self) != true {
            OWSArchivedMessageJob.shared().inConversation = false
            OWSArchivedMessageJob.shared().triggerArchiveCheckAfterLeavingConversation()
            batchDeleteViewedPlaceholders()
        }
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
            if presentedViewController == nil {
                inputToolbar.resignFirstResponder()
                inputToolbar.clearDesiredKeyboard()
            }
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
        // No longer needed: getGroupInfo now always fetches and compares.
    }

    // MARK: - Confidential Placeholder Management

    /// 兜底：离开会话时删除所有还未被定时器处理的占位消息
    private func batchDeleteViewedPlaceholders() {
        placeholderDismissTimers.values.forEach { $0.invalidate() }
        placeholderDismissTimers.removeAll()

        guard !viewedPlaceholderIds.isEmpty else { return }
        let placeholderIds = viewedPlaceholderIds
        viewedPlaceholderIds.removeAll()

        databaseStorage.asyncWrite { transaction in
            for uniqueId in placeholderIds {
                guard let placeholder = TSInfoMessage.anyFetch(
                    uniqueId: uniqueId,
                    transaction: transaction
                ) as? TSInfoMessage,
                      placeholder.messageType == .confidentialViewed else {
                    continue
                }
                placeholder.anyRemove(transaction: transaction)
            }
        }
    }

    func addViewedPlaceholder(_ uniqueId: String) {
        guard !viewedPlaceholderIds.contains(uniqueId) else { return }
        viewedPlaceholderIds.insert(uniqueId)

        // 3s 后自动删除，触发 collection view 的单条删除动画
        let timer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            self?.deletePlaceholder(uniqueId: uniqueId)
        }
        placeholderDismissTimers[uniqueId] = timer
    }

    private func deletePlaceholder(uniqueId: String) {
        placeholderDismissTimers.removeValue(forKey: uniqueId)
        viewedPlaceholderIds.remove(uniqueId)

        databaseStorage.asyncWrite { transaction in
            guard let placeholder = TSInfoMessage.anyFetch(
                uniqueId: uniqueId,
                transaction: transaction
            ) as? TSInfoMessage,
                  placeholder.messageType == .confidentialViewed else {
                return
            }
            placeholder.anyRemove(transaction: transaction)
        }
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

        // Mark that screen orientation is changing to prevent auto-scroll in adjustInsets
        if previousTraitCollection?.verticalSizeClass != traitCollection.verticalSizeClass ||
           previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass {
            isScreenOrientationChanging = true
        }

        updateBarButtonItems()
        updateNavigationBarSubtitleLabel()
    }
    
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        
        if view.safeAreaInsets.bottom > 50 {
            return
        }

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

        let oldModel = groupThread.groupModel

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
                transaction.addAsyncCompletionOnMain { [weak self] in
                    guard let self else { return }
                    guard let newThread else {
                        self.navigationController?.popViewController(animated: true)
                        return
                    }
                    if !newThread.groupModel.isEqual(to: oldModel) {
                        self.thread = newThread
                        self.updateNavigationTitle()
                    }
                }
            }
            
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
                self.databaseStorage.asyncWrite { [weak self] transaction in
                    guard let self = self else { return }
                    groupThread.anyUpdateGroupThread(transaction: transaction) { instance in
                        instance.groupModel.groupMemberIds = Array(memberIds)
                    }
                }
                
            default:
                break
            }
        }
    }
    
    private func fetchThreadConfig() {
        guard let contractThread = thread as? TSContactThread,
              thread.threadConfig?.messageExpiry == nil else {
            return
        }
        
        let contactIdentifier = contractThread.contactIdentifier()
        fetchThreadConfigAPI.fetchThreadConfigRequest(withNumber: contactIdentifier) { [weak self] entity in
            
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
                                                             messageClearAnchor: NSNumber(value: entity.messageClearAnchor),
                                                             transaction: transaction)
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
        guard let contactThread = thread as? TSContactThread else { return }
        let recipientId = contactThread.contactIdentifier()
        guard let contactsManager = Environment.shared.contactsManager else { return }
        contactsManager.fetchAndUpdateContactInfo(forRecipientId: recipientId)
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
        guard !conversationViewModel.isLoadingInitialMessages() else { return }
        
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

            // 矫正未读数（每次会话打开时只执行一次）
            if !hasCorrectUnreadCount {
                hasCorrectUnreadCount = true

                databaseStorage.asyncWrite { [weak self] transaction in
                    guard let self = self else { return }
                    let thread = self.thread

                    // 在 anyUpdate 外部查询一次（只执行1次 SQL）
                    guard let latestThread = TSThread.anyFetch(uniqueId: thread.uniqueId,
                                                               transaction: transaction) else { return }
                    let unreadCount = latestThread.getUnreadMessageCount(with: transaction)

                    thread.anyUpdate(transaction: transaction) { instance in
                        instance.updateUnreadMessageCount(unreadCount)
                    }
                }
            }

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
}

// MARK: - Confidential Message Availability

extension ConversationViewController {
    /// Check and update confidential message availability based on group size
    /// - For groups with ≥20 members: hide confidential message toggle and disable if currently enabled
    /// - For groups with <20 members: show confidential message toggle normally
    /// - This should only be called when group membership changes, not on every view appearance
    func checkAndUpdateConfidentialMessageAvailability() {
        guard isGroupConversation, let groupThread = thread as? TSGroupThread else {
            return
        }

        let memberCount = groupThread.groupModel.groupMemberIds.count
        let groupConfig = DTGroupConfig.fetch()
        let threshold = groupConfig.confidentialModeThreshold
        let shouldDisableConfidential = memberCount >= threshold

        // Update button visibility
        updateConfidentialButtonVisibility()

        // If group has ≥threshold members and confidential mode is currently enabled, disable it
        if shouldDisableConfidential {
            if let conversationEntity = thread.conversationEntity,
               conversationEntity.confidentialMode == .confidential {
                disableConfidentialModeForLargeGroup()
            }
        }
    }

    /// Disable confidential mode for groups with ≥threshold members
    private func disableConfidentialModeForLargeGroup() {
        let configApi = DTSetConversationApi()
        configApi.requestConfigConfidentialMode(withConversationID: thread.serverThreadId,
                                                confidentialMode: 0) { [weak self] conversationEntity in
            guard let self = self else { return }
            self.inputToolbar.inputToolbarState = .normal
            self.thread.conversationEntity = conversationEntity
            self.databaseStorage.asyncWrite { wTransaction in
                self.thread.anyUpdate(transaction: wTransaction) { thread in
                    thread.conversationEntity = conversationEntity

                    DataUpdateUtil.shared.updateConversation(thread: thread,
                                                             expireTime: conversationEntity.messageExpiry,
                                                             messageClearAnchor: NSNumber(value: conversationEntity.messageClearAnchor),
                                                             transaction: wTransaction)
                }
                wTransaction.addAsyncCompletionOnMain {
                    NotificationCenter.default.post(name: .DTConversationDidChange, object: nil)
                }
            }
        } failure: { error in
            Logger.error("Failed to disable confidential mode for large group: \(error)")
        }
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

        view.backgroundColor = Theme.bg1Color
        collectionView.backgroundColor = Theme.bg1Color

        headerView.applyTheme()
        updateNavigationBarSubtitleLabel()

        applyThemeForForwardToolbar()

        friendReqBar.applyTheme()

        if showWarningHeader {
            warningHeaderView.applyTheme()
        }
    }
    
    private func applyThemeForInputToolBar() {
        Logger.info("[Keyboard] applyThemeForInputToolBar, isFirstResponder=\(inputToolbar.inputTextView.isFirstResponder), textLen=\(inputToolbar.inputTextView.text?.count ?? 0)")
        recreateInputToolbar()
        reloadBottomBar()
    }

    // MARK: - Reshow PersonalCard

}
