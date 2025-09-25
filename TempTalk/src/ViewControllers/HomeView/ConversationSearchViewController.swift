//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation
import Metal
import SignalCoreKit
import UIKit
import TTServiceKit
import TTMessaging

enum SearchLocalizeds {
    static var trelated: String {
        Localized(
            "SEARCH_SECTION_TRELATED_MESSAGE",
            comment: "section header for search results that match existing conversations (either group or contact conversations)"
        )
    }
    
    static var include: String {
        Localized(
            "SEARCH_SOMETHING_CONTAIN",
            comment: "A label for conversations with blocked users."
        )
    }
}
 
enum SearchFonts {
    static let body: UIFont = UIFont.ows_dynamicTypeBody
    static let small: UIFont = UIFont.systemFont(ofSize: 11)
}

@objc
class ConversationSearchViewController: UITableViewController {
    private var dataArray: [RenderSection] = []
    
    private lazy var operationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 2
        return queue
    }()
    
    private lazy var searcher = ConversationSearcher.shared
    
    private var contactsManager: OWSContactsManager { Environment.shared.contactsManager }
    
    private var quickSearchResult: SearchResultSet?
    private var searchMessagesResult: SearchResultSet?
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    private lazy var blockedPhoneNumberSet: Set<String> = {
        let blockingManager = OWSBlockingManager.shared()
        return Set(blockingManager.blockedPhoneNumbers())
    }()
    
    private var searchText: String {
        (searchBar.text ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private lazy var searchBar: OWSSearchBar = {
        let searchBar = OWSSearchBar(showsCancel: true)
        searchBar.keyboardAppearance = Theme.keyboardAppearance
        searchBar.customPlaceholder = Localized(
            "HOME_VIEW_CONVERSATION_SEARCHBAR_PLACEHOLDER",
            comment: "Placeholder text for search bar which filters conversations."
        )
        searchBar.delegate = self
        return searchBar
    }()
        
    // MARK: View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let blockingManager = OWSBlockingManager.shared()
        blockedPhoneNumberSet = Set(blockingManager.blockedPhoneNumbers())
    
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyTheme),
            name: NSNotification.Name.ThemeDidChange,
            object: nil
        )
        
        setupUI()
        configTableView()
        applyTheme()
    }
  
    private func setupUI() {
        navigationItem.setHidesBackButton(true, animated: false)
        navigationItem.titleView = searchBar
        UIBarButtonItem.appearance(whenContainedInInstancesOf: [UISearchBar.self]).tintColor = UIColor.ows_darkSkyBlue
    }
    
    private func configTableView() {
        tableView.separatorStyle = .none
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        
        tableView.register(EmptySearchResultCell.self, forCellReuseIdentifier: EmptySearchResultCell.reuseIdentifier)
        tableView.register(HomeViewCell.self, forCellReuseIdentifier: HomeViewCell.cellReuseIdentifier())
        tableView.register(DTMoreSearchResultCell.self, forCellReuseIdentifier: DTMoreSearchResultCell.reuseIdentifier)
        tableView.register(ConversationSearchTableViewCell.self, forCellReuseIdentifier: ConversationSearchTableViewCell.reuseIdentifier)
    }
    
    @objc func applyTheme() {
        view.backgroundColor = Theme.backgroundColor
        tableView.backgroundColor = Theme.backgroundColor
        tableView.separatorColor = Theme.cellSeparatorColor
        let textField : UITextField? = searchBar.textField
        textField?.textColor = Theme.primaryTextColor
        self.tableView.reloadData()
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
    
    private func mergeData(quickSearchResult: SearchResultSet? = nil, searchMessagesResult: SearchResultSet? = nil) {
        let lastSearchText = (self.searchBar.text ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let quickResultSet: SearchResultSet? = {
            let result = quickSearchResult ?? self.quickSearchResult
            if let result, result.searchText == lastSearchText {
                return result
            }
            return nil
        }()
        self.quickSearchResult = quickResultSet
        
        let messagesResultSet: SearchResultSet? = {
            let result = searchMessagesResult ?? self.searchMessagesResult
            if let result, result.searchText == lastSearchText {
                return result
            }
            return nil
        }()
        self.searchMessagesResult = messagesResultSet
        
        if quickResultSet == nil, messagesResultSet == nil {
            mergeRenderData(searchResultSet: .empty)
        } else {
            let result = SearchResultSet(
                searchText: lastSearchText,
                conversations: quickResultSet?.conversations ?? [],
                contacts: quickResultSet?.contacts ?? [],
                messages: messagesResultSet?.messages ?? [],
                recentConversations: quickResultSet?.recentConversations ?? []
            )
            mergeRenderData(searchResultSet: result)
        }
    }

    private func mergeRenderData(searchResultSet: SearchResultSet) {
        guard !searchResultSet.isEmpty else {
            self.dataArray = []
            self.tableView.separatorStyle = .none
            return self.tableView.reloadData()
        }
        DispatchQueue.global().async {
            var dataArray: [RenderSection] = []
            if !searchResultSet.recentConversations.isEmpty {
                let renderRows = self.gengertRecentRows(recents: searchResultSet.recentConversations, keyword: searchResultSet.searchText)
                dataArray.append(.recent(renders: renderRows, results: searchResultSet.recentConversations))
            }
            
            if !searchResultSet.contacts.isEmpty {
                let renderRows = self.gengertContactRows(contacts: searchResultSet.contacts, keyword: searchResultSet.searchText)
                dataArray.append(.contact(renders: renderRows, results: searchResultSet.contacts))
            }
            
            if !searchResultSet.conversations.isEmpty {
                let renderRows = self.gengertGroupRows(groups: searchResultSet.conversations, keyword: searchResultSet.searchText)
                dataArray.append(.group(renders: renderRows, results: searchResultSet.conversations))
            }
            
            if !searchResultSet.filteredMessagesThreads.isEmpty {
                let renderRows = self.gengertMessageRows(
                    threads: searchResultSet.filteredMessagesThreads,
                    messageMap: searchResultSet.filteredMessagesDict
                )
                dataArray.append(.message(renders: renderRows, results: searchResultSet.filteredMessagesThreads, map: searchResultSet.filteredMessagesDict))
            }
            
            DispatchQueue.main.async {
                self.dataArray = dataArray
                self.tableView.separatorStyle = .singleLine
                self.tableView.reloadData()
            }
        }
    }
    
    private func gengertRecentRows(recents: [RecentSearchResult], keyword: String) -> [RenderRow] {
        var renderRows: [RenderRow] = []
        for item in recents {
            let iconRender: IconRender
            if item.thread.isNoteToSelf {
                iconRender = .note(recipientId: item.thread.contactIdentifier().orEmpty)
            } else if let thread = item.thread as? TSGroupThread {
                iconRender = .group(thread: thread, contactsManager: self.contactsManager)
            } else {
                let avatar = item.account?.contact?.avatar as? [String: Any]
                iconRender = .account(avatar: avatar ?? [:], recipientId: item.account?.recipientId ?? "")
            }
            let date = DateUtil.formatDateShort(item.thread.lastMessageDate ?? item.thread.creationDate) // DateUtil.shortDate(from: item.thread.lastMessageDate ?? item.thread.creationDate)
            let threadName = item.thread.isNoteToSelf ? MessageStrings.noteToSelf() : item.threadName
            if threadName.lowercased().contains(keyword) {
                let attribute = gengertAttribute(threadName, match: keyword, font: SearchFonts.body, color: Theme.primaryTextColor)
                renderRows.append(.recent(icon: iconRender, name: .attribute(attribute), lastMessage: .normal(item.lastMessage), date: date))
            } else {
                renderRows.append(.recent(icon: iconRender, name: .normal(threadName), lastMessage: .normal(item.lastMessage), date: date))
            }
        }
        return renderRows
    }
    
    private func gengertContactRows(contacts: [ContactSearchResult], keyword: String) -> [RenderRow] {
        var renderRows: [RenderRow] = []
        for item in contacts where renderRows.count < kDefaultShowMoreNum  {
            guard !item.signalAccount.recipientId.isEmpty, let contact = item.signalAccount.contact else { continue }
            // 过滤非相同 team 的用户
            guard !contact.isExternal else { continue }
            let avatar = contact.avatar as? [String : Any]
            let iconRender: IconRender = .account(avatar: avatar ?? [:], recipientId: item.recipientId)
            let date = TimeZoneUntil.timeZoneFrom(contact: contact).orEmpty
            if contact.fullName.lowercased().contains(keyword) || searcher.noteSearchKey.contains(keyword) {
                var name = contact.fullName
                                if item.recipientId == TSAccountManager.localNumber() {
                                    name = Localized("LOCAL_ACCOUNT_DISPLAYNAME")
                                }
                              
                let attribute = gengertAttribute(name, match: keyword, font: SearchFonts.body, color: Theme.primaryTextColor)
                let others: [String] = [
                    contact.signature, contact.email,
                     item.recipientId
                ].compactMap {
                    guard let result = $0, !result.isEmpty else { return nil }
                    return result
                }
                renderRows.append(.contact(icon: iconRender, name: .attribute(attribute), sign: .normal(others.first.orEmpty), email: .normal(others.second.orEmpty), date: date))
                
            }else if let signature = contact.signature, signature.lowercased().contains(keyword) {
                let attribute = gengertAttribute(signature, match: keyword)
                let others: [String?] = [contact.email,
                                         item.recipientId
                ]
                let shouldRender = others.first { $0?.isEmpty == false } ?? .empty
                renderRows.append(.contact(icon: iconRender, name: .normal(contact.fullName), sign: .attribute(attribute), email: .normal(shouldRender.orEmpty), date: date))
                
            } else if let email = contact.email, email.lowercased().contains(keyword) {
                let attribute = gengertAttribute(email, match: keyword)
                let others: [String] = [
                    contact.signature.orEmpty,
                    item.recipientId
                ]
                guard let firstIndex = others.firstIndex(where: { !$0.isEmpty }) else {
                    renderRows.append(.contact(icon: iconRender, name: .normal(contact.fullName), sign: .attribute(attribute), email: .normal(.empty), date: date))
                    continue
                }
                let shouldRender = others[safe: firstIndex].orEmpty
                let sign: RenderText = firstIndex == 0 ? .normal(shouldRender) : .attribute(attribute)
                let email: RenderText = firstIndex == 0 ? .attribute(attribute) : .normal(shouldRender)
                renderRows.append(.contact(icon: iconRender, name: .normal(contact.fullName), sign: sign, email: email, date: date))
                
            } else if item.recipientId.lowercased().contains(keyword) {
                let attribute = gengertAttribute(item.recipientId, match: keyword)
                let others: [String] = [
                    contact.signature.orEmpty, contact.email.orEmpty,
                ]
                guard let firstIndex = others.firstIndex(where: { !$0.isEmpty }) else {
                    renderRows.append(.contact(icon: iconRender, name: .normal(contact.fullName), sign: .attribute(attribute), email: .normal(.empty), date: date))
                    continue
                }
                let shouldRender = others[safe: firstIndex].orEmpty
                let sign: RenderText = firstIndex == 0 ? .normal(shouldRender) : .attribute(attribute)
                let email: RenderText = firstIndex == 0 ? .attribute(attribute) : .normal(shouldRender)
                renderRows.append(.contact(icon: iconRender, name: .normal(contact.fullName), sign: sign, email: email, date: date))
            }
        }
        if contacts.count >= kDefaultShowMoreNum {
            renderRows.append(.more)
        }
        return renderRows
    }
    
    private func gengertGroupRows(groups: [GroupSearchResult], keyword: String) -> [RenderRow] {
        var renderRows: [RenderRow] = []
        for item in groups where renderRows.count < kDefaultShowMoreNum {
            let iconRender = IconRender.group(thread: item.thread, contactsManager: self.contactsManager)
            if item.accounts.isEmpty, item.groupName.lowercased().contains(keyword) {
                let attribute = gengertAttribute(item.groupName, match: keyword, font: SearchFonts.body, color: Theme.primaryTextColor)
                renderRows.append(.group(icon: iconRender, name: .attribute(attribute), include: .normal(.empty)))
                
            } else if let account = item.accounts.first, let contact = account.contact {
                guard let renderText = [contact.fullName, contact.email, account.recipientId].first(where: { $0?.lowercased().contains(keyword) == true }) else {
                    continue
                }
                let attribute = gengertAttribute(renderText.orEmpty, match: keyword)
                attribute.insert(.init(string: SearchLocalizeds.include), at: 0)
                renderRows.append(.group(icon: iconRender, name: .normal(item.groupName), include: .attribute(attribute)))
            }
        }
        if groups.count >= kDefaultShowMoreNum {
            renderRows.append(.more)
        }
        return renderRows
    }
    
    private func gengertMessageRows(threads: [MessageSearchResult], messageMap: [String:[MessageSearchResult]]) -> [RenderRow] {
        var renderRows: [RenderRow] = []
        for item in threads where renderRows.count < kDefaultShowMoreNum {
            guard let set = messageMap[item.thread.threadRecord.uniqueId], !set.isEmpty else { continue }
            let attribute: NSAttributedString
            if set.count > 1 {
                attribute = NSAttributedString(string: "\(set.count) \(SearchLocalizeds.trelated)")
            } else {
                attribute = NSAttributedString(string: item.body.orEmpty)
            }
            renderRows.append(.message(thread: item.thread, overrideSnippet: attribute, date: item.messageDate))
        }
        if threads.count >= kDefaultShowMoreNum {
            renderRows.append(.more)
        }
        return renderRows
    }
    
    private func gengertAttribute(_ nString: String, match: String, font: UIFont = SearchFonts.small, color: UIColor = Theme.ternaryTextColor) -> NSMutableAttributedString {
        NSMutableAttributedString.covertString(nString, match: match, attributes: [.font: font, .foregroundColor: color], matchAttributes: [.foregroundColor: UIColor.ows_darkSkyBlue])
    }
    
    private func didSelectTableView(renders: [RenderRow], results: [ContactSearchResult], at index: Int) {
        guard let row = renders[safe: index] else { return }
        switch row {
        case .contact:
            guard let result = results[safe: index] else { return }
            
            var thread : TSThread?
            DTToastHelper.showHud(in: view)
            self.databaseStorage.asyncWrite { transation in
                thread = TSContactThread.getOrCreateThread(
                    withContactId: result.recipientId,
                    transaction: transation
                )
                
            } completion: {
                
                DTToastHelper.hide()
                guard let thread = thread else {
                    return
                }
                
                self.pushToConversationViewController(thread: thread, messageId: nil)
            }
        case .more:
            let searchResultListVC = DTSearchResultListController(
                resultStyle: .contacts(results: results),
                hasMore: results.count == ConversationSearcher.LoadStrategy.contact,
                searchText: searchBar.text.orEmpty
            )
            navigationController?.pushViewController(searchResultListVC, animated: true)
        default:
            return
        }
    }
    
    private func didSelectTableView(renders: [RenderRow], results: [GroupSearchResult], at index: Int) {
        guard let row = renders[safe: index] else { return }
        switch row {
        case .group:
            guard let result = results[safe: index] else { return }
            pushToConversationViewController(thread: result.thread, messageId: nil)
        case .more:
            let searchResultListVC = DTSearchResultListController(
                resultStyle: .conversations(results: results),
                hasMore: results.count == ConversationSearcher.LoadStrategy.conversation,
                searchText: searchBar.text.orEmpty
            )
            navigationController?.pushViewController(searchResultListVC, animated: true)
        default:
            return
        }
    }
    
    private func didSelectTableView(renders: [RenderRow], results: [MessageSearchResult], map: [String : [MessageSearchResult]], at index: Int) {
        guard let row = renders[safe: index] else { return }
        switch row {
        case .more:
            let searchResultListVC = DTSearchResultListController(
                resultStyle: .messages(results: results, map: map),
                hasMore: false,
                searchText: searchBar.text.orEmpty
            )
            navigationController?.pushViewController(searchResultListVC, animated: true)
        case .message:
            guard let searchResult = results[safe: index], let recodMessages = map[searchResult.thread.threadRecord.uniqueId], !recodMessages.isEmpty else {
                return
            }
            if recodMessages.count == 1 {
                pushToConversationViewController(
                    thread: searchResult.thread.threadRecord,
                    messageId: recodMessages.first?.messageId
                )
            } else {
                let searchResultsController = DTSearchMessageListController()
                searchResultsController.currentThread = searchResult.thread.threadRecord
                searchResultsController.hidesBottomBarWhenPushed = true
                searchResultsController.searchText = searchBar.text.orEmpty
                navigationController?.pushViewController(searchResultsController, animated: true)
            }
        default:
            return
        }
    }
    
    func pushToConversationViewController(thread:TSThread ,messageId:String? = nil) {
        DispatchMainThreadSafe {
            let viewController = ConversationViewController(thread: thread, action: .none, focusMessageId: messageId)
            self.navigationController?.pushViewController(viewController, animated: true)
        }
    }
    
    // MARK: UITableViewDelegate
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        
        guard let section = self.dataArray[safe: indexPath.section] else { return }
        switch section {
        case .recent(_, let results):
            guard let recent = results[safe: indexPath.row] else { return }
            pushToConversationViewController(thread: recent.thread, messageId: nil)
        case let .contact(renders, results):
            didSelectTableView(renders: renders, results: results, at: indexPath.row)
        case let .group(renders, results):
            didSelectTableView(renders: renders, results: results, at: indexPath.row)
        case let .message(renders, results, map):
            didSelectTableView(renders: renders, results: results, map: map, at: indexPath.row)
        }
    }
    
    // MARK: UITableViewDataSource
    override func numberOfSections(in tableView: UITableView) -> Int {
        Swift.max(self.dataArray.count, 1)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = self.dataArray[safe: section] else {
            return 1
        }
        return section.count
    }

    private func gengertSearchCell(_ tableView: UITableView, with row: RenderRow, at indexPath: IndexPath) -> UITableViewCell {
        switch row {
        case let .recent(icon, name, lastMessage, date):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: ConversationSearchTableViewCell.reuseIdentifier, for: indexPath) as? ConversationSearchTableViewCell else {
                return .init()
            }
            return cell.set(icon: icon)
                .set(name: name)
                .set(last: lastMessage)
                .set(date: date)
                .hidden(sign: true)
                .hidden(last: lastMessage.isEmpty)
                .hidden(date: date.isEmpty)
                .layout()
        case let .contact(icon, name, sign, email, date):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: ConversationSearchTableViewCell.reuseIdentifier, for: indexPath) as? ConversationSearchTableViewCell else {
                return .init()
            }
            return cell.set(icon: icon)
                .set(name: name)
                .set(sign: sign)
                .set(last: email)
                .set(date: date)
                .hidden(sign: sign.isEmpty)
                .hidden(last: email.isEmpty)
                .hidden(date: date.isEmpty)
                .layout()
        case .group(let icon, let name, let include):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: ConversationSearchTableViewCell.reuseIdentifier, for: indexPath) as? ConversationSearchTableViewCell else {
                return .init()
            }
            return cell.set(icon: icon).set(name: name)
                .set(last: include)
                .hidden(sign: true)
                .hidden(last: include.isEmpty)
                .hidden(date: true)
                .layout()
        case let .message(thread, overrideSnippet, date):
            guard let cell = tableView.dequeueReusableCell(withIdentifier: HomeViewCell.cellReuseIdentifier()) as? HomeViewCell else {
                return .init()
            }
            cell.configure(withThread: thread,
                           contactsManager: contactsManager,
                           blockedPhoneNumber: blockedPhoneNumberSet,
                           overrideSnippet: overrideSnippet,
                           overrideDate: date)
            cell.resetUI(forSearch: searchText, thread: thread.threadRecord, cellStyle: HomeViewCellStyleTypeSearchNormal)
            return cell
        case .more:
            return gengertMoreCell(tableView, at: indexPath)
        }
    }
    
    private func gengertMoreCell(_ tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: DTMoreSearchResultCell.reuseIdentifier, for: indexPath) as?  DTMoreSearchResultCell else {
            return .init()
        }
        cell.separatorInset = UIEdgeInsets(top: 0, left: 75, bottom: 0, right: 0)
        cell.backgroundColor = Theme.tableCellBackgroundColor
        cell.contentView.backgroundColor = Theme.tableCellBackgroundColor
        return cell
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = self.dataArray[safe: indexPath.section] else {
            let cell = EmptySearchResultCell()
            cell.configure(searchState: searchText.isEmpty ? DTSearchViewState.defaultState : DTSearchViewState.noResults)
            return cell
        }
    
        guard let row = section.renderRows[safe: indexPath.row] else { return .init() }
        
        return gengertSearchCell(tableView, with: row, at: indexPath)
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        // Background color
        // R:0.46 G:0.46 B:0.5 A:0.24
        view.tintColor = UIColor(red: 0.46, green: 0.46, blue: 0.5, alpha: 0.24)
        
        (view as? UITableViewHeaderFooterView)?.textLabel?.textColor = Theme.secondaryTextAndIconColor
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let section = dataArray[safe: indexPath.section], let row = section.renderRows[safe: indexPath.row] else {
            return UITableView.automaticDimension
        }
        switch row {
        case .message:
            return 60.0
        default:
            return CGFloat.leastNonzeroMagnitude
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let section = dataArray[safe: indexPath.section], let row = section.renderRows[safe: indexPath.row] else {
            return UITableView.automaticDimension
        }
        return row.height
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        dataArray[safe: section]?.title
    }

    // MARK: - UIScrollViewDelegate
    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        searchBar.resignFirstResponder();
    }
    
    // MARK: Update Search Results
    @objc private func refreshSearchResults() {
        AssertIsOnMainThread()
        operationQueue.cancelAllOperations()
        
        let searchWord = (searchBar.text ?? "").lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !searchWord.isEmpty else {
            return self.mergeRenderData(searchResultSet: .empty)
        }
        
        let quickSearchOperation = ConversationQuickSearchOperation(searchWord: searchWord) { [weak self] resultSet in
            guard let self else { return }
            self.mergeData(quickSearchResult: resultSet)
        }
        
        let searchMessagesOperation = ConversationSearchMessagesOperation(searchWord: searchWord) { [weak self] resultSet in
            guard let self else { return }
            self.mergeData(searchMessagesResult: resultSet)
        }
        
        operationQueue.addOperation(quickSearchOperation)
        operationQueue.addOperation(searchMessagesOperation)
    }
    
    deinit {
        Logger.debug("[search] dealloc")
    }
}

