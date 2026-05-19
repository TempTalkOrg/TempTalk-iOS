//
//  HomeViewController+TableView.swift
//  Difft
//
//  Created by Jaymin on 2024/9/19.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit
import SVProgressHUD

@objc
enum HomeViewControllerSection: Int, CaseIterable {
    case reminders
    case virtualThread
    case conversations
    case archiveButton
}

// MARK: - Diffable DataSource
class HomePageDataSource: UITableViewDiffableDataSource<HomeViewControllerSection, String> {
    
    var threadMapping: ThreadMapping?
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        guard let threadMapping else {
            return false
        }
        guard let section = HomeViewControllerSection(rawValue: indexPath.section) else {
            return false
        }
        switch section {
        case .conversations:
            if let thread = threadMapping.thread(indexPath: indexPath), !thread.isCallingSticked {
                return true
            } else {
                return false
            }
        default:
            return false
        }
    }
}

extension HomeViewController {
    
    enum ReloadRange: Equatable {
        case all
        case part(uniqueIds: Set<String>)
        case none
        
        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.all, .all):
                return true
            case (.none, .none):
                return true
            case (.part(let lhsIds), .part(let rhsIds)):
                return lhsIds == rhsIds
            default:
                return false
            }
        }
    }
    
    private struct AssociatedKeys {
        static var dataSource: UInt8 = 0
        static var hasVisibleReminders: UInt8 = 1
        static var hasArchivedThreadsRow: UInt8 = 2
    }
    
    private var dataSource: HomePageDataSource {
        if let dataSource = objc_getAssociatedObject(self, &AssociatedKeys.dataSource) as? HomePageDataSource {
            return dataSource
        }
        let dataSource = createDiffableDataSource()
        objc_setAssociatedObject(self, &AssociatedKeys.dataSource, dataSource, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return dataSource
    }
    
    private func createDiffableDataSource() -> HomePageDataSource {
        let dataSource = HomePageDataSource(
            tableView: self.tableView,
            cellProvider: { [weak self] tableView, indexPath, itemIdentifier in
                guard let self, let section = HomeViewControllerSection(rawValue: indexPath.section) else {
                    return UITableViewCell()
                }
                switch section {
                case .reminders:
                    return self.reminderViewCell
                case .virtualThread:
                    return virtualCell(for: itemIdentifier)
                case .conversations:
                    return conversationCell(for: itemIdentifier)
                case .archiveButton:
                    return archivedCell()
                }
            }
        )
        dataSource.threadMapping = self.threadMapping
        return dataSource
    }
    
    // 全量刷新
    @objc func fullReloadData(animated: Bool, completion: (() -> Void)?) {
        reloadData(forceReloadRange: .all, animated: animated, completion: completion)
    }
    
    // 差量刷新
    @objc func diffReloadData(forceReloadItemIds: Set<String>?, animated: Bool, completion: (() -> Void)?) {
        var forceReloadRange: ReloadRange = .none
        if let forceReloadItemIds, !forceReloadItemIds.isEmpty {
            forceReloadRange = .part(uniqueIds: forceReloadItemIds)
        }
        reloadData(forceReloadRange: forceReloadRange, animated: animated, completion: completion)
    }
    
    private func reloadData(
        forceReloadRange: ReloadRange,
        animated: Bool,
        completion: (() -> Void)? = nil
    ) {
        let reminderIds = self.hasVisibleReminders ? ["reminderId"] : []
        let virtualThreadIds = self.threadMapping.virtualThreadIds
        let threadIds = self.threadMapping.threadIds
        let archivedThreadIds = self.hasArchivedThreadsRow ? ["archivedThread"] : []
        
        var newSnapshot = NSDiffableDataSourceSnapshot<HomeViewControllerSection, String>()
        newSnapshot.appendSections(HomeViewControllerSection.allCases)
        newSnapshot.appendItems(reminderIds, toSection: .reminders)
        newSnapshot.appendItems(virtualThreadIds, toSection: .virtualThread)
        newSnapshot.appendItems(threadIds, toSection: .conversations)
        newSnapshot.appendItems(archivedThreadIds, toSection: .archiveButton)
        
        if forceReloadRange != .none {
            let oldSnapshot = self.dataSource.snapshot()
            let oldItemIds = oldSnapshot.itemIdentifiers
            
            // 获取 thread 新旧快照的交集
            let threadIntersectionIds = Set(threadIds).intersection(Set(oldItemIds))
            // 获取 virtual thread 新旧快照的交集
            let virtualThreadIntersectionIds = Set(virtualThreadIds).intersection(Set(oldItemIds))
            
            // 获取需要强制刷新的 item id
            var forceReloadItemIds: [String] = []
            switch forceReloadRange {
            case .all:
                // 刷新全部 = thread 新旧快照的交集 + virtual thread 新旧快照的交集，一定要刷新交集，否则会 crash
                forceReloadItemIds = Array(threadIntersectionIds.union(virtualThreadIntersectionIds))
            case .part(let itemIds):
                // 刷新部分 = (thread 新旧快照的交集 + virtual thread 新旧快照的交集) 与 part 指定的 itemIds 的交集
                let needReloadThreadIds = threadIntersectionIds.filter { itemIds.contains($0) }
                let needReloadVirtualThreadIds = virtualThreadIntersectionIds.filter { itemIds.contains($0) }
                forceReloadItemIds = Array(needReloadThreadIds.union(needReloadVirtualThreadIds))
            default:
                break
            }

            if !forceReloadItemIds.isEmpty {
                // 使用 reconfigureItems 代替 reloadItems 来避免 cell 重新创建
                if #available(iOS 15.0, *) {
                    newSnapshot.reconfigureItems(forceReloadItemIds)
                } else {
                    newSnapshot.reloadItems(forceReloadItemIds)
                }
            }
        }

        self.dataSource.apply(newSnapshot, animatingDifferences: false) {
            if let completion {
                completion()
            }
        }
    }
}

