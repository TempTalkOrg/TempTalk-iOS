//
//  DTConversationSearchList.swift
//  Wea
//
//  Created by hornet on 2022/5/2.
//  Copyright © 2022 Difft. All rights reserved.
//

import UIKit

@objc
class DTSearchResultListController: OWSViewController , UITableViewDelegate , UITableViewDataSource {
    private let searchText: String
    private var resultStyle: ResultStyle
    private let hasMore: Bool
    private var dataArray: [RenderRow] = []
    private lazy var searcher: ConversationSearcher = .shared
    private lazy var blockedPhoneNumberSet: Set<String> = {
        let blockingManager = OWSBlockingManager.shared()
        return Set(blockingManager.blockedPhoneNumbers())
    }()
    
    private var contactsManager: OWSContactsManager {
        return Environment.shared.contactsManager
    }
        
    private lazy var tableView: UITableView = {
        tableView = UITableView.init()
        tableView.separatorStyle = .none;
        tableView.delegate = self
        tableView.dataSource = self
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.register(HomeViewCell.self, forCellReuseIdentifier: HomeViewCell.cellReuseIdentifier())
        tableView.register(ConversationSearchTableViewCell.self, forCellReuseIdentifier: ConversationSearchTableViewCell.reuseIdentifier)
        return tableView
    }()
    
    private lazy var searchWord = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    
    public init(resultStyle: ResultStyle, hasMore: Bool, searchText: String) {
        self.resultStyle = resultStyle
        self.hasMore = hasMore
        self.searchText = searchText
        
        super.init()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = resultStyle.title
        
        view.addSubview(self.tableView)
        
        setupUI()
        mergeRenderData(resultStyle: resultStyle)
        loadMoreIfNeed()
        applyTheme()
    }
  
    private func setupUI() {
        navigationItem.setHidesBackButton(false, animated: false)
        view.addSubview(self.tableView)
        tableView.autoPinEdge(toSuperviewSafeArea: .top)
        tableView.autoPinEdge(ALEdge.left, to: ALEdge.left, of: view)
        tableView.autoPinEdge(ALEdge.right, to: ALEdge.right, of: view)
        tableView.autoPinEdge(ALEdge.bottom, to: ALEdge.bottom, of: view)
    }

    private func loadMoreIfNeed() {
        guard hasMore else { return }
        
        guard !searchWord.isEmpty else {
            self.dataArray = []
            self.tableView.reloadData()
            return
        }
        
        switch self.resultStyle {
        case .contacts:
            var result: [ContactSearchResult] = []
            databaseStorage.asyncRead(block: { [weak self] transaction in
                guard let self else { return }
                result = self.searcher.queryContacts(
                    searchText: self.searchWord,
                    transaction: transaction,
                    contactsManager: self.contactsManager,
                    loadStrategy: .all
                )
            }, completionQueue: DispatchQueue.main) {
                self.mergeRenderData(resultStyle: .contacts(results: result))
            }
        case .conversations:
            var result: [GroupSearchResult] = []
            databaseStorage.asyncRead(block: { [weak self] transaction in
                guard let self else { return }
                result = self.searcher.queryConversations(
                    searchText: self.searchWord,
                    transaction: transaction,
                    loadStrategy: .all
                )
            }, completionQueue: DispatchQueue.main) {
                self.mergeRenderData(resultStyle: .conversations(results: result))
            }
        default:
            break
        }
    }
    
    private func mergeRenderData(resultStyle: ResultStyle) {
        guard !resultStyle.isEmpty else {
            self.dataArray = []
            self.tableView.separatorStyle = .none
            return self.tableView.reloadData()
        }
        let searchWord = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        DispatchQueue.global().async {
            let dataArray: [RenderRow]
            switch resultStyle {
            case .contacts(let results):
                dataArray = self.gengertContactRows(contacts: results, keyword: searchWord)
            case .conversations(let results):
                dataArray = self.gengertGroupRows(groups: results, keyword: searchWord)
            case .messages(let results, let map):
                dataArray = self.gengertMessageRows(threads: results, messageMap: map)
            }
            DispatchQueue.main.async {
                self.resultStyle = resultStyle
                self.dataArray = dataArray
                self.tableView.separatorStyle = .singleLine
                self.tableView.separatorInset = UIEdgeInsets(top: 0, left: 75, bottom: 0, right: 0)
                self.tableView.reloadData()
            }
        }
    }
    
