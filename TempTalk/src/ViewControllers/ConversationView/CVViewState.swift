//
//  CVViewState.swift
//  Signal
//
//  Created by Jaymin on 2024/1/5.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit
import QuickLook
import AVFoundation
import TTMessaging
import TTServiceKit

@objc enum ScrollContinuity: UInt {
    case bottom
    case top
}

enum ConversationSection: CaseIterable {
    case main
}

class CVViewState: NSObject {
    
    static var conversationTagInfo: [String: Bool] = [:]
    
    var thread: TSThread
    
    var readTimer: Timer?
    var isMarkingAsRead = false
    
    lazy var cellMediaCache: NSCache<AnyObject, AnyObject> = {
        // Cache the cell media for ~24 cells.
        let cache = NSCache<AnyObject, AnyObject>()
        cache.countLimit = 24
        return cache
    }()
    
    var conversationViewMode: ConversationViewMode
    var conversationStyle: ConversationStyle
    var dataSource: UICollectionViewDiffableDataSource<ConversationSection, String>?
    
    lazy var renderItemBuilder = ConversationCellRenderItemBuilder()
    var renderItems: [ConversationCellRenderItem] = []
    var renderItemsMap: [String: ConversationCellRenderItem] = [:]
    
    var headerView: ConversationHeaderView?
    lazy var remindView = DTRemindView()
    lazy var blockView = UIView()

    var threadBackButton: UIBarButtonItem?
    var threadPopBackButton: UIBarButtonItem?
    var cancelMultiButton: UIBarButtonItem?
    var moreButton: UIBarButtonItem?
    var askFriendBtn: UIBarButtonItem?
    var quickGroupBtn: UIBarButtonItem?
    
    var inputToolbar: ConversationInputToolbar?

    var friendReqBar: DTRequestBar?
    var friendReqTime: TimeInterval = 0
    var warningHeaderView: DTConversationWarningHeaderView?
    var warningHeaderTopConstraint: NSLayoutConstraint?
    
    //用于机密消息附件预览后清除
    var genericAttachmenViewItem: ConversationViewItem?
    
    lazy var bottomBar = UIView.container()
    var bottomBarBottomConstraint: NSLayoutConstraint?
    lazy var inputAccessoryPlaceholder = InputAccessoryViewPlaceholder()
    var isDismissingInteractively = false
    
    var tapGestureRecognizer: UITapGestureRecognizer?
    
    var isViewVisible = false
    var isUserScrolling = false
    var isWaitingForDeceleration = false
    
    var viewHasEverAppeared = false
    var shouldAnimateKeyboardChanges = false
    var hasCompletedInitialScroll = false
    
    var atLocation: UInt = 0
    weak var atVC: ChooseAtMembersViewController?
    
    var lastMessageSentDate: Date?
    
    var isShowLoadOlderHeader = false
    var isShowLoadNewerHeader = false
    var isShowFetchOlderHeader = false
    var isShowFetchNewerHeader = false

    // 防止在加载过程中重复触发加载
    var isLoadingOlderItems = false
    var isLoadingNewerItems = false
    
    var lastVisibleSortId: UInt64 = .zero
    var lastNotifySequenceId: UInt64 = .zero
    var lastMsgSequenceId: UInt64 = .zero
    
    var isViewCompletelyAppeared = false

    var peek = false
    var hasUnreadMessages = false
    var scrollDownButton: ConversationScrollButton?
    var dateSeparatorView: ConversationDateSeparatorView?

    // MARK: - Keyboard Protection
    /// 键盘保护状态：当键盘弹出后，防止非用户操作导致的键盘收起
    var isKeyboardProtectionEnabled = false

    // MARK: - Initial Scroll Position Protection
    /// 存储初始滚动到未读消息的目标位置，用于防止键盘闪现导致的位置偏移
    var initialScrollTargetOffset: CGFloat?
    /// 初始滚动保护的截止时间，超过此时间后清除保护
    var initialScrollProtectionDeadline: Date?
    
    var lastPosition: CGFloat = .zero
    var isScrollUp = false
    var userHasScrolled = false
    var lastReloadDate: Date?
    var scrollStateBeforeLoadingMore: ConversationScrollState?
    var mentionMessagesJumpManager: DTMentionMessagesJumpManager?
    
