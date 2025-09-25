//
//  DTNotificationSettingsController.swift
//  Signal
//
//  Created by hornet on 2023/5/25.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
import TTServiceKit
import TTMessaging

@objc
class DTNotificationSettingsController : SettingBaseViewController {
    let reuse_identifier_style_blank = "DTDefaultStyleCell_NotificationSettings_style_blank"
    let reuse_identifier_style_description = "DTDefaultStyleCell_NotificationSettings_style_description"
    let reuse_identifier_style_switch = "DTDefaultStyleCell_NotificationSettings_style_switch"
    
    var notificationTypeValue : NSNumber = NSNumber(value: -1000)
    var contact : Contact?
    public lazy var mainTableView: UITableView = {
        let mainTableView = UITableView(frame: CGRect.zero, style: .plain)
        if #available(iOS 15.0, *) {
            mainTableView.sectionHeaderTopPadding = 0;
        }
        mainTableView.delegate = self
        mainTableView.dataSource = self
        mainTableView.separatorStyle = .none
        mainTableView.estimatedRowHeight = 52
        mainTableView.rowHeight = UITableView.automaticDimension
        mainTableView.register(DTBlankCell.self, forCellReuseIdentifier: reuse_identifier_style_blank)
        mainTableView.register(DTSettingDescriptionCell.self, forCellReuseIdentifier: reuse_identifier_style_description)
        mainTableView.register(DTSettingSwitchCell.self, forCellReuseIdentifier: reuse_identifier_style_switch)
        return mainTableView
    }()
    var signalAccount: SignalAccount?
    
    public lazy var dataSource: [[DTNotificationItem]] = {
        return getDataSource()
    }()
    
    
    func getDataSource() -> [[DTNotificationItem]] {
        let notificationTypeString = notificationTypeString()
        let soundsDisplay = OWSSounds.displayName(for: OWSSounds.globalNotificationSound())
        let prefs = Environment.preferences()
        var nameDisplay = ""
        if let notificationPreviewTypeValue = prefs?.notificationPreviewType() {
            nameDisplay = Environment.preferences().name(forNotificationPreviewType:notificationPreviewTypeValue)
        }
        var openSwitch = false
        if let openSwitchValue = prefs?.soundInForeground() {
            openSwitch = openSwitchValue
        }
        /// cellStyle 不同的值对应不同的cell类型
        ///blank = 0
        ///onlyAccessory = 1
        ///noAccessoryAndNoDescription = 2
        ///onlyDescription = 3
        ///accessoryAndDescription = 4
        ///onlySwitch = 5
        let dataSource : [[[String: Any]]] = [
            [
                ["icon":"",
                 "title":"",
                 "description":"",
                 "cellStyle": 0],
            ],
            [
                ["icon":"",
                 "title": Localized("SETTINGS_ITEM_NOTIFICATION_APNS",comment: "Action title Notification"),
                 "description":notificationTypeString,
                 "type":1,
                 "cellStyle": 1],
            ],
            [
                ["icon":"",
                 "title":"",
                 "description":"",
                 "cellStyle": 0],
            ],
            [
                ["icon":"",
                 "title": Localized("SETTINGS_ITEM_NOTIFICATION_SOUND",comment: "Action title Notification"),
                 "description":soundsDisplay,
                 "type":2,
                 "cellStyle": 1
                ],
                ["icon":"",
                 "title": Localized("NOTIFICATIONS_SECTION_INAPP",comment: "Action title Notification"),
                 "description":"",
                 "type":3,
                 "cellStyle": 5,
                 "openSwitch": openSwitch,
                ] ,
            ],
            [
                ["icon":"",
                 "title":"",
                 "description":"",
                 "cellStyle": 0
                ],
            ],
            [
                ["icon":"",
                 "title": Localized("NOTIFICATIONS_SHOW",comment: "Action title Notification"),
                 "description":nameDisplay,
                 "type":4,
                 "cellStyle": 4
                ],
            ],
        ]
        let dataSourceArr = DTJsonParsesUtil.convert(dataSource, to: DTNotificationItem.self)
        return dataSourceArr
    }
    
    func notificationTypeString() -> String {
        var notificationTypeString = ""
        if(notificationTypeValue.intValue == 0){
            notificationTypeString = Localized("SETTINGS_ITEM_NOTIFICATION_APNS_ALL_MESSAGE",comment: "APNS ALL MESSAGE")
        } else if(notificationTypeValue.intValue == 1){
            notificationTypeString = Localized("SETTINGS_ITEM_NOTIFICATION_APNS_AT",comment: "APNS ALL MESSAGE")
        } else if(notificationTypeValue.intValue == 2){
            notificationTypeString = Localized("SETTINGS_ITEM_NOTIFICATION_APNS_OFF",comment: "APNS ALL MESSAGE")
        }
        return notificationTypeString
    }
    
    override func loadView() {
        super.loadView()
        prepareUIData()
        prepareView()
        prepareLayout()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = Localized("SETTINGS_NOTIFICATIONS", comment: "")
        prepareTheme()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        prepareUIData()
        self.mainTableView.reloadData()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func applyTheme() {
        super.applyTheme()
        view.backgroundColor = Theme.defaultBackgroundColor
        mainTableView.backgroundColor = Theme.defaultBackgroundColor
        self.mainTableView.tableHeaderView?.backgroundColor = Theme.defaultBackgroundColor
        self.mainTableView.reloadData()
    }
    
    
    @objc class func inModalNavigationController() -> OWSNavigationController {
        let viewController = AppSettingsViewController()
        let navController = OWSNavigationController.init(rootViewController: viewController)
        return navController
    }
    
    func prepareTheme() {
        view.backgroundColor = Theme.defaultBackgroundColor
        mainTableView.backgroundColor = Theme.defaultBackgroundColor
    }
    
    func prepareUIData() {
        let contactsManager = Environment.shared.contactsManager;
        guard let localNum = TSAccountManager.localNumber() else { return }
        guard let account = contactsManager?.signalAccount(forRecipientId: localNum) else { return }
        self.signalAccount = account
        guard let contact_t = account.contact else {
            return
        }
        contact = contact_t
        //TODO:temptalk need handle
        if let privateConfig = contact_t.privateConfigs ,let value = privateConfig.globalNotification{
            notificationTypeValue = value
        }
        dataSource = getDataSource()
        
    }
    
    func prepareView() {
        view.addSubview(mainTableView)
    }
    
    func prepareLayout() {
        mainTableView.autoPinEdgesToSuperviewEdges()
    }
}

