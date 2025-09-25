//
//  DTBotsViewController.swift
//  Signal
//
//  Created by Ethan on 2022/10/19.
//  Copyright © 2022 Difft. All rights reserved.
//

import UIKit
import TTMessaging
import JXPagingView

@objcMembers
class DTBotsViewController: OWSViewController {
    
    var contactsManager = Environment.shared.contactsManager!
    
    var sortedBots = [SignalAccount]()
    
    var scrollCallback: ((UIScrollView?) -> Void)!
    
    lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = Theme.backgroundColor
        tableView.delegate = self
        tableView.dataSource = self
        tableView.estimatedRowHeight = 0
        tableView.rowHeight = 70
        tableView.separatorStyle = .none
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.register(ContactTableViewCell.self, forCellReuseIdentifier: ContactTableViewCell.reuseIdentifier())
        
        return tableView
    }()
    
    override func loadView() {
        super.loadView()
        
        view.addSubview(tableView)
        tableView.autoPinEdgesToSuperviewSafeArea()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        sortedBots = contactsManager.bots
        tableView.reloadData()
    }
    
    override func applyTheme() {
        super.applyTheme()
        tableView.backgroundColor = Theme.backgroundColor
        tableView.reloadData()
    }
    
    public func loadDataIfNecessary() {
//        if self.isViewLoaded {
//            return
//        }
//        self.loadViewIfNeeded()
        sortedBots = contactsManager.bots
        tableView.reloadData()
    }
}

extension DTBotsViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sortedBots.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ContactTableViewCell.reuseIdentifier(), for: indexPath) as! ContactTableViewCell
        guard indexPath.row < sortedBots.count else {
            return cell
        }
        cell.cellView.isBotsUseSignature = true
        cell.configure(with: sortedBots[indexPath.row], contactsManager: contactsManager)
        
        return cell
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < sortedBots.count else {
            return
        }
        
       
        let bot = sortedBots[indexPath.row]
        let profileVC = DTPersonalCardController(type: .other, recipientId: bot.recipientId, account: bot)
        
        navigationController?.pushViewController(profileVC, animated: true)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        scrollView.bounces = true
        scrollView.showsVerticalScrollIndicator = false
        guard let scrollCallback = scrollCallback else {
            return
        }
        scrollCallback(scrollView)
    }
    
    override func userTakeScreenshotEvent(_ notify: Notification) {
        
    }
}

extension DTBotsViewController: JXPagerViewListViewDelegate {
    
    func listView() -> UIView! { view }
    
    func listScrollView() -> UIScrollView! {
        tableView
    }
    
    func listViewDidScrollCallback(_ callback: ((UIScrollView?) -> Void)!) {
        scrollCallback = callback
    }
}