    private func gengertContactRows(contacts: [ContactSearchResult], keyword: String) -> [RenderRow] {
        var renderRows: [RenderRow] = []
        for item in contacts {
            guard !item.signalAccount.recipientId.isEmpty, let contact = item.signalAccount.contact else { continue }
            let avatar = contact.avatar as? [String : Any]
            let iconRender: IconRender = .account(avatar: avatar ?? [:], recipientId: item.recipientId)
            let date = TimeZoneUntil.timeZoneFrom(contact: contact).orEmpty
            if contact.fullName.lowercased().contains(keyword) {
                let attribute = gengertAttribute(contact.fullName, match: keyword, font: SearchFonts.body, color: Theme.primaryTextColor)
                let others: [String] = [
                    contact.signature, contact.email, item.recipientId
                ].compactMap {
                    guard let result = $0, !result.isEmpty else { return nil }
                    return result
                }
                renderRows.append(.contact(icon: iconRender, name: .attribute(attribute), sign: .normal(others.first.orEmpty), email: .normal(others.second.orEmpty), date: date))
                
            }else if let signature = contact.signature, signature.lowercased().contains(keyword) {
                let attribute = gengertAttribute(signature, match: keyword)
                let others: [String?] = [contact.email, item.recipientId
                ]
                let shouldRender = others.first { $0?.isEmpty == false } ?? .empty
                renderRows.append(.contact(icon: iconRender, name: .normal(contact.fullName), sign: .attribute(attribute), email: .normal(shouldRender.orEmpty), date: date))
                
            } else if let email = contact.email, email.lowercased().contains(keyword) {
                let attribute = gengertAttribute(email, match: keyword)
                let others: [String] = [
                    contact.signature.orEmpty, item.recipientId
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
        return renderRows;
    }
    
    private func gengertGroupRows(groups: [GroupSearchResult], keyword: String) -> [RenderRow] {
        var renderRows: [RenderRow] = []
        for item in groups {
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
        return renderRows
    }
    
    private func gengertMessageRows(threads: [MessageSearchResult], messageMap: [String:[MessageSearchResult]]) -> [RenderRow] {
        var renderRows: [RenderRow] = []
        for item in threads {
            guard let set = messageMap[item.thread.threadRecord.uniqueId], !set.isEmpty else { continue }
            let attribute: NSAttributedString
            if set.count > 1 {
                attribute = NSAttributedString(string: "\(set.count) \(SearchLocalizeds.trelated)")
            } else {
                attribute = NSAttributedString(string: item.body.orEmpty)
            }
            renderRows.append(.message(thread: item.thread, overrideSnippet: attribute, date: item.messageDate))
        }
        return renderRows
    }
    
    private func gengertAttribute(_ nString: String, match: String, font: UIFont = SearchFonts.small, color: UIColor = Theme.ternaryTextColor) -> NSMutableAttributedString {
        NSMutableAttributedString.covertString(nString, match: match, attributes: [.font: font, .foregroundColor: color], matchAttributes: [.foregroundColor: UIColor.ows_darkSkyBlue])
    }
    
    override func applyTheme() {
        view.backgroundColor = Theme.backgroundColor
        tableView.backgroundColor = Theme.backgroundColor
        tableView.separatorColor = Theme.cellSeparatorColor
        self.tableView.reloadData()
    }
    
    // MARK: UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch resultStyle {
        case .contacts(let results):
            guard let result = results[safe: indexPath.row] else { return }
            databaseStorage.write { transation in
                let thread = TSContactThread.getOrCreateThread(
                    withContactId: result.recipientId,
                    transaction: transation
                )
                self.pushToConversationViewController(thread: thread)
         }
        case .conversations(let results):
            guard let result = results[safe: indexPath.row] else { return }
            pushToConversationViewController(thread: result.thread)
        case .messages(let results, let map):
            guard let searchResult = results[safe: indexPath.row], let recodMessages = map[searchResult.thread.threadRecord.uniqueId], !recodMessages.isEmpty else {
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
                searchResultsController.searchText = searchText
                navigationController?.pushViewController(searchResultsController, animated: true)
            }
        }
    }

    func pushToConversationViewController(thread:TSThread ,messageId:String? = nil) {
        DispatchMainThreadSafe {
            let viewController = ConversationViewController(thread: thread, action: .none, focusMessageId: messageId)
            self.navigationController?.pushViewController(viewController, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        dataArray.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let row = dataArray[safe: indexPath.row] else { return .init() }
        switch row {
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
                           blockedPhoneNumber: self.blockedPhoneNumberSet,
                           overrideSnippet: overrideSnippet,
                           overrideDate: date)
            cell.resetUI(forSearch: searchWord, thread: thread.threadRecord, cellStyle: HomeViewCellStyleTypeSearchNormal)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let row = dataArray[safe: indexPath.row] else { return UITableView.automaticDimension }
        return row.height
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let row = dataArray[safe: indexPath.row] else { return UITableView.automaticDimension }
        switch row {
        case .message:
            return 60.0
        default:
            return CGFloat.leastNonzeroMagnitude
        }
    }
}

extension DTSearchResultListController {
    enum ResultStyle {
        case contacts(results: [ContactSearchResult])
        case conversations(results: [GroupSearchResult])
        case messages(results: [MessageSearchResult], map: [String : [MessageSearchResult]])
        
        var isEmpty: Bool {
            switch self {
            case .contacts(let results):
                return results.isEmpty
            case .conversations(let results):
                return results.isEmpty
            case .messages(let results, _):
                return results.isEmpty
            }
        }
        
        var title: String {
            switch self {
            case .contacts:
                return Localized(
                    "SEARCH_RESULT_LIST_TITLE_CONTACTS",
                    comment: "section header for search results that match existing conversations (either group or contact conversations)"
                )
            case .conversations:
                return Localized(
                    "SEARCH_RESULT_LIST_TITLE_GROUP",
                    comment: "section header for search results that match existing conversations (either group or contact conversations)"
                )
            case .messages:
                return Localized(
                    "SEARCH_RESULT_LIST_TITLE_MESSAGES",
                    comment: "section header for search results that match existing conversations (either group or contact conversations)"
                )
            }
        }
    }
}

extension DTSearchResultListController {
    typealias RenderText = ConversationSearchTableViewCell.RenderText
    typealias IconRender = ConversationSearchTableViewCell.IconRender
        
    private enum RenderRow {
        case contact(icon: IconRender, name: RenderText, sign: RenderText, email: RenderText, date: String)
        case group(icon: IconRender, name: RenderText, include: RenderText)
        case message(thread: ThreadViewModel, overrideSnippet: NSAttributedString, date: Date)
        
        var subheadlineSize: CGFloat {
            return UIFont.preferredFont(forTextStyle: .subheadline).pointSize
        }
        
        var height: CGFloat {
            switch self {
            case .message:
                return subheadlineSize < 17 ? 60 : 70
            default:
                return ConversationSearchTableViewCell.cellHeight
            }
        }
    }
}



