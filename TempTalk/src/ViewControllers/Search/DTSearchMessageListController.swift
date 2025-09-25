//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation
import Metal
import SignalCoreKit
import TTMessaging
import UIKit

@objc
class DTSearchMessageListController: UITableViewController {
    @objc public weak var delegate: ConversationSearchViewDelegate?
    @objc public var currentThread: TSThread?
    @objc public var searchText: String = ""
    private var searchResultSet: MessageSearchResultSet = .empty
    private var searcher: ConversationSearcher { ConversationSearcher.shared }

    private var contactsManager: OWSContactsManager { Environment.shared.contactsManager }

    var blockedPhoneNumberSet = Set<String>()
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    private lazy var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    private lazy var searchBar: OWSSearchBar = {
        let searchBar = OWSSearchBar(showsCancel: true)
        searchBar.keyboardAppearance = Theme.keyboardAppearance
        searchBar.customPlaceholder = Localized(
            "HOME_VIEW_CONVERSATION_SEARCHBAR_PLACEHOLDER",
            comment: "Placeholder text for search bar which filters conversations."
        )
        searchBar.sizeToFit()
        searchBar.delegate = self
        return searchBar
    }()
    
    var subheadlineSize: CGFloat {
        return UIFont.preferredFont(forTextStyle: .subheadline).pointSize
    }

    // MARK: View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        let blockingManager = OWSBlockingManager.shared()
        blockedPhoneNumberSet = Set(blockingManager.blockedPhoneNumbers())
        
        setupUI()
        applyTheme()
    
