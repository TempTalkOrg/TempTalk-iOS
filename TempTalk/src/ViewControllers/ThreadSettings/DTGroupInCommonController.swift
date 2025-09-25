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
        tableView.backgroundColor = Theme.backgroundColor
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

    private var filteredResultGroups = [GroupSearchResult]()
    
    override func applyTheme() {
        super.applyTheme()
        updateTableContents()
        tableView.backgroundColor = Theme.backgroundColor
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = resultGroups.count > 1 ? Localized("GROUP_IN_COMMON_TITLE_GROUPS"): Localized("GROUP_IN_COMMON_TITLE_GROUP")
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
    
//    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
//        updateTableContents()
//    }
    
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
            cell.messageLabel.textColor = Theme.primaryTextColor
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
//            guard let navigationController = self.navigationController as? OWSNavigationController else {
//                return
//            }
//            navigationController.pushViewController(conversationVC, animated: true, completion: {
//                navigationController.remove(toViewController: "DTHomeViewController")
//            })
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let groupThread = filteredResultGroups[indexPath.row].thread
        let isGroupOwner = (groupThread.groupModel.groupOwner == TSAccountManager.localNumber())
        let leaveTitle = Localized(isGroupOwner ? "CONFIRM_DISBAND" : "LEAVE_BUTTON_TITLE", comment: "member leave group title")
        let leaveAction = UIContextualAction(style: .destructive, title: leaveTitle) { (action, sourceView, completion) -> Void in
            DTLeaveOrDisbandGroup.leaveOrDisbandGroup(groupThread, viewController: self) { [weak self] in
                completion(true)
                guard let self else { return }
                self.filteredResultGroups.remove(at: indexPath.row)
                self.updateTableContents()
                
                self.resultGroups.removeAll {
                    groupThread.serverThreadId == $0.thread.serverThreadId
                }
                guard let leaveGroupHandler = self.leaveGroupHandler else { return }
                leaveGroupHandler(self.resultGroups)
            }
        }
        
        let actionsConfig = UISwipeActionsConfiguration(actions: [leaveAction])
        actionsConfig.performsFirstActionWithFullSwipe = false
        
        return actionsConfig
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