    var lastKnownDistanceFromBottom: CGFloat?
    var scrollContinuity: ScrollContinuity = .bottom
    var scrollUpdateTimer: Timer?
    var hideDateTimer: Timer?
    
    var actionOnOpen: ConversationViewAction = .none
    
    var shouldObserveDBModifications = false
    var reloadTimer: Timer?
    var isNeedReloadAfterAppEnterForeground = false
        
    var selectThreadTool: SelectThreadTool?
    var actionMessageType: ConversationMessageType?
    weak var actionMenuController: ConversationActionMenuController?
    
    // MARK: forward message
    var forwardToolbar: DTMultiSelectToolbar?
    var isMultiSelectMode: Bool = false
    var forwardType: DTForwardMessageType = .oneByOne
    var forwardMessageItems: [ConversationViewItem] = []
    var targetThreads: [TSThread] = []

    // MARK: call
    var isReturningFromCallWindow = false
    var isScreenOrientationChanging = false
    var isFromPersonalCard = false
    var isFullScreenMode = false
    var floatingWindowIsCompactMode = false  // 浮动窗口是否处于compact模式（50%）

    // MARK: photo
    var photoBrowser: DTPhotoBrowserHelper?
    var loadingView: UIActivityIndicatorView?
    
    // MARK: audio
    var audioPlayer: OWSAudioPlayer?
    var audioRecorder: DTAudioRecorder?
    var voiceMessageUUID: UUID?
    var currentAudioPlaybackRate: Float? // 当前会话的播放速度，nil 表示使用全局设置
    lazy var recordVoiceNoteAudioActivity: AudioActivity = {
        let activity = AudioActivity(audioDescription: "Voice Message Recording")
        return activity
    }()
    
    // MARK: attachment
    var currentPreviewFileURL: NSURL?
    var previewController: QLPreviewController?
    
    // MARK: Group
    lazy var rejoinGroupAPI = DTInviteToGroupAPI()
    lazy var getGroupInfoAPI = DTGetGroupInfoAPI()
    lazy var groupUpdateMessageProcessor = DTGroupUpdateMessageProcessor()
    lazy var fetchThreadConfigAPI = DTFetchThreadConfigAPI()
    
    @objc init(
        thread: TSThread,
        conversationViewMode: ConversationViewMode,
        focusMessageId: String?,
        botViewItem: ConversationViewItem?
    ) {
        self.thread = thread
        self.conversationViewMode = conversationViewMode
        self.conversationStyle = ConversationStyle(thread: thread)
    }
}

extension ConversationViewController {
    var conversationTagInfo: [String: Bool] {
        get { CVViewState.conversationTagInfo }
        set { CVViewState.conversationTagInfo = newValue }
    }
    
    @objc var thread: TSThread {
        get {
            viewState.thread
        }
        set {
            viewState.thread = newValue
        }
    }
    
    var conversationViewMode: ConversationViewMode {
        viewState.conversationViewMode
    }
    
    var cellMediaCache: NSCache<AnyObject, AnyObject> {
        viewState.cellMediaCache
    }
    
    var conversationStyle: ConversationStyle {
        viewState.conversationStyle
    }
    
    var isViewVisible: Bool {
        get {
            viewState.isViewVisible
        }
        set {
            let wasVisible = viewState.isViewVisible
            viewState.isViewVisible = newValue
            // 为解决 modal 半屏 viewController 后，图片不展示问题，不去更改 cellIsVisible
            // updateCellsVisible()
            updateShouldObserveDBModifications()
        }
    }
    
    var isWaitingForDeceleration: Bool {
        get {
            viewState.isWaitingForDeceleration
        }
        set {
            viewState.isWaitingForDeceleration = newValue
        }
    }

    var isLoadingOlderItems: Bool {
        get {
            viewState.isLoadingOlderItems
        }
        set {
            viewState.isLoadingOlderItems = newValue
        }
    }

    var isLoadingNewerItems: Bool {
        get {
            viewState.isLoadingNewerItems
        }
        set {
            viewState.isLoadingNewerItems = newValue
        }
    }
    
    var lastMessageSentDate: Date? {
        get { viewState.lastMessageSentDate }
        set { viewState.lastMessageSentDate = newValue }
    }
    
    var lastVisibleSortId: UInt64 {
        get { viewState.lastVisibleSortId }
        set { viewState.lastVisibleSortId = newValue }
    }
    
