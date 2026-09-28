//
//  CVViewState.swift
//  Signal
//
//  Created by Jaymin on 2024/1/5.
//  Copyright © 2024 Difft. All rights reserved.
//

import UIKit
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

/// Coordinates the first snapshot with the controller's first appearance.
/// Keeping this explicit prevents a provisional empty snapshot from being
/// rendered before the view model's initial load finishes.
enum ConversationInitialLoadPhase {
    case loading
    case ready
    case applying
    case applied
}

/// The semantic destination owned by a scroll-down button tap. Keeping the
/// destination semantic lets us reapply it after an asynchronous snapshot.
enum ConversationScrollDownTarget {
    case unreadIndicator
    case latestMessage
}

/// A programmatic scroll that belongs to a collection update. Like Signal's
/// CVScrollAction, this is carried through the asynchronous render/snapshot
/// pipeline and performed only after the winning generation has landed.
struct ConversationCollectionScrollAction {
    enum Destination {
        case bottomOfLoadWindow
    }

    let destination: Destination
    let isAnimated: Bool
    let userScrollGeneration: UInt64
    let requestGeneration: UInt64
}

/// A stable message-relative viewport position captured before an asynchronous
/// collection update. Unlike an index path or absolute content offset, this
/// remains valid when messages are inserted or cell heights are recomputed.
struct ConversationViewportAnchor {
    let interactionUniqueId: String
    let distanceFromViewportTop: CGFloat
    let userScrollGeneration: UInt64
}

/// Makes the caller's viewport intent explicit. In particular, `.disabled`
/// must not be represented by a nil anchor because nil previously meant
/// "inherit an in-flight anchor".
enum ConversationViewportAnchorPolicy {
    case inherit
    case preserve(ConversationViewportAnchor)
    case disabled
}

/// Coalesces collection updates that land while the conversation is off-screen.
/// Inserts and deletes are represented by the next diffable snapshot; only items
/// that still exist in both snapshots need to be explicitly reloaded.
enum PendingConversationCollectionUpdate: Equatable {
    case none
    case diff(updatedItemIds: Set<String>)
    case reloadAll

    mutating func merge(_ update: PendingConversationCollectionUpdate) {
        switch (self, update) {
        case (_, .none):
            break
        case (.reloadAll, _), (_, .reloadAll):
            self = .reloadAll
        case (.none, .diff(let updatedItemIds)):
            self = .diff(updatedItemIds: updatedItemIds)
        case (.diff(let currentIds), .diff(let updatedItemIds)):
            self = .diff(updatedItemIds: currentIds.union(updatedItemIds))
        }
    }

}

struct InCallVoiceMemoAudioOwnership {
    enum EndAction: Equatable {
        case preserveRecording
        case stopRecording
    }

    private(set) var liveKitOwnedRecordingAtStart = false

    mutating func begin(hasMicrophonePublication: Bool) {
        liveKitOwnedRecordingAtStart = hasMicrophonePublication
    }

    mutating func finish(hasCurrentMicrophonePublication: Bool) -> EndAction {
        defer { liveKitOwnedRecordingAtStart = false }
        return liveKitOwnedRecordingAtStart && hasCurrentMicrophonePublication
            ? .preserveRecording
            : .stopRecording
    }

    mutating func reset() {
        liveKitOwnedRecordingAtStart = false
    }
}

