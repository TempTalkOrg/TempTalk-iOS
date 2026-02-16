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
import UserNotifications

@objc
class DTNotificationSettingsController : SettingBaseViewController {
    let reuse_identifier_style_blank = "DTDefaultStyleCell_NotificationSettings_style_blank"
    let reuse_identifier_style_description = "DTDefaultStyleCell_NotificationSettings_style_description"
    let reuse_identifier_style_switch = "DTDefaultStyleCell_NotificationSettings_style_switch"
    let reuse_identifier_style_plainText = "DTDefaultStyleCell_NotificationSettings_style_plainText"
    
    var notificationTypeValue : NSNumber = NSNumber(value: -1000)
    var contact : Contact?
    var criticalEnabed: Bool = false
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
        mainTableView.register(DTSettingPlanTextCell.self, forCellReuseIdentifier: reuse_identifier_style_plainText)
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
        
        // 默认critical alert描述，会在异步更新后刷新
        let criticalAlertDescription = Localized("NOTIFICATIONS_CRITICAL_SWITCH_OFF")
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
            [
                ["icon":"",
                 "title":"",
                 "description":"",
                 "cellStyle": 0
                ],
            ],
            [
                ["icon":"",
                 "title": Localized("NOTIFICATIONS_CRITICAL_ALERT",comment: "Critical Alert"),
                 "description":criticalAlertDescription,
                 "type":5,
                 "cellStyle": 4,
                ],
                ["icon":"",
                 "title":"",
                 "description":"",
                 "cellStyle": SettingCellStyle.plainTextType.rawValue,
                 "plainText": Localized("NOTIFICATIONS_CRITICAL_DESCRIPTION", comment: "Critical Alert Tips")
                ],
            ],
        ]
        let dataSourceArr = DTJsonParsesUtil.convert(dataSource, to: DTNotificationItem.self)
        return dataSourceArr
    }
    
    func checkCriticalAlertPermission(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.criticalAlertSetting {
            case .enabled:
                completion(true)
            case .disabled:
                completion(false)
            case .notSupported:
                completion(false)
            @unknown default:
                completion(false)
            }
        }
    }
    
    
    func checkCriticalAlertNotSupportedPermission(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.criticalAlertSetting {
            case .enabled:
                completion(false)
            case .disabled:
                completion(false)
            case .notSupported:
                completion(true)
            @unknown default:
                completion(false)
            }
        }
    }
    
    func updateCriticalAlertStatus() {
        checkCriticalAlertPermission { [weak self] isEnabled in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.criticalEnabed = isEnabled
                
                for sectionIndex in 0..<self.dataSource.count {
                    for rowIndex in 0..<self.dataSource[sectionIndex].count {
                        let item = self.dataSource[sectionIndex][rowIndex]
                        if item.type == .criticalAlert {
                            let description = isEnabled ? Localized("NOTIFICATIONS_CRITICAL_SWITCH_ON") : Localized("NOTIFICATIONS_CRITICAL_SWITCH_OFF")
                            self.dataSource[sectionIndex][rowIndex].description = description
                            let indexPath = IndexPath(row: rowIndex, section: sectionIndex)
                            if let cell = self.mainTableView.cellForRow(at: indexPath) as? DTSettingDescriptionCell {
                                cell.reloadCell(model: self.dataSource[sectionIndex][rowIndex])
                            }
                            break
                        }
                    }
                }
            }
        }
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
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        prepareUIData()
        updateCriticalAlertStatus()
        self.mainTableView.reloadData()
    }
    
    override func applyTheme() {
        super.applyTheme()
        view.backgroundColor = Theme.bgpageSecondaryColor
        mainTableView.backgroundColor = Theme.bgpageSecondaryColor
        self.mainTableView.tableHeaderView?.backgroundColor = Theme.defaultColor
        self.mainTableView.reloadData()
    }
    
    
    @objc class func inModalNavigationController() -> OWSNavigationController {
        let viewController = AppSettingsViewController()
        let navController = OWSNavigationController.init(rootViewController: viewController)
        return navController
    }
    
    func prepareTheme() {
        view.backgroundColor = Theme.bgpageSecondaryColor
        mainTableView.backgroundColor = Theme.bgpageSecondaryColor
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
    
    @objc func appDidBecomeActive() {
        updateCriticalAlertStatus()
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
        } else if settingMeItem.cellStyle == .plainTextType {
            return UITableView.automaticDimension
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
        } else if(settingMeItem.cellStyle == .plainTextType){
            
            let cell = tableView.dequeueReusableCell(withIdentifier: reuse_identifier_style_plainText, for: indexPath) as? DTSettingPlanTextCell
            guard let defaultStyleCell = cell else { return UITableViewCell.init()}
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
        case .some(.criticalAlert):
            handleCriticalAlertTap()
            return
        case .none:
            return
        }
    }
    
    private func handleCriticalAlertTap() {
        // 先检查系统设置中 Critical Alert 的状态
        checkCriticalAlertNotSupportedPermission { [weak self] notSupported in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // 如果系统设置中已经有 Critical Alert 开关（无论开启或关闭），说明用户已经授权过
                if !notSupported {
                    self.showCriticalAlertSettingsRedirect()
                } else {
                    // 如果系统设置中没有 Critical Alert 开关，说明从未授权过
                    self.requestCriticalAlertPermission()
                }
            }
        }
    }
}

extension DTNotificationSettingsController : DTSettingSwitchCellDelegate  {
    
    func switchValueChanged(isOn: Bool, cell: DTDefaultBaseStyleCell) {
        if let indexPath = mainTableView.indexPath(for: cell) {
            let settingItem = dataSource[indexPath.section][indexPath.row]
            if settingItem.type == .playWhileAppOpen {
                Environment.preferences().setSoundInForeground(isOn)
            }
        }
    }
    
    private func requestCriticalAlertPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.criticalAlert]) { granted, error in
            DispatchQueue.main.async {
                self.updateCriticalAlertStatus()
            }
        }
    }
    
    private func showCriticalAlertSettingsRedirect() {
        let title = self.criticalEnabed ? Localized("NOTIFICATIONS_CRITICAL_ALERT_TITLE_OFF") : Localized("NOTIFICATIONS_CRITICAL_ALERT_TITLE_ON")
        let description = self.criticalEnabed ? Localized("NOTIFICATIONS_CRITICAL_ALERT_DESCRIPTION_OFF") : Localized("NOTIFICATIONS_CRITICAL_ALERT_DESCRIPTION_ON")
        let alertController = UIAlertController(
            title: title,
            message: description,
            preferredStyle: .alert
        )
        
        let settingsAction = UIAlertAction(title: Localized("NOTIFICATIONS_CRITICAL_ALERT_SETTING", comment: "Open Settings"), style: .default) { _ in
            UIApplication.shared.openSystemSettings()
        }
        
        let cancelAction = UIAlertAction(title: Localized("NOTIFICATIONS_CRITICAL_ALERT_CANCEL", comment: "Cancel"), style: .cancel)
        
        alertController.addAction(settingsAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
    }
}