// MARK: - TableView
extension HomeViewController {
    
    @objc func createTableView() -> UITableView {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.verticalScrollIndicatorInsets = .init(top: -1.0, left: 0, bottom: 0, right: 0)
        tableView.separatorStyle = .singleLine
        tableView.separatorInset = .init(top: 0, left: 75, bottom: 0, right: 0)
        tableView.contentInsetAdjustmentBehavior = .always
        tableView.register(HomeViewCell.self, forCellReuseIdentifier: HomeViewCell.cellReuseIdentifier())
        tableView.register(DTHomeVirtualCell.self, forCellReuseIdentifier: DTHomeVirtualCell.cellReuseIdentifier())
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "kArchivedConversationsReuseIdentifier")
        
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .gray
        refreshControl.addTarget(self, action: #selector(pullToRefresh(_:)), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        return tableView
    }
    
    @objc func pullToRefresh(_ sender: UIRefreshControl) {
        AssertIsOnMainThread()
        Logger.info("beginning refreshing")
        SignalApp.shared().messageFetcherJob.run().promise.ensure {
            Logger.info("ending refreshing")
            sender.endRefreshing()
        }.cauterize()
    }
    
    @objc func resetLastViewedThreadPosition() {
        guard let lastViewedThread else { return }
        let threadId = lastViewedThread.uniqueId
        scrollToThread(threadId: threadId)
    }
    
    func scrollToThread(
        threadId: String,
        scrollPosition: UITableView.ScrollPosition = .none,
        animated: Bool = false
    ) {
        let snapshot = self.dataSource.snapshot()
        guard let section = snapshot.indexOfSection(.conversations), let row = snapshot.indexOfItem(threadId) else {
            return
        }
        
        if section < tableView.numberOfSections,
           row < tableView.numberOfRows(inSection: section) {
            let indexPath = IndexPath(row: row, section: section)
            tableView.scrollToRow(at: indexPath, at: scrollPosition, animated: animated)
        } else {
            Logger.warn("⚠️ Attempted to scroll to an out-of-bounds row: \(row) in section: \(section)")
        }
        
    }
}

// MARK: - Cell
extension HomeViewController {
    
    var contactsManager: OWSContactsManager {
        Environment.shared.contactsManager
    }
    