extension DTNotificationSettingsController : UITableViewDelegate,UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.dataSource[section].count
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataSource.count
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let settingMeItem = self.dataSource[indexPath.section][indexPath.row]
        if settingMeItem.cellStyle == .blank{
            return 26
        } else {
            return 52
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let settingMeItem : DTNotificationItem? = self.dataSource[indexPath.section][indexPath.row]
        guard let settingMeItem = settingMeItem else {  return UITableViewCell.init() }
        if(settingMeItem.cellStyle == .blank){
            let cell = tableView.dequeueReusableCell(withIdentifier: reuse_identifier_style_blank, for: indexPath) as? DTBlankCell
            guard let defaultStyleCell = cell else { return UITableViewCell.init()}
            defaultStyleCell.applyTheme()
            return defaultStyleCell
            
        } else if(settingMeItem.cellStyle == .onlyAccessory ||
                  settingMeItem.cellStyle == .noAccessoryAndNoDescription ||
                  settingMeItem.cellStyle == .onlyDescription ||
                  settingMeItem.cellStyle == .accessoryAndDescription){
            
            let cell = tableView.dequeueReusableCell(withIdentifier: reuse_identifier_style_description, for: indexPath) as? DTSettingDescriptionCell
            guard let defaultStyleCell = cell else { return UITableViewCell.init()}
            if (indexPath.row == 0){
                defaultStyleCell.borderType = self.dataSource[indexPath.section].count > 1 ?  .top : .all
            } else if(indexPath.row == (self.dataSource[indexPath.section].count - 1)){
                defaultStyleCell.borderType = .bottom
            } else {
                defaultStyleCell.borderType = .none
            }
            defaultStyleCell.selectionStyle = .none
            defaultStyleCell.reloadCell(model: settingMeItem)
            return defaultStyleCell
            
        } else if(settingMeItem.cellStyle == .onlySwitch){
            let cell = tableView.dequeueReusableCell(withIdentifier: reuse_identifier_style_switch, for: indexPath) as? DTSettingSwitchCell
            guard let defaultStyleCell = cell else { return UITableViewCell.init()}
            if (indexPath.row == 0){
                defaultStyleCell.borderType = self.dataSource[indexPath.section].count > 1 ?  .top : .all
            } else if(indexPath.row == (self.dataSource[indexPath.section].count - 1)){
                defaultStyleCell.borderType = .bottom
            } else {
                defaultStyleCell.borderType = .none
            }
            defaultStyleCell.delegate = self
            defaultStyleCell.selectionStyle = .none
            defaultStyleCell.reloadCell(model: settingMeItem)
            return defaultStyleCell
        }
        else {
            return UITableViewCell.init()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let settingMeItem = self.dataSource[indexPath.section][indexPath.row]
        switch settingMeItem.type {
        case .some(.blank):return
        case .some(.notification):
            let scopeOfNoticeController = DTScopeOfNoticeController()
            self.navigationController?.pushViewController(scopeOfNoticeController, animated: true)
        case .some(.messageSound):
            let vc = OWSSoundSettingsViewController.init()
            self.navigationController?.pushViewController(vc, animated: true)
        case .some(.playWhileAppOpen):
            let privacyVC = DTSecurityAndPrivacyViewController()
            self.navigationController?.pushViewController(privacyVC, animated: true)
        case .some(.displayContent):
            let notificationsVC = NotificationSettingsOptionsViewController()
            self.navigationController?.pushViewController(notificationsVC, animated: true)
            return
        case .none:
            return
        }
    }
}

//MARK:  用户自定义的按钮点击事件
extension DTNotificationSettingsController : DTSettingSwitchCellDelegate  {
    
    func switchValueChanged(isOn: Bool, cell: DTDefaultBaseStyleCell) {
        Environment.preferences().setSoundInForeground(isOn)
    }
    
}