    var lastNotifySequenceId: UInt64 {
        get { viewState.lastNotifySequenceId }
        set { viewState.lastNotifySequenceId = newValue }
    }
    
    var lastMsgSequenceId: UInt64 {
        get { viewState.lastMsgSequenceId }
        set { viewState.lastMsgSequenceId = newValue }
    }
    
    var peek: Bool {
        get { viewState.peek }
        set { viewState.peek = newValue }
    }
    
    var actionOnOpen: ConversationViewAction {
        get { viewState.actionOnOpen }
        set { viewState.actionOnOpen = newValue }
    }
    
    var recordVoiceNoteAudioActivity: AudioActivity {
        viewState.recordVoiceNoteAudioActivity
    }
    
    var rejoinGroupAPI: DTInviteToGroupAPI {
        viewState.rejoinGroupAPI
    }
    
    var getGroupInfoAPI: DTGetGroupInfoAPI {
        viewState.getGroupInfoAPI
    }
    
    var groupUpdateMessageProcessor: DTGroupUpdateMessageProcessor {
        viewState.groupUpdateMessageProcessor
    }
    
    var fetchThreadConfigAPI: DTFetchThreadConfigAPI {
        viewState.fetchThreadConfigAPI
    }

    var isReturningFromCallWindow: Bool {
        get { viewState.isReturningFromCallWindow }
        set { viewState.isReturningFromCallWindow = newValue }
    }

    var isScreenOrientationChanging: Bool {
        get { viewState.isScreenOrientationChanging }
        set { viewState.isScreenOrientationChanging = newValue }
    }

    var isFromPersonalCard: Bool {
        get { viewState.isFromPersonalCard }
        set { viewState.isFromPersonalCard = newValue }
    }

    var isFullScreenMode: Bool {
        get { viewState.isFullScreenMode }
        set { viewState.isFullScreenMode = newValue }
    }

    var floatingWindowIsCompactMode: Bool {
        get { viewState.floatingWindowIsCompactMode }
        set { viewState.floatingWindowIsCompactMode = newValue }
    }
}

extension ConversationViewController {
    
    var isGroupConversation: Bool {
        self.thread.isGroupThread()
    }
    
    var isCanSpeak: Bool {
        TSThreadPermissionHelper.checkCanSpeakAndToastTipMessage(self.thread)
    }
    
    var isUserLeftGroup: Bool {
        guard let _ = self.thread as? TSGroupThread else {
            return false
        }
        
        var groupThread: TSGroupThread?
        databaseStorage.read { transaction in
            groupThread = TSGroupThread.anyFetchGroupThread(
                uniqueId: self.thread.uniqueId,
                transaction: transaction
            )
        }
        return !(groupThread?.isLocalUserInGroup() ?? false)
    }
    
    var serverGroupId: String? {
        guard isGroupConversation, let groupThread = thread as? TSGroupThread else {
            return nil
        }
        return TSGroupThread.transformToServerGroupId(
            withLocalGroupId: groupThread.groupModel.groupId
        )
    }
    
    var viewItems: [ConversationViewItem] {
        conversationViewModel.viewState.viewItems
    }
    
    func viewItem(for index: Int) -> ConversationViewItem? {
        guard index >= 0, index < renderItems.count else {
            owsFailDebug("Invalid view item index: \(index)")
            return nil
        }
        let renderItem = renderItems[index]
        return renderItem.viewItem
    }
    
    func viewItem(for uniqueId: String) -> ConversationViewItem? {
        guard let renderItem = renderItem(for: uniqueId) else { return nil }
        return renderItem.viewItem
    }
    
    var renderItemBuilder: ConversationCellRenderItemBuilder {
        viewState.renderItemBuilder
    }
    
    var renderItems: [ConversationCellRenderItem] {
        get { viewState.renderItems }
        set { viewState.renderItems = newValue }
    }
    
    var renderItemsMap: [String: ConversationCellRenderItem] {
        get { viewState.renderItemsMap }
        set { viewState.renderItemsMap = newValue }
    }
    
    func renderItem(for uniqueId: String) -> ConversationCellRenderItem? {
        guard !uniqueId.isEmpty else { return nil }
        return renderItemsMap[uniqueId]
    }
}