    private var hasVisibleReminders: Bool {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.hasVisibleReminders) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.hasVisibleReminders, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    private var hasArchivedThreadsRow: Bool {
        get {
            objc_getAssociatedObject(self, &AssociatedKeys.hasArchivedThreadsRow) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.hasArchivedThreadsRow, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    @objc func createReminderCell() -> HomeReminderViewCell {
        let cell = HomeReminderViewCell()
        cell.delegate = self
        return cell
    }
    
    @objc func updateReminderViews() {
        let isShowArchive = self.homeViewMode == .archive
        // App is killed and restarted when the user changes their contact permissions, so need need to "observe" anything
        // to re-render this.
        
        let isShowDeregistered = TSAccountManager.sharedInstance().isDeregistered() && !isShowArchive
        let isShowOutage = self.outageDetection.hasOutage
        self.reminderViewCell.update(
            isShowDeregisteredView: isShowDeregistered,
            isShowOutageView: isShowOutage,
            isShowArchiveView: isShowArchive
        )
        
        self.hasVisibleReminders = isShowArchive || isShowOutage || isShowDeregistered
        
        if self.viewDidAppear {
            DispatchQueue.main.async {
                self.diffReloadData(forceReloadItemIds: nil, animated: false, completion: nil)
            }
        }
    }
    
    private func conversationCell(for identifier: String) -> UITableViewCell {
        guard let cell = self.tableView.dequeueReusableCell(withIdentifier: HomeViewCell.cellReuseIdentifier()) as? HomeViewCell else {
            return UITableViewCell()
        }
        guard let threadViewModel = threadViewModel(for: identifier) else {
            return UITableViewCell()
        }
        cell.isShowSticked = true
        cell.shouldObserveMeeting = true
        cell.messageAuthorId = nil
        cell.meetingBarDelegate = self
        cell.configure(
            withThread: threadViewModel,
            contactsManager: self.contactsManager,
            blockedPhoneNumber: self.blockedPhoneNumberSet
        )
        return cell
    }
    
    private func threadViewModel(for identifier: String) -> ThreadViewModel? {
        guard threadMapping.thread(for: identifier) != nil else {
            Logger.error("can not find thread for identifier: \(identifier)")
            return nil
        }

        if let cachedThreadViewModel = self.threadViewModelCache.object(forKey: identifier as NSString) {
            return cachedThreadViewModel
        }

        var newThreadViewModel: ThreadViewModel?
        self.databaseStorage.uiRead { transaction in
            guard let freshThread = TSThread.anyFetch(uniqueId: identifier, transaction: transaction) else {
                return
            }
            newThreadViewModel = ThreadViewModel(thread: freshThread, transaction: transaction)
        }
        if let newThreadViewModel {
            self.threadViewModelCache.setObject(newThreadViewModel, forKey: identifier as NSString)
        }
        return newThreadViewModel
    }
    
    private func virtualCell(for identifier: String) -> UITableViewCell {
        guard let cell = self.tableView.dequeueReusableCell(withIdentifier: DTHomeVirtualCell.cellReuseIdentifier()) as? DTHomeVirtualCell else {
            return UITableViewCell()
        }
        guard let virtualThread = threadMapping.virtualThread(for: identifier) else {
            Logger.error("can not find virtual thread for identifier: \(identifier)")
            return UITableViewCell()
        }
        cell.meetingBarDelegate = self;
        cell.config(with: virtualThread)
        return cell
    }
    
    private func archivedCell() -> UITableViewCell {
        let specialAccount = SignalAccount(recipientId: "HOME_ARCHIVE")
        specialAccount.contact = Contact(fullName: Localized("HOME_VIEW_ARCHIVED_CONVERSATIONS"), phoneNumber: "HOME_ARCHIVE")
        let cell = ContactTableViewCell()
        cell.configure(withSpecialAccount: specialAccount)
        return cell
    }
    
    @objc func updateHasArchivedThreadsRow() {
        // 不显示"已归档会话"入口
        self.hasArchivedThreadsRow = false
    }
}

protocol HomeReminderViewCellDelegate: AnyObject {
    func reminderCellDidTapDeregisteredView(_ cell: HomeReminderViewCell)
}

class HomeReminderViewCell: UITableViewCell {
    
    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        return stackView
    }()
    
    private lazy var deregisteredView: ReminderView = {
        let text = Localized("DEREGISTRATION_WARNING").appending(Localized("DEREGISTRATION_RE-REGISTRATION"))
        let view = ReminderView.nag(text: text) { [weak self] in
            guard let self else { return }
            self.delegate?.reminderCellDidTapDeregisteredView(self)
        }
        return view
    }()
    
    private lazy var outageView: ReminderView = {
        let view = ReminderView.nag(text: Localized("OUTAGE_WARNING"), tapAction: nil)
        return view
    }()
    
    private lazy var archiveView: ReminderView = {
        let view = ReminderView.explanation(text: Localized("INBOX_VIEW_ARCHIVE_MODE_REMINDER"))
        return view
    }()
    
    weak var delegate: HomeReminderViewCellDelegate?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        selectionStyle = .none
        
        stackView.addArrangedSubviews([deregisteredView, outageView, archiveView])
        contentView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
    }
    
