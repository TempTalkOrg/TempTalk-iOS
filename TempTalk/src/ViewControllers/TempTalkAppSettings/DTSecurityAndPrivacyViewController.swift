//
//  DTSecurityAndPrivacyViewController.swift
//  Signal
//
//  Created by Kris.s on 2024/11/1.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

class DTSecurityAndPrivacyViewController : SettingBaseViewController {
    fileprivate let reuse_identifier_style_blank = "DTDefaultStyleCell_SecurityAndPrivacy_style_blank"
    fileprivate let reuse_identifier_style_description = "DTDefaultStyleCell_SecurityAndPrivacy_style_description"
    fileprivate let reuse_identifier_style_switch = "DTDefaultStyleCell_SecurityAndPrivacy_style_switch"
    fileprivate let reuse_identifier_style_plaintext = "DTDefaultStyleCell_SecurityAndPrivacy_style_plaintext"
    
    let profileInfoApi = DTProfileInfoApi()
    
    fileprivate lazy var mainTableView: UITableView = {
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
        mainTableView.register(DTSettingPlanTextCell.self, forCellReuseIdentifier: reuse_identifier_style_plaintext)
        return mainTableView
    }()
    
    fileprivate lazy var dataSource: [[DTSettingItem]] = {
        return getDataSource()
    }()
    
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func loadView() {
        super.loadView()
        prepareView()
        prepareLayout()
        dataSource = getDataSource()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = Localized("SETTINGS_PRIVACY_TITLE", comment: "")
        prepareTheme()
        
        NotificationCenter.default.addObserver(self, selector: #selector(screenLockDidChange(_:)), name: ScreenLock.ScreenLockDidChange, object: nil)
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        getProfileInfo()
        self.navigationController?.setNavigationBarHidden(false, animated: true)
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
    
    func prepareView() {
        view.addSubview(mainTableView)
    }
    
    func prepareLayout() {
        mainTableView.autoPinEdgesToSuperviewEdges()
    }
    
    @objc func screenLockDidChange(_ notification: NSNotification) {
        self.reloadPage()
    }
    
    func getProfileInfo() {
        self.profileInfoApi.profileInfo(sucess: { _ in
            self.reloadPage()
        }) { _ in
//            self.mainTableView.reloadData()
        }
    }
    
}

//MARK: tableView delegate
extension DTSecurityAndPrivacyViewController : UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource[section].count
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.dataSource.count
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let settingItem = self.dataSource[indexPath.section][indexPath.row]
        if settingItem.cellStyle == .blank{
            return 26
        } else if settingItem.cellStyle == .plainTextType {
            return UITableView.automaticDimension
        } else {
            return 52
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let settingItem : DTSettingItem? = self.dataSource[indexPath.section][indexPath.row]
        guard let settingItem = settingItem else {  return UITableViewCell.init() }
        if(settingItem.cellStyle == .blank){
            let cell = tableView.dequeueReusableCell(withIdentifier: reuse_identifier_style_blank, for: indexPath) as? DTBlankCell
            guard let defaultStyleCell = cell else { return UITableViewCell.init()}
            defaultStyleCell.applyTheme()
            return defaultStyleCell
            
        } else if(settingItem.cellStyle == .onlyAccessory ||
                  settingItem.cellStyle == .noAccessoryAndNoDescription ||
                  settingItem.cellStyle == .onlyDescription ||
                  settingItem.cellStyle == .accessoryAndDescription){
            
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
            defaultStyleCell.reloadCell(model: settingItem)
            if(settingItem.tag == SecurityAndPrivacyItemType.deleteAccount.rawValue){
                defaultStyleCell.titleTextColor = UIColor.color(rgbHex: 0xF84135)
            } else {
                defaultStyleCell.titleTextColor = Theme.primaryTextColor
            }
            return defaultStyleCell
            
        } else if(settingItem.cellStyle == .onlySwitch){
            
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
            defaultStyleCell.reloadCell(model: settingItem)
            return defaultStyleCell
            
        } else if(settingItem.cellStyle == .plainTextType){
            
            let cell = tableView.dequeueReusableCell(withIdentifier: reuse_identifier_style_plaintext, for: indexPath) as? DTSettingPlanTextCell
            guard let defaultStyleCell = cell else { return UITableViewCell.init()}
            defaultStyleCell.selectionStyle = .none
            defaultStyleCell.reloadCell(model: settingItem)
            return defaultStyleCell
            
        } else {
            
            return UITableViewCell.init()
            
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let settingItem = dataSource[indexPath.section][indexPath.row]
        if settingItem.tag == SecurityAndPrivacyItemType.timeout.rawValue {
            showScreenLockTimeoutUI()
        } else if settingItem.tag == SecurityAndPrivacyItemType.renewKey.rawValue {
            showRenewKeyAlert()
        } else if settingItem.tag == SecurityAndPrivacyItemType.deleteAccount.rawValue {
            let deleteAccountVC =  DTDeleteAccountController()
            self.navigationController?.pushViewController(deleteAccountVC, animated: true)
        }
    }
    
    func showScreenLockTimeoutUI() {
        let actionSheetController = UIAlertController(title: Localized("SETTINGS_SCREEN_LOCK_ACTIVITY_TIMEOUT", "Label for the 'screen lock activity timeout' setting of the privacy settings."),
                                                message: "",
                                                preferredStyle: .actionSheet)
        ScreenLock.shared.screenLockTimeouts.forEach { timeoutValue in
            let screenLockTimeout = round(timeoutValue)
            let screenLockTimeoutString = formatScreenLock(timeout: Int(screenLockTimeout), useShortFormat: false)
            actionSheetController.addAction(UIAlertAction(title: screenLockTimeoutString, style: .default, handler: { _ in
                ScreenLock.shared.setScreenLockTimeout(screenLockTimeout)
            }))
        }
        actionSheetController.addAction(OWSAlerts.cancelAction)
        self.present(actionSheetController, animated: true, completion: nil)
    }
    
    func showRenewKeyAlert() {
        let alertVC = UIAlertController(title: Localized("ALERT_RENEW_KEY_TITLE"), message: Localized("ALERT_RENEW_KEY_TIPS"), preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: CommonStrings.cancelButton(), style: .default)
        let alerAction = UIAlertAction(title: Localized("ALERT_RENEW_KEY_GENERATE"), style: .destructive, handler: { _ in
            DTToastHelper.show()
            IdentityKeyHandler.resetIDKey {
                DTToastHelper.hide()
                self.reloadPage()
            } failure: { error in
                DTToastHelper.hide()
                DTToastHelper.toast(withText: error.localizedDescription, in: self.view, durationTime: 3.0, afterDelay: 0.2)
            }
        })
        alertVC.addAction(cancelAction)
        alertVC.addAction(alerAction)
        self.present(alertVC, animated: true, completion: nil)
    }
    
    func reloadPage() {
        self.dataSource = self.getDataSource()
        self.mainTableView.reloadData()
    }
}

//MARK:  DataSource
extension DTSecurityAndPrivacyViewController {
    
    enum SecurityAndPrivacyItemType: Int {
        case passkeys = 0
        case screenLockEnable = 1
        case timeout = 2
        case renewKey = 3
        case deleteAccount = 4
    }
 
    func getDataSource() -> [[DTSettingItem]] {
        
        let passkeyAuthSwitch = DTTokenKeychainStore.loadPassword(withAccountKey: ProfileInfoConstants.passkeysSwitchKey)
        let isOpenPasskeyAuthSwith = passkeyAuthSwitch == "1" ? true : false
        let passkeyItem = DTSettingItem(icon: "", title: Localized("PASSKEYS_ENABLE"), description: "", cellStyle: SettingCellStyle.onlySwitch.rawValue, openSwitch: isOpenPasskeyAuthSwith)
        passkeyItem.tag = SecurityAndPrivacyItemType.passkeys.rawValue
        let passkeyTipsItem = DTSettingItem(icon: "", title: "", description: "", cellStyle: SettingCellStyle.plainTextType.rawValue, plainText:  Localized("PASSKEYS_ENABLE_TIP"))
        
        
        let screenlockEnable = ScreenLock.shared.isScreenLockEnabled()
        
        let screenLockEnableItem = DTSettingItem(icon: "", title: Localized("SETTINGS_SCREEN_LOCK_SWITCH_LABEL"), description: "", cellStyle: SettingCellStyle.onlySwitch.rawValue, openSwitch: screenlockEnable)
        screenLockEnableItem.tag = SecurityAndPrivacyItemType.screenLockEnable.rawValue
        let screenLockTipsItem = DTSettingItem(icon: "", title: "", description: "", cellStyle: SettingCellStyle.plainTextType.rawValue, plainText: Localized("SETTINGS_SCREEN_LOCK_SECTION_FOOTER"))
        
        let screenLockTimeout = round(ScreenLock.shared.screenLockTimeout())
        let screenLockTimeoutString = self.formatScreenLock(timeout: Int(screenLockTimeout), useShortFormat: true)
        let timeoutItem = DTSettingItem(icon: "", title: Localized("SETTINGS_SCREEN_LOCK_ACTIVITY_TIMEOUT"), description:screenLockTimeoutString , cellStyle: SettingCellStyle.accessoryAndDescription.rawValue)
        timeoutItem.tag = SecurityAndPrivacyItemType.timeout.rawValue
        
        let renewKeyItem = DTSettingItem(icon: "", title: Localized("SETTINGS_RENEW_KEY_LABEL"), description:"" , cellStyle: SettingCellStyle.accessoryAndDescription.rawValue)
        renewKeyItem.tag = SecurityAndPrivacyItemType.renewKey.rawValue
        
        var idKeyTime: NSNumber?
        self.databaseStorage.read { transaction in
            idKeyTime = OWSIdentityManager.shared().identityKeyTime(with: transaction)
        }
        var idkeyTimeString = ""
        var renewKeyTips = Localized("SETTINGS_RENEW_KEY_DES")
        if let idKeyTime = idKeyTime {
            idkeyTimeString = DateUtil.normalLongFormatter().string(from: NSDate.ows_date(withMillisecondsSince1970: UInt64(truncating: idKeyTime)))
            renewKeyTips = "🔐 " + idkeyTimeString + "\n" + renewKeyTips
        }
        let renewKeyTipsItem = DTSettingItem(icon: "", title: "", description: "", cellStyle: SettingCellStyle.plainTextType.rawValue, plainText:  renewKeyTips)
        
        let blanckItem = DTSettingItem(icon: "", title: "", description: "", cellStyle: SettingCellStyle.blank.rawValue)
        
        let deleteAccountItem = DTSettingItem(icon: "", title: Localized("SETTINGS_ITEM_DELETE"), description:"" , cellStyle: SettingCellStyle.accessoryAndDescription.rawValue)
        deleteAccountItem.tag = SecurityAndPrivacyItemType.deleteAccount.rawValue
        
        if screenlockEnable {
            
            if TSAccountManager.sharedInstance().passKeyManager.isPasskeySupported() {
                return [[blanckItem],
                        [passkeyItem, passkeyTipsItem],
                        [blanckItem],
                        [screenLockEnableItem, timeoutItem],
                        [screenLockTipsItem],
                        [blanckItem],
                        [renewKeyItem],
                        [renewKeyTipsItem],
                        [blanckItem],
                        [deleteAccountItem]]
            } else {
                return [[blanckItem],
                        [screenLockEnableItem, timeoutItem],
                        [screenLockTipsItem],
                        [blanckItem],
                        [renewKeyItem],
                        [renewKeyTipsItem],
                        [blanckItem],
                        [deleteAccountItem]]
            }
            
            
        } else {
            
            if TSAccountManager.sharedInstance().passKeyManager.isPasskeySupported() {
                return [[blanckItem],
                        [passkeyItem, passkeyTipsItem],
                        [blanckItem],
                        [screenLockEnableItem],
                        [screenLockTipsItem],
                        [blanckItem],
                        [renewKeyItem],
                        [renewKeyTipsItem],
                        [blanckItem],
                        [deleteAccountItem]]
            } else {
                return [[blanckItem],
                        [screenLockEnableItem],
                        [screenLockTipsItem],
                        [blanckItem],
                        [renewKeyItem],
                        [renewKeyTipsItem],
                        [blanckItem],
                        [deleteAccountItem]]
            }
        }
    }
    
    func formatScreenLock(timeout: Int, useShortFormat: Bool) -> String {
        if timeout <= 1 {
            return Localized("SCREEN_LOCK_ACTIVITY_TIMEOUT_NONE", comment: "Indicates a delay of zero seconds, and that 'screen lock activity' will timeout immediately.")
        }
        
        return NSString.formatDurationSeconds(UInt32(timeout), useShortFormat: useShortFormat)
    }
    
}

//MARK:  switch action
extension DTSecurityAndPrivacyViewController : DTSettingSwitchCellDelegate  {
    
    func switchValueChanged(isOn: Bool, cell: DTDefaultBaseStyleCell) {
        
        if let settingItem = cell.model {
            if settingItem.tag == SecurityAndPrivacyItemType.screenLockEnable.rawValue {
                screenLockEnabledChangeAction(isOn: isOn, cell: cell)
            } else if settingItem.tag == SecurityAndPrivacyItemType.passkeys.rawValue {
                if(isOn){
                    let setUpPasskeysVC = DTSetUpPasskeysController()
                    setUpPasskeysVC.loginType = DTLoginModeTypeViaRegisterPasskeyAuthFromMe
                    self.navigationController?.pushViewController(setUpPasskeysVC, animated: true)
                } else {
                    self.setEnablePasskeysForProfileInfo(passkeysSwitch: 0)
                }
            }
        }
        
    }
    
    func screenLockEnabledChangeAction(isOn: Bool, cell: DTDefaultBaseStyleCell) {
        let shouldBeEnabled = isOn;
        if shouldBeEnabled == ScreenLock.shared.isScreenLockEnabled() {
            Logger.error("\(self.logTag) ignoring redundant screen lock.")
            return;
        }
        
        Logger.info("\(self.logTag) trying to set is screen lock enabled: \(shouldBeEnabled)")
        
        if shouldBeEnabled {
            let setPasscodeVc = DTScreenLockBaseViewController.buildScreenLockView(viewType: .setPasscode) { passcode in
                let confirmPasscodeVc = DTScreenLockBaseViewController.buildScreenLockView(viewType: .confirmPasscode) { verifiedPasscode in
                    //上报passcode
                    let screenLockTimeout = round(ScreenLock.shared.screenLockTimeout())
                    let screenlockCrypto = DTScreenLockCrypto()
                    
                    guard let verifiedPasscode = verifiedPasscode else{
                        Logger.error("verifiedPasscode is empty!")
                        return
                    }
                    
                    guard let passcodeHash = screenlockCrypto.hashPasscode(passcode: verifiedPasscode) else{
                        DTToastHelper.toast(withText: "Sorry,encountered some problems!", in: self.view, durationTime: 3.0, afterDelay: 0.2)
                        Logger.error("passcodeHash is empty!")
                        return
                    }
                    
                    ScreenLock.shared.setPasscode(passcodeHash)
                    self.navigationController?.popToViewController(self, animated: false)
                    let passcodeSuccessVc = DTScreenLockBaseViewController.buildScreenLockView(viewType: .passcodeSuccess) { _ in
                        self.navigationController?.popToViewController(self, animated: false)
                    }
                    self.navigationController?.pushViewController(passcodeSuccessVc, animated: true)
                    
                }
                let confirmPasscode = confirmPasscodeVc as! DTConfirmPasscodeViewController
                confirmPasscode.verifiedPasscode = passcode ?? ""
                self.navigationController?.pushViewController(confirmPasscodeVc, animated: false)
            }
            
            self.navigationController?.pushViewController(setPasscodeVc, animated: false)
            
        } else {
            ScreenLock.shared.removePasscode()
        }
    }
    
    func setEnablePasskeysForProfileInfo(passkeysSwitch: UInt) {
        DTToastHelper.showHud(in: self.view)
        self.profileInfoApi.setProfileInfo(["passkeysSwitch":passkeysSwitch]) { entity in
            DTToastHelper.hide()
            self.cachePrivateSettingInKeyChain(passkeysSwitch: passkeysSwitch, key: ProfileInfoConstants.passkeysSwitchKey)
            self.reloadPage()
        } failure: { error in
            DTToastHelper.hide()
            Logger.info("setEnablePasskeysForProfileInfo")
            self.reloadPage()
        }
    }
    
    func cachePrivateSettingInKeyChain(passkeysSwitch: UInt, key: String) {
        DTTokenKeychainStore.setPassword("\(passkeysSwitch)", forAccount: key)
    }
    
}