extension ConversationSearchViewController: UISearchBarDelegate {
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        DispatchQueue.main.async {
            let cancelBtn = searchBar.value(forKey: "cancelButton") as? UIButton
            cancelBtn?.isEnabled = true
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(refreshSearchResults), object: nil)
        self.perform(#selector(refreshSearchResults), with: nil, afterDelay: 0.15)
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

extension ConversationSearchViewController: ContactsViewHelperDelegate {
    
    func contactsViewHelperDidUpdateContacts() {}
    
    func shouldHideLocalNumber() -> Bool {
        return true
    }
}

extension ConversationSearchViewController {
    typealias RenderText = ConversationSearchTableViewCell.RenderText
    typealias IconRender = ConversationSearchTableViewCell.IconRender
        
    private enum RenderSection {
        case recent(renders: [RenderRow], results: [RecentSearchResult])
        case contact(renders: [RenderRow], results: [ContactSearchResult])
        case group(renders: [RenderRow], results: [GroupSearchResult])
        case message(renders: [RenderRow], results: [MessageSearchResult], map: [String : [MessageSearchResult]])
        
        var title: String {
            switch self {
            case .recent:
                return Localized(
                    "SEARCH_SECTION_CONVERSATIONS_RECENT",
                    comment: "section header for search results that match existing conversations (either group or contact conversations)"
                )
            case .contact:
                return Localized(
                    "SEARCH_SECTION_CONTACTS",
                    comment: "section header for search results that match a contact who doesn't have an existing conversation"
                )
            case .group:
                return Localized(
                    "SEARCH_SECTION_CONVERSATIONS",
                    comment: "section header for search results that match existing conversations (either group or contact conversations)"
                )
            case .message:
                return Localized(
                    "SEARCH_SECTION_MESSAGES",
                    comment: "section header for search results that match a message in a conversation"
                )
            }
        }
        
        var count: Int {
            switch self {
            case .recent(let renders, _):
                return renders.count
            case .contact(let renders, _):
                return renders.count
            case .group(let renders, _):
                return renders.count
            case .message(let renders, _, _):
                return renders.count
            }
        }
        
        var renderRows: [RenderRow] {
            switch self {
            case .recent(let renders, _):
                return renders
            case .contact(let renders, _):
                return renders
            case .group(let renders, _):
                return renders
            case .message(let renders, _, _):
                return renders
            }
        }
    }
    
    private enum RenderRow {
        case recent(icon: IconRender, name: RenderText, lastMessage: RenderText, date: String)
        case contact(icon: IconRender, name: RenderText, sign: RenderText, email: RenderText, date: String)
        case group(icon: IconRender, name: RenderText, include: RenderText)
        case message(thread: ThreadViewModel, overrideSnippet: NSAttributedString, date: Date)
        case more
        
        var subheadlineSize: CGFloat {
            return UIFont.preferredFont(forTextStyle: .subheadline).pointSize
        }
        
        var height: CGFloat {
            switch self {
            case .message:
                return subheadlineSize < 17 ? 60 : 70
            case .more:
                return 46.0
            default:
                return ConversationSearchTableViewCell.cellHeight
            }
        }
    }
}

extension ConversationSearchViewController: OWSNavigationChildController {
    public var childForOWSNavigationConfiguration: OWSNavigationChildController? { nil }

    public var shouldCancelNavigationBack: Bool { false }

    public var preferredNavigationBarStyle: OWSNavigationBarStyle { .solid }

    public var navbarBackgroundColorOverride: UIColor? { nil }

    public var navbarTintColorOverride: UIColor? { nil }

    public var prefersNavigationBarHidden: Bool { false }
}

extension String {
    func nsRange(from range: Range<String.Index>) -> NSRange? {
        guard let from = range.lowerBound.samePosition(in: utf16),
              let to = range.upperBound.samePosition(in: utf16) else { return nil }
        return NSRange(
            location: distance(from: utf16.startIndex, to: from),
            length: distance(from: from, to: to)
        )
    }
    
    static var empty: String = ""
}

extension Optional where Wrapped == String {
    var orEmpty: String {
        self ?? .empty
    }
}

extension Optional where Wrapped == Int {
    var orZero: Int {
        return self ?? .zero
    }
}

public extension Collection where Self.Index == Int {
    var second: Element? {
        guard self.count > 1 else {
            return nil
        }
        return self[1]
    }
}

struct LanguageUnitl {
    static var isChinese: Bool {
        guard let languageCode = Locale.preferredLanguages.first else {
            return false
        }
        return languageCode.hasPrefix("zh-Hant") || languageCode.hasPrefix("yue-Hant")
        || languageCode == "zh-HK" || languageCode == "zh-TW"
        || languageCode.hasPrefix("zh-Hans") || languageCode.hasPrefix("yue-Hans")
    }
}

struct TimeZoneUntil {
    static func convertStringToNumber(value: String) -> NSNumber? {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        return numberFormatter.number(from: value)
    }

    static func timeZoneFrom(contact: Contact) -> String? {
        guard let timeZone = contact.timeZone else { return nil }
        let localZone = NSTimeZone.local
        let localTimeZone = Float(localZone.secondsFromGMT()) / 3600
        let localTimeZoneValueString = String(format: "%.2f", localTimeZone)
        guard let localTimeZoneValue = self.convertStringToNumber(value: localTimeZoneValueString) else {
            return nil
        }
        guard let remoteTimeZoneValue = self.convertStringToNumber(value: timeZone) else {
            return nil
        }
        let components: DateComponents
        if remoteTimeZoneValue.floatValue == localTimeZoneValue.floatValue {
            components = Calendar.current.dateComponents([.hour, .minute, .timeZone], from: Date())
        } else {
            let timeZoneInterval = remoteTimeZoneValue.floatValue - localTimeZoneValue.floatValue
            let remoteDate = Date(timeInterval: Double(timeZoneInterval * 60.0 * 60.0), since: Date())
            components = Calendar.current.dateComponents([.hour, .minute, .timeZone], from: remoteDate)
        }
        
        let hour = components.hour.orZero
        let minute = components.minute.orZero
        let dateStr: String
        if LanguageUnitl.isChinese {
            switch hour {
            case 0:
                dateStr = String(format: "午夜 12:%02lu", minute)
            case 1..<12:
                dateStr = String(format: "%@ %lu:%02lu", Localized("TIME_AM", comment: .empty), hour, minute)
            case 12:
                dateStr = String(format: "中午 %lu:%02lu", hour, minute)
            case 13..<24:
                dateStr = String(format: "%@ %lu:%02lu", Localized("TIME_PM", comment: .empty), hour - 12, minute)
            default:
                dateStr = String(format: "%ld:%02ld", hour, minute)
            }
        } else {
            switch hour {
            case 0:
                dateStr = String(format: "12:%02lu MIDNIGHT", minute)
            case 1..<12:
                dateStr = String(format: "%lu:%02lu %@", hour, minute, Localized("TIME_AM", comment: .empty))
            case 12:
                dateStr = String(format: "%lu:%02lu NOON", hour, minute)
            case 13..<24:
                dateStr = String(format: "%lu:%02lu %@", hour - 12, minute, Localized("TIME_PM", comment: .empty))
            default:
                dateStr = String(format: "%ld:%02ld", hour, minute)
            }
        }
        return dateStr
    }
}

class ConversationQuickSearchOperation: OWSOperation {
    
    private let searchWord: String
    private let completionOnMainThread: (SearchResultSet) -> Void
    
    private let threadViewHelper = ThreadViewHelper()
    private var searcher: ConversationSearcher { ConversationSearcher.shared }
    private var contactsManager: OWSContactsManager { Environment.shared.contactsManager }
    
    init(searchWord: String, completionOnMainThread: @escaping (SearchResultSet) -> Void) {
        self.searchWord = searchWord
        self.completionOnMainThread = completionOnMainThread
        super.init()
    }
    
    override func run() {
        self.databaseStorage.asyncRead { [weak self] transaction in
            guard let self else { return }
            
            Logger.debug("[search] begin search: \(self.searchWord)")
            
            let resultSet = self.searcher.quickQuery(
                searchText: self.searchWord,
                threads: self.threadViewHelper.recentThreads(with: transaction),
                transaction: transaction,
                contactsManager: self.contactsManager
            )
            
            if self.isCancelled {
                self.reportCancelled()
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                if self.isCancelled {
                    self.reportCancelled()
                    return
                }
                
                self.completionOnMainThread(resultSet)
                self.reportSuccess()
            }
        }
    }
}

class ConversationSearchMessagesOperation: OWSOperation {
    
    private let searchWord: String
    private let completionOnMainThread: (SearchResultSet) -> Void
    
    private var searcher: ConversationSearcher { ConversationSearcher.shared }
    private var contactsManager: OWSContactsManager { Environment.shared.contactsManager }
    
    init(searchWord: String, completionOnMainThread: @escaping (SearchResultSet) -> Void) {
        self.searchWord = searchWord
        self.completionOnMainThread = completionOnMainThread
        super.init()
    }
    
    override func run() {
        self.databaseStorage.asyncRead { [weak self] transaction in
            guard let self else { return }
            
            Logger.debug("[search] begin search: \(self.searchWord)")
            
            let messages = self.searcher.queryMessages(
                searchText: self.searchWord,
                transaction: transaction,
                loadStrategy: .limit(count: ConversationSearcher.LoadStrategy.message)
            )
            let resultSet = SearchResultSet(
                searchText: self.searchWord,
                conversations: [],
                contacts: [],
                messages: messages,
                recentConversations: []
            )
            
            if self.isCancelled {
                self.reportCancelled()
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                
                if self.isCancelled {
                    self.reportCancelled()
                    return
                }
                
                self.completionOnMainThread(resultSet)
                self.reportSuccess()
            }
        }
    }
}
