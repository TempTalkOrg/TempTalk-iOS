//
//  DTGroupInCommonController.swift
//  Signal
//
//  Created by Ethan on 24/07/2023.
//  Copyright © 2023 Difft. All rights reserved.
//

import UIKit
import TTMessaging

@objcMembers
class DTGroupInCommonController: OWSViewController {
    
    lazy var searchBar: OWSSearchBar = {
        let searchBar = OWSSearchBar()
        searchBar.customPlaceholder = "Search"
        searchBar.delegate = self
        searchBar.sizeToFit()
        
        return searchBar
    }()
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = Theme.bgpageSecondaryColor
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 0
        tableView.separatorStyle = .none
        tableView.tableHeaderView = searchBar
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.register(HomeViewCell.self, forCellReuseIdentifier: HomeViewCell.cellReuseIdentifier())
        tableView.register(EmptySearchResultCell.self, forCellReuseIdentifier: EmptySearchResultCell.reuseIdentifier)
        
        return tableView
    }()
    
    var resultGroups: [GroupSearchResult]!
    var sortedGroupMembers: [String: String]!
    var leaveGroupHandler: ( ([GroupSearchResult]) -> Void )?
    var recipientId: String?

    private var filteredResultGroups = [GroupSearchResult]()
    
    override func applyTheme() {
        super.applyTheme()
        updateTableContents()
        tableView.backgroundColor = Theme.bgpageSecondaryColor
        view.backgroundColor = Theme.bgpageSecondaryColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = resultGroups.count > 1 ? Localized("GROUP_IN_COMMON_TITLE_GROUPS"): Localized("GROUP_IN_COMMON_TITLE_GROUP")
        view.backgroundColor = Theme.bgpageSecondaryColor
        view.addSubview(tableView)
        tableView.autoPinEdgesToSuperviewSafeArea()
        filteredResultGroups = resultGroups
        updateTableContents()
    }
    
    func updateTableContents() {
        tableView.reloadData()
    }

}

extension DTGroupInCommonController: UISearchBarDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        guard !searchText.isEmpty else {
            filteredResultGroups = resultGroups
            updateTableContents()
            return
        }
        filteredResultGroups.removeAll()
        resultGroups.forEach { resultGroup in
            let lowercasedGroupName = resultGroup.groupName.lowercased()
            let lowercasedSearchText = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if (lowercasedGroupName.contains(lowercasedSearchText)) {
                filteredResultGroups.append(resultGroup)
            }
        }
        updateTableContents()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
    }
    
}

extension DTGroupInCommonController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return filteredResultGroups.isEmpty ? 150 : 70
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredResultGroups.isEmpty ? 1 : filteredResultGroups.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        guard !filteredResultGroups.isEmpty else {
            let cell = tableView.dequeueReusableCell(withIdentifier: EmptySearchResultCell.reuseIdentifier, for: indexPath) as! EmptySearchResultCell
            cell.messageLabel.textColor = Theme.tprimaryColor
            cell.configure(searchState: .noResults)
            
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: HomeViewCell.cellReuseIdentifier(), for: indexPath) as! HomeViewCell
        
        let groupThread = filteredResultGroups[indexPath.row].thread
        cell.configInCommonGroup(with: groupThread, sortedMemberNames: sortedGroupMembers[groupThread.serverThreadId] ?? "", contactsManager: Environment.shared.contactsManager)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
      
        let groupThread = filteredResultGroups[indexPath.row].thread
        DispatchMainThreadSafe { [weak self] in
            let conversationVC = ConversationViewController(thread: groupThread, action: .none)
            guard let self else { return }
            self.navigationController?.pushViewController(conversationVC, animated: true)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.row < filteredResultGroups.count else { return nil }
        let groupThread = filteredResultGroups[indexPath.row].thread
        let groupModel = groupThread.groupModel
        var actions: [UIContextualAction] = []

        if GroupPermissions.hasPermissionToRemoveGroupMembers(groupModel: groupModel) {
            let removeAction = UIContextualAction(style: .normal, title: Localized("REMOVE_MEMBER_GROUP_ACTION")) { [weak self] _, _, completion in
                completion(true)
                guard let self, let recipientId = self.recipientId else { return }
                self.removeMember(recipientId, from: groupThread) { [weak self] in
                    self?.removeGroupFromList(groupThread)
                }
            }
            removeAction.backgroundColor = Theme.bgtooltipColor
            actions.append(removeAction)
        }

        if groupModel.isSelfGroupOwner() {
            let disbandAction = UIContextualAction(style: .destructive, title: Localized("DISBAND_GROUP_ACTION")) { [weak self] _, _, completion in
                completion(true)
                guard let self else { return }
                DTLeaveOrDisbandGroup.leaveOrDisbandGroup(groupThread, viewController: self) { [weak self] in
                    self?.removeGroupFromList(groupThread)
                }
            }
            disbandAction.backgroundColor = Theme.errorColor
            actions.append(disbandAction)
        } else {
            let leaveAction = UIContextualAction(style: .normal, title: Localized("LEAVE_BUTTON_TITLE")) { [weak self] _, _, completion in
                completion(true)
                guard let self else { return }
                DTLeaveOrDisbandGroup.leaveOrDisbandGroup(groupThread, viewController: self) { [weak self] in
                    self?.removeGroupFromList(groupThread)
                }
            }
            leaveAction.backgroundColor = Theme.cautionColor
            actions.append(leaveAction)
        }

        guard !actions.isEmpty else { return nil }
        let config = UISwipeActionsConfiguration(actions: actions)
        config.performsFirstActionWithFullSwipe = false
        return config
    }

    private func removeGroupFromList(_ groupThread: TSGroupThread) {
        filteredResultGroups.removeAll { groupThread.serverThreadId == $0.thread.serverThreadId }
        updateTableContents()
        resultGroups.removeAll { groupThread.serverThreadId == $0.thread.serverThreadId }
        leaveGroupHandler?(resultGroups)
    }

    private func removeMember(_ recipientId: String, from groupThread: TSGroupThread, completion: @escaping () -> Void) {
        DTLeaveOrDisbandGroup.removeMember(recipientId, from: groupThread, viewController: self) {
            completion()
        }
    }
    
}

@objcMembers
open class GroupInCommonSeacher: NSObject {
    
    static let shared = GroupInCommonSeacher()
    
    private lazy var searcher = ConversationSearcher.shared
    private let threadViewHelper = ThreadViewHelper()
    private var contactsManager: OWSContactsManager {
        Environment.shared.contactsManager
    }
    
    private lazy var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    @objc
    func loadInCommonGroups(_ recipientId: String, closure: (([GroupSearchResult]) -> Void)?) {
        AssertIsOnMainThread()
//        operationQueue.cancelAllOperations()

        guard !recipientId.isEmpty else { return }
        guard let closure = closure else { return }

//        operationQueue.addOperation { [weak self] in
//            guard let self else { return }
//
            self.databaseStorage.asyncRead { [weak self] transaction in
                guard let self else { return }
                
                Logger.debug("\(self.logTag) search group in common for \(recipientId)")
                
                let resultSet = self.searcher.queryGroupInCommon(searchText: recipientId, transaction: transaction)

                closure(resultSet.conversations)
                Logger.info("have \(resultSet.conversations.count) group in common")
#if DEBUG
                var resultLog = "\n"
                resultSet.conversations.forEach { result in
                    resultLog += result.groupName + "\n"
                }
                Logger.debug("group in common: \(resultLog)")
#endif
            }
//        }
    }
    
}
