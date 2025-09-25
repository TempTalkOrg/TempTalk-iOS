//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit

@objc
class DTLanguageSettingTableViewController : SettingBaseViewController {
    let reuse_identifier_style_blank = "DTDefaultStyleCell_LanguageSetting_style_blank"
    let reuse_identifier_style_check_box = "DTDefaultStyleCell_LanguageSetting_style_checkBox"
    
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
    
    public lazy var dataSource: [[DTLanguageSettingItem]] = {
        return getDataSource()
    }()
     
    override func loadView() {
        super.loadView()
        prepareUIData()
        prepareView()
        prepareLayout()
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = Localized("APPEARANCE_SETTINGS_LANGUAGE")
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
    
    func changeLanguage(_ language: LanguageType) {
        Localize.setCurrentLanguage(language.rawValue)
        self.title = Localized("APPEARANCE_SETTINGS_LANGUAGE")
        self.mainTableView.reloadData()
    }
    
}

extension DTLanguageSettingTableViewController : UITableViewDelegate,UITableViewDataSource {
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
        let settingMeItem : DTLanguageSettingItem? = self.dataSource[indexPath.section][indexPath.row]
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
        case .some(.english):
            changeLanguage(.english)
        case .some(.chinese):
            changeLanguage(.chinese)
        case .none:
            return
        }
    }
}

