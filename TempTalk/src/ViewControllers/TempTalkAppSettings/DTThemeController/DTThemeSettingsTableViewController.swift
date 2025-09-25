//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import TTMessaging

@objc
class DTThemeSettingsTableViewController : SettingBaseViewController {
    let reuse_identifier_style_blank = "DTDefaultStyleCell_ThemeSettings_style_blank"
    let reuse_identifier_style_check_box = "DTDefaultStyleCell_ThemeSettings_style_checkBox"
    
    var notificationTypeValue : NSNumber = NSNumber(value: -1000)
    var contact : Contact?
    let logoutApi = DTLogoutApi()
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
        mainTableView.register(DTSettingCheckBoxCell.self, forCellReuseIdentifier: reuse_identifier_style_check_box)
        return mainTableView
    }()
    var signalAccount: SignalAccount?
    
    public lazy var dataSource: [[DTThemeSettingItem]] = {
        return getDataSource()
    }()
    
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
        self.title = Localized("SETTINGS_APPEARANCE_THEME_TITLE", comment: "")
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
    
    func changeTheme(_ mode: ThemeMode) {
        Theme.setCurrent(mode)
        self.mainTableView.reloadData()
    }
    
}

extension DTThemeSettingsTableViewController : UITableViewDelegate,UITableViewDataSource {
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
        let settingMeItem : DTThemeSettingItem? = self.dataSource[indexPath.section][indexPath.row]
        guard let settingMeItem = settingMeItem else {  return UITableViewCell.init() }
        if(settingMeItem.cellStyle == .blank){
            let cell = tableView.dequeueReusableCell(withIdentifier: reuse_identifier_style_blank, for: indexPath) as? DTBlankCell
            guard let defaultStyleCell = cell else { return UITableViewCell.init()}
            defaultStyleCell.applyTheme()
            return defaultStyleCell
            
        }else if(settingMeItem.cellStyle == .checkBox){
            let cell = tableView.dequeueReusableCell(withIdentifier: reuse_identifier_style_check_box, for: indexPath) as? DTSettingCheckBoxCell
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
            
        } else {
            return UITableViewCell.init()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let settingMeItem = self.dataSource[indexPath.section][indexPath.row]
        switch settingMeItem.type {
        case .some(.blank):return
        case .some(.system):
            changeTheme(.system)
        case .some(.light):
            changeTheme(.light)
        case .some(.dark):
            changeTheme(.dark)
        case .none:
            return
        }
    }
}