        if !searchText.isEmpty {
            self.searchBar.textField?.insertText(searchText)
        }
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyTheme),
            name: NSNotification.Name.ThemeDidChange,
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.view.setNeedsLayout()
        navigationController?.view.layoutIfNeeded()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if searchBar.canBecomeFirstResponder {
            searchBar.becomeFirstResponder()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        navigationController?.view.setNeedsLayout()
        navigationController?.view.layoutIfNeeded()
        if searchBar.canResignFirstResponder {
            searchBar.resignFirstResponder()
        }
    }
    
    private func setupUI() {
        tableView.separatorStyle = .singleLine;
        tableView.separatorColor = Theme.cellSeparatorColor
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.register(EmptySearchResultCell.self, forCellReuseIdentifier: EmptySearchResultCell.reuseIdentifier)
        tableView.register(HomeViewCell.self, forCellReuseIdentifier: HomeViewCell.cellReuseIdentifier())
        
        navigationItem.setHidesBackButton(true, animated: false)
        navigationItem.titleView = searchBar
        searchBar.showsCancelButton = true
    }
    
    @objc func applyTheme() {
        view.backgroundColor = Theme.backgroundColor
        tableView.backgroundColor = Theme.backgroundColor
        tableView.separatorColor = Theme.cellSeparatorColor
        self.tableView.reloadData()
    }
  
    @objc func yapDatabaseModified(notification: NSNotification) {
        AssertIsOnMainThread()
        refreshSearchResults()
    }

    // MARK: UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        
        guard let searchResult = self.searchResultSet.messages[safe: indexPath.row] else { return }
        
        let viewController = ConversationViewController(
            thread: searchResult.thread.threadRecord,
            action: .none,
            focusMessageId: searchResult.messageId
        )
        navigationController?.pushViewController(viewController, animated: true)
    }

    // MARK: UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Swift.max(self.searchResultSet.messages.count, 1)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let searchResult = self.searchResultSet.messages[safe: indexPath.row] else {
            let cell = EmptySearchResultCell()
            cell.configure(searchState: searchResultSet.searchText.isEmpty ? DTSearchViewState.defaultState : DTSearchViewState.noResults)
            cell.backgroundColor = Theme.tableCellBackgroundColor
            cell.contentView.backgroundColor = Theme.tableCellBackgroundColor
            return cell
        }
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: HomeViewCell.cellReuseIdentifier()) as? HomeViewCell else {
            return UITableViewCell()
        }
        cell.separatorInset = UIEdgeInsets(top: 0, left: 75, bottom: 0, right: 0)
        ///会话消息搜索中authorId有值，首页搜索中为nil
        cell.messageAuthorId = searchResult.authorId
        var overrideSnippet = NSAttributedString()
        let overrideDate = searchResult.messageDate
        if searchResult.messageId != nil {
            // Note that we only use the snippet for message results,
            // not conversation results.  HomeViewCell will generate
            // a snippet for conversations that reflects the latest
            // contents.
            self.databaseStorage.read { transation in
                guard let messageId = searchResult.messageId else {
                  return
                }
                
                guard let message = TSMessage.anyFetchMessage(uniqueId: messageId, transaction: transation) else {
                    overrideSnippet = NSMutableAttributedString.init(string: "")
                    return
                }
                
                let searchText = self.searchResultSet.searchText
                
                guard !searchText.isEmpty else {
                    overrideSnippet = NSMutableAttributedString.init(string: message.body ?? "")
                    return
                }
               
                let snippet = searchResult.snippet ?? searchText
                if let body = message.body, body.lowercased().contains(snippet) {
                    overrideSnippet = NSMutableAttributedString.init(string: body)
                } else if let body = message.quotedMessage?.body, body.lowercased().contains(snippet) {
                    overrideSnippet = NSMutableAttributedString.init(string: body)
                } else if let forwardMessage = message.combinedForwardingMessage {
                    for forward in forwardMessage.subForwardingMessages {
                        guard let body = forward.body, body.lowercased().contains(snippet) else {
                            continue
                        }
                        overrideSnippet = NSMutableAttributedString.init(string: body)
                        break
                    }
                }
            }
        }
        
        cell.configure(withThread: searchResult.thread,
                       contactsManager: contactsManager,
                       blockedPhoneNumber: self.blockedPhoneNumberSet,
                       overrideSnippet: overrideSnippet,
                       overrideDate: overrideDate)
        
        cell.resetUI(forSearch: searchText, thread: searchResult.thread.threadRecord, cellStyle: HomeViewCellStyleTypeSearchNormal)
        return cell
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        // Background color
        // R:0.46 G:0.46 B:0.5 A:0.24
        view.tintColor = UIColor(red: 0.46, green: 0.46, blue: 0.5, alpha: 0.24)
        
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = Theme.secondaryTextAndIconColor
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return subheadlineSize < 17 ? 60 : 70
    }

    // MARK: Update Search Results
    @objc private func refreshSearchResults() {
        AssertIsOnMainThread()
        
        let searchWord = (searchBar.text ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        operationQueue.cancelAllOperations()
        operationQueue.addOperation { [weak self] in
            guard let self else { return }
            
            self.databaseStorage.read { [weak self] in
                guard let self, let thread = self.currentThread else { return }
                
                let searchResultSet = self.searcher.queryMessages(with: searchWord, in: thread, at: $0, loadStrategy: .all)
                
                self.searchResultSet = searchResultSet.searchText == searchWord ? searchResultSet : .empty
                
                DispatchQueue.main.async {
                    self.tableView.separatorStyle = self.searchResultSet.messages.isEmpty ? .none : .singleLine
                    self.tableView.reloadData()
                }
            }
        }
    }

    // MARK: - UIScrollViewDelegate
    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        searchBar.resignFirstResponder()
    }
}

extension DTSearchMessageListController: UISearchBarDelegate {
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        DispatchQueue.main.async {
            guard let cancelBtn = searchBar.value(forKey: "cancelButton") as? UIButton else { return }
            cancelBtn.isEnabled = true
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(refreshSearchResults), object: nil)
        self.perform(#selector(refreshSearchResults), with: nil, afterDelay: 0.1)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        let cancelBtn = searchBar.value(forKey: "cancelButton") as? UIButton
        cancelBtn?.isEnabled = true
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = nil
        searchBar.resignFirstResponder()
        
        navigationController?.popViewController(animated: true)
    }
}


 