class CVViewState: NSObject {

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
    /// Incremented at the start of every `reloadData`.
    var collectionReloadGeneration: UInt64 = 0
    /// Generation of the most recently committed snapshot. A reload whose generation is older than
    /// this has been superseded on screen and must not overwrite `renderItems`.
    var collectionCommittedGeneration: UInt64 = 0
    /// Reload requirements that a newer generation must inherit until they are committed.
    var collectionReloadIdsByGeneration: [UInt64: Set<String>] = [:]
    /// Viewport anchors that a newer in-flight generation must inherit until one commits.
    var collectionViewportAnchorsByGeneration: [UInt64: ConversationViewportAnchor] = [:]
    /// Layout invalidations that a newer generation must inherit until one commits.
    var collectionLayoutInvalidationGenerations: Set<UInt64> = []
    /// A local-send insert may be followed immediately by a persisted-row update. Both snapshots
    /// are built asynchronously, so the newer update must inherit the original "follow bottom"
    /// intent instead of restoring the pre-insert viewport anchor over the new bubble.
    /// The value is the user-scroll generation that requested the follow; a later drag cancels it.
    var collectionFollowToBottomUserScrollGenerations: [UInt64: UInt64] = [:]
    /// A load-more status change that happened while collection updates were suspended.
    /// The next visible snapshot must invalidate the layout so header/footer heights are rebuilt.
    var pendingConversationLoadMoreHeaderLayoutUpdate = false
    
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
    var isInteractivePopTransitioning = false
    
    var tapGestureRecognizer: UITapGestureRecognizer?
    
    var isViewVisible = false
    var isUserScrolling = false
    var isWaitingForDeceleration = false
    /// Incremented whenever the user starts a drag so an asynchronous reload
    /// cannot restore an anchor captured before that gesture.
    var userScrollGeneration: UInt64 = 0
    // loadInitialMessages completion may arrive before viewIsAppearing flips isViewVisible to true;
    // queue it here and replay from viewIsAppearing to avoid losing the first snapshot.
    var initialLoadPhase: ConversationInitialLoadPhase = .loading
    var pendingInitialLoadCompletion: ((Bool) -> Void)?
    /// UI updates are intentionally not applied while this controller is off-screen.
    /// Preserve their minimum invalidation range so returning from another screen
    /// does not require rebuilding every message cell.
    var pendingConversationCollectionUpdate: PendingConversationCollectionUpdate = .none
    /// Mirrors the normal live-diff behavior: a tail message received while the
    /// user was at the bottom should still be visible when the conversation returns.
    var pendingConversationShouldScrollToBottom = false
    /// Coalesces scroll-down requests made while older/newer items are loading.
    /// A nil value means there is no outstanding request.
    var pendingScrollToBottomAnimated: Bool?
    /// Consumed by the reload triggered by `loadNewest`. Keeping this separate
    /// from the button target prevents an unrelated collection update from
    /// deciding when the bottom animation should begin.
    var scrollActionForNextUpdate: ConversationCollectionScrollAction?
    /// Retained until the button animation completes so a collection reload that
    /// starts during the animation can inherit the same destination.
    var activeScrollDownCollectionAction: ConversationCollectionScrollAction?
    /// Scroll actions owned by in-flight collection generations. Newer
    /// generations inherit an older action so an out-of-order async build cannot
    /// discard the explicit destination.
    var collectionScrollActionsByGeneration: [UInt64: ConversationCollectionScrollAction] = [:]
    /// Invalidates a captured action when another navigation request supersedes it.
    var scrollActionRequestGeneration: UInt64 = 0
    /// While non-nil, collection updates must not restore an older viewport anchor.
    var scrollDownButtonTarget: ConversationScrollDownTarget?
    /// Starting a replacement UIKit animation can synchronously finish the animation it
    /// supersedes. Ignore that stale delegate callback instead of treating it as another
    /// interrupted attempt.
    var isStartingScrollDownAnimation = false
    /// Coalesces interrupted-animation recovery and bounds it so bottom navigation always
    /// converges even if layout keeps invalidating UIKit's animation.
    var isScrollDownAnimationRetryScheduled = false
    var scrollDownAnimationRetryCount = 0

    var viewHasEverAppeared = false
    var shouldAnimateKeyboardChanges = false
    var needsInputToolbarRecreation = false
    var wasInputToolbarFirstResponderBeforeResignActive = false
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
    var dateSeparatorTopOffset: CGFloat?

    // MARK: - Initial Scroll Position Protection
    /// 存储初始滚动到未读消息的目标位置，用于防止键盘闪现导致的位置偏移
    var initialScrollTargetOffset: CGFloat?
    /// 初始滚动保护的截止时间，超过此时间后清除保护
    var initialScrollProtectionDeadline: Date?
    /// The focus handoff may finish only after keyboardDidShow and any in-flight snapshot both complete.
    var isFocusKeyboardPresentationComplete = false
    