    func update(
        isShowDeregisteredView: Bool,
        isShowOutageView: Bool,
        isShowArchiveView: Bool
    ) {
        archiveView.isHidden = !isShowArchiveView
        deregisteredView.isHidden = !isShowDeregisteredView
        outageView.isHidden = !isShowOutageView
        
        stackView.arrangedSubviews.forEach {
            if let subStackView = $0 as? UIStackView, !subStackView.isHidden {
                subStackView.setNeedsLayout()
                subStackView.layoutIfNeeded()
            }
        }
    }
    
    @objc func applyTheme() {
        outageView.applyTheme()
        deregisteredView.applyTheme()
        archiveView.applyTheme()
    }
}

extension HomeViewController: HomeReminderViewCellDelegate {
    func reminderCellDidTapDeregisteredView(_ cell: HomeReminderViewCell) {
        RegistrationUtils.showReregistrationUI(from: self)
    }
}

// MARK: - UITableViewDelegate
extension HomeViewController: UITableViewDelegate {
    
    var currentGroup: String {
        switch self.homeViewMode {
        case .inbox:
            return AnyThreadFinder.inboxGroup
        case .archive:
            return AnyThreadFinder.archiveGroup
        default:
            return .empty
        }
    }

    var subheadlineSize: CGFloat {
        // 使用固定字体大小（15pt），忽略系统 Dynamic Type
        let baseSize: CGFloat = 15.0
        let scaleFactor = TextSizeManager.currentScaleFactor
        return baseSize * scaleFactor
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == HomeViewControllerSection.reminders.rawValue {
            return UITableView.automaticDimension
        }

        // 根据 App 内字体大小设置计算 cell 高度
        // 默认模式：60pt，大字体模式：70pt
        let scaleFactor = TextSizeManager.currentScaleFactor
        if scaleFactor > 1.0 {
            // 大字体模式
            return 70
        } else {
            // 默认模式
            return 60
        }
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let section = HomeViewControllerSection(rawValue: indexPath.section) else {
            return
        }
        switch section {
        case .conversations:
            guard let thread = self.threadMapping.thread(indexPath: indexPath) else {
                return
            }
            self.clearUnreadBadge(for: thread)
            if self.homeViewMode == .inbox {
                self.present(thread, action: .none)
            } else {
                let conversationVC = ConversationViewController(
                    thread: thread,
                    action: .none,
                    focusMessageId: nil,
                    botViewItem: nil,
                    viewMode: .main
                )
                self.navigationController?.pushViewController(conversationVC, animated: true)
            }
            
        case .archiveButton:
            let homeVC = HomeViewController()
            homeVC.homeViewMode = .archive
            self.navigationController?.pushViewController(homeVC, animated: true)
            
        default:
            break
        }
    }
    
    public func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard self.isViewLoaded && self.view.window != nil else {
            return nil
        }
        