    var lastPosition: CGFloat = .zero
    var isScrollUp = false
    var userHasScrolled = false
    /// Set when a GIF is sent from the keyboard panel (which re-presents the system keyboard). The
    /// keyboard's inset is applied asynchronously, so the message-insert scroll can race it and land
    /// the new bubble behind the keyboard. Consumed in `inputAccessoryPlaceholderKeyboardDidPresent`
    /// (inset now final) to re-scroll to bottom deterministically.
    var scrollToBottomOnKeyboardSettle = false
    var lastReloadDate: Date?
    var scrollStateBeforeLoadingMore: ConversationScrollState?
    var mentionMessagesJumpManager: DTMentionMessagesJumpManager?
    
    var lastKnownDistanceFromBottom: CGFloat?
    var scrollContinuity: ScrollContinuity = .bottom
    var scrollUpdateTimer: Timer?

    var isScrollingToTop = false
    
    var actionOnOpen: ConversationViewAction = .none
    
    var shouldObserveDBModifications = false
    var reloadTimer: Timer?
    var isNeedReloadAfterAppEnterForeground = false
        
    var selectThreadTool: SelectThreadTool?
    var actionMessageType: ConversationMessageType?
    weak var actionMenuController: ConversationActionMenuController?
    
    // MARK: Multi-select
    var forwardToolbar: DTMultiSelectToolbar?
    var isMultiSelectMode: Bool = false
    var forwardType: DTForwardMessageType = .oneByOne
    var selectedMessageItems: [ConversationViewItem] = []
    var targetThreads: [TSThread] = []

    // MARK: call
    var isReturningFromCallWindow = false
    var isScreenOrientationChanging = false
    var isFromPersonalCard = false
    var isFullScreenMode = false
    var floatingWindowIsCompactMode = false  // 浮动窗口是否处于compact模式（50%）

    // MARK: photo
    var photoBrowser: DTPhotoBrowserHelper?
    
    // MARK: audio
    var audioPlayer: OWSAudioPlayer?
    /// Multi-tap voice-message recorder (denoise + voice changer candidates).
    var voiceRecorder: DualCandidateVoiceRecorder?
    var voiceMessageUUID: UUID?
    /// Latched on release, consumed by `didFinish`. Reset on every terminal path.
    var pendingVoiceMessageSendMode: VoiceMessageSendMode = .original
    /// True while a voice memo forced LiveKit's ADM to capture (via
    /// `startLocalRecording`) so an in-call *muted* recording can still pick up
    /// the mic. Cleared when `endRecordingSession` restores the prior ownership.
    var didStartInCallLocalRecording: Bool = false
    var inCallVoiceMemoAudioOwnership = InCallVoiceMemoAudioOwnership()
    var currentAudioPlaybackRate: Float? // 当前会话的播放速度，nil 表示使用全局设置
    lazy var recordVoiceNoteAudioActivity: AudioActivity = {
        let activity = AudioActivity(audioDescription: "Voice Message Recording")
        return activity
    }()
    
    // MARK: attachment
    var currentPreviewFileURL: NSURL?
    var attachmentPreviewRequestID: UUID?
    weak var confidentialAttachmentPreviewController: UIViewController?
    
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

    deinit {
        // A staged plaintext copy must not outlive the conversation that decrypted it.
        DTQuickLookPreviewFile.cleanUp(currentPreviewFileURL as URL?)
    }
}

extension ConversationViewController {
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
        guard let groupThread = self.thread as? TSGroupThread else {
            return false
        }
        return !groupThread.isLocalUserInGroup()
    }

    var isUserActivelyTyping: Bool {
        guard let inputToolbar = viewState.inputToolbar else { return false }

        guard inputToolbar.isUserActivelyTyping else { return false }

        return inputAccessoryPlaceholder.keyboardOverlap > 0
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