        guard let section = HomeViewControllerSection(rawValue: indexPath.section) else {
            return nil
        }
        switch section {
        case .conversations:
            guard let thread = self.threadMapping.thread(indexPath: indexPath) else {
                return nil
            }
            var actions: [UIContextualAction] = []
            // 只有处于全部分组可以删除会话，处于分组时可以把会话移出分组（推荐分组会话不能手动移出）
            var deleteTitle = Localized("TXT_DELETE_TITLE")
            // 防止 Accessibility bug：title 不能为空，否则会崩溃
            if deleteTitle.isEmpty {
                deleteTitle = "Delete"
            }
            let deleteAction = UIContextualAction(
                style: .destructive,
                title: deleteTitle
            ) { [weak self] action, sourceView, completion in
                guard let self else {
                    completion(true)
                    return
                }
                self.tableViewCellDidTapDelete(indexPath: indexPath)
                completion(true)
            }
            deleteAction.backgroundColor = .systemRed
            deleteAction.image = nil  // 明确设置 image 为 nil，避免 UIKit 创建默认图像视图导致崩溃
            actions.append(deleteAction)
            
            if self.homeViewMode != .archive {
                let stickActionTitle = thread.isSticked ? Localized("HOME_TABLE_ACTION_UNSTICK") : Localized("HOME_TABLE_ACTION_STICK")
                let stickAction = UIContextualAction(
                    style: .normal,
                    title: stickActionTitle
                ) { [weak self] action, sourceView, completion in
                    guard let self else {
                        completion(true)
                        return
                    }
                    self.stickThread(indexPath: indexPath)
                    completion(true)
                }
                stickAction.backgroundColor = .ows_gray25
                actions.append(stickAction)
                
                if let threadViewModel = threadViewModel(for: thread.uniqueId) {
                    let readAction = self.getUnreadContextualAction(indexpath: indexPath, threadViewModel: threadViewModel)
                    actions.append(readAction)
                }
            }
            
            let config = UISwipeActionsConfiguration(actions: actions)
            config.performsFirstActionWithFullSwipe = false
            return config
            
        default:
            return nil
        }
    }
    
    public func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard self.isViewLoaded && self.view.window != nil else {
            return nil
        }

        guard let section = HomeViewControllerSection(rawValue: indexPath.section) else {
            return nil
        }
        switch section {
        case .conversations:
            guard let thread = self.threadMapping.thread(indexPath: indexPath) else {
                return nil
            }
            var actions: [UIContextualAction] = []
            if let groupThread = thread as? TSGroupThread, groupThread.isLocalUserInGroup() {
                let isOwner = groupThread.groupModel.groupOwner == TSAccountManager.localNumber()
                var title = Localized(isOwner ? "CONFIRM_DISBAND" : "LEAVE_BUTTON_TITLE")
                // 防止 Accessibility bug：title 不能为空，否则会崩溃
                if title.isEmpty {
                    title = "Disband or Leave"
                }
                let leaveAction = UIContextualAction(
                    style: .destructive,
                    title: title
                ) { [weak self] action, sourceView, completion in
                    guard let self else {
                        completion(true)
                        return
                    }
                    DTLeaveOrDisbandGroup.leaveOrDisbandGroup(
                        groupThread,
                        viewController: self,
                        needAlert: isOwner
                    )
                    completion(true)
                }
                leaveAction.backgroundColor = .systemRed
                leaveAction.image = nil  // 明确设置 image 为 nil，避免 UIKit 创建默认图像视图导致崩溃
                actions.append(leaveAction)
            }

            // 如果没有任何 action，返回 nil 避免 iOS 内部崩溃
            guard !actions.isEmpty else {
                return nil
            }

            let config = UISwipeActionsConfiguration(actions: actions)
            config.performsFirstActionWithFullSwipe = false
            return config

        default:
            return nil
        }
    }

    private func tableViewCellDidTapDelete(indexPath: IndexPath) {
        guard indexPath.section == HomeViewControllerSection.conversations.rawValue else {
            Logger.error("failure: unexpected section: \(indexPath.section)")
            return
        }
        guard let thread = self.threadMapping.thread(indexPath: indexPath) else {
            Logger.error("can not find thread for indexPath: \(indexPath)")
            return
        }
        
        DTToastHelper.svShow()
        self.databaseStorage.asyncWrite { transaction in
            thread.removeAllThreadInteractions(with: transaction)
            thread.anyUpdate(transaction: transaction) { instantce in
                instantce.isRemovedFromConversation = true
                instantce.unstickThread()
            }
            transaction.addAsyncCompletionOffMain {
                DTToastHelper.dismiss(withDelay: 0.3)
            }
        }
        self.updateViewState()
    }
}

// MARK: - DTMeetingBarDeleagate
extension HomeViewController: DTMeetingBarTapDelegate {
    
    public func didTapMeetingBar(with thread: TSThread) {
        Logger.info("\(logTag) click meetingbar")
        if let targetCall = DTMeetingManager.shared.currentThreadTargetCall(thread)  {
            Logger.info("\(logTag) didTapMeetingBar acceptCall")
            DispatchMainThreadSafe {
                DTToastHelper.show01LoadingHudIsDark(Theme.isDarkThemeEnabled, in: nil)
            }
            DTMeetingManager.shared.acceptCall(call: targetCall)
            return
        }
    }
}
