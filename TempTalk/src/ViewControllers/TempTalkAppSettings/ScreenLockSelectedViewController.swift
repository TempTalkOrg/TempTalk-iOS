//
//  ScreenLockSelectedViewController.swift
//  Difft
//
//  Created by Henry on 2025/9/22.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

class ScreenLockSelectedViewController: SettingBaseViewController {
    enum ScreenLockItemType: Int {
        case pattern = 0
        case password = 1
        case timeout = 2
        case patternPath = 3
    }
    
    // Settings UI properties
    private let reuse_identifier_style_blank = "DTDefaultStyleCell_ScreenLock_style_blank"
    private let reuse_identifier_style_description = "DTDefaultStyleCell_ScreenLock_style_description"
    private let reuse_identifier_style_switch = "DTDefaultStyleCell_ScreenLock_style_switch"
    private let reuse_identifier_style_plaintext = "DTDefaultStyleCell_ScreenLock_style_plaintext"
    
    private lazy var mainTableView: UITableView = {
        let mainTableView = UITableView(frame: CGRect.zero, style: .plain)
        if #available(iOS 15.0, *) {
            mainTableView.sectionHeaderTopPadding = 0
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
    
    private lazy var dataSource: [[DTSettingItem]] = {
        return getDataSource()
    }()
    
    // 记录当前开启的数据类型
    var currentOpenItemType: ScreenLockItemType?
    
    // MARK: - Lifecycle
    
    override func loadView() {
        super.loadView()
        setupSettingsInterface()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if shouldShowSettingsInterface() {
            self.title = Localized("SETTINGS_SCREEN_LOCK_TITLE", comment: "Screen Lock")
            self.navigationController?.setNavigationBarHidden(false, animated: true)
            
            // 添加通知监听
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(screenLockDidChange(_:)),
                name: ScreenLock.ScreenLockDidChange,
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(screenLockPatternDidChange(_:)),
                name: ScreenLock.ScreenLockPatternDidChange,
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(screenLockBindEmail(_:)),
                name: ScreenLock.ScreenLockBindEmail,
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(screenLockBindPhone(_:)),
                name: ScreenLock.ScreenLockBindPhone,
                object: nil
            )
        }
        
        // 未绑定，且之前绑定过任意一种密码
        if shouldShowBindUI() && (isPatternUnlockEnabled() || isPasswordUnlockEnabled()) {
            showBindingTipsVC()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if shouldShowSettingsInterface() {
            self.navigationController?.setNavigationBarHidden(false, animated: true)
            reloadPage()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    deinit {
        currentOpenItemType = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Private Methods
    
    private func shouldShowSettingsInterface() -> Bool {
        // 这里可以根据需要决定是否显示设置界面
        // 例如：检查某个标志位或者根据当前状态
        return true // 暂时总是显示设置界面
    }
    
    private func setupSettingsInterface() {
        self.view.backgroundColor = Theme.bgpageSecondaryColor
        
        prepareView()
        prepareLayout()
        prepareTheme()
        
        self.dataSource = getDataSource()
    }
    
    // MARK: - Settings Interface Setup
    
    override func applyTheme() {
        super.applyTheme()
        view.backgroundColor = Theme.bgpageSecondaryColor
        mainTableView.backgroundColor = Theme.bgpageSecondaryColor
        self.mainTableView.tableHeaderView?.backgroundColor = Theme.bgpageSecondaryColor
        self.mainTableView.reloadData()
    }
    
    func prepareTheme() {
        view.backgroundColor = Theme.bgpageSecondaryColor
        mainTableView.backgroundColor = Theme.bgpageSecondaryColor
    }
    
    func prepareView() {
        view.addSubview(mainTableView)
    }
    
    func prepareLayout() {
        mainTableView.autoPinEdgesToSuperviewEdges()
    }
    
    // MARK: - Data Source
    private func getDataSource() -> [[DTSettingItem]] {
        let gestureUnlockItem = DTSettingItem(
            icon: "",
            title: Localized("SETTINGS_GESTURE_UNLOCK", comment: "Gesture Unlock"),
            description: "",
            cellStyle: SettingCellStyle.onlySwitch.rawValue,
            openSwitch: isPatternUnlockEnabled(),
            plainText: ""
        )
        gestureUnlockItem.tag = ScreenLockItemType.pattern.rawValue
        
        let passwordUnlockItem = DTSettingItem(
            icon: "",
            title: Localized("SETTINGS_PASSWORD_UNLOCK", comment: "Password Unlock"),
            description: "",
            cellStyle: SettingCellStyle.onlySwitch.rawValue,
            openSwitch: isPasswordUnlockEnabled(),
            plainText: ""
        )
        passwordUnlockItem.tag = ScreenLockItemType.password.rawValue // Password Unlock Switch
        
        let screenLockTimeout = round(ScreenLock.shared.screenLockTimeout())
        let screenLockTimeoutString = self.formatScreenLock(timeout: Int(screenLockTimeout), useShortFormat: true)
        let timeOutItem = DTSettingItem(
            icon: "",
            title: Localized("SETTINGS_TIMEOUT_UNLOCK", comment: "timeout"),
            description: screenLockTimeoutString,
            cellStyle: SettingCellStyle.accessoryAndDescription.rawValue,
            openSwitch: false,
            plainText: ""
        )
        timeOutItem.tag = ScreenLockItemType.timeout.rawValue // Password Unlock Switch
        
        let passwordPathUnlockItem = DTSettingItem(
            icon: "",
            title: Localized("SETTINGS_GESTURE_PATH_UNLOCK", comment: "Pattern path"),
            description: "",
            cellStyle: SettingCellStyle.onlySwitch.rawValue,
            openSwitch: isPatternPathUnlockEnabled(),
            plainText: ""
        )
        passwordPathUnlockItem.tag = ScreenLockItemType.patternPath.rawValue
        
        let blanckItem = DTSettingItem(icon: "", title: "", description: "", cellStyle: SettingCellStyle.blank.rawValue)
        
        if isPatternUnlockEnabled() {
            return [[blanckItem],
                    [gestureUnlockItem, passwordUnlockItem],
                    [blanckItem],
                    [timeOutItem],
                    [blanckItem],
                    [passwordPathUnlockItem]]
        } else if isPasswordUnlockEnabled() {
            return [[blanckItem],
                    [gestureUnlockItem, passwordUnlockItem],
                    [blanckItem],
                    [timeOutItem]]
        }
        
        return [[blanckItem],
                [gestureUnlockItem, passwordUnlockItem]]
        
    }
    
    private func isPatternUnlockEnabled() -> Bool {
        return ScreenLock.shared.isScreenLockPatternEnabled()
    }
    
    private func isPasswordUnlockEnabled() -> Bool {
        return ScreenLock.shared.isScreenLockPasscodeEnabled()
    }
    
    private func isPatternPathUnlockEnabled() -> Bool {
        return ScreenLock.shared.isScreenLockPatternPathEnabled()
    }
    
    private func setPatternPathUnlockEnabled(_ enabled: Bool) {
        ScreenLock.shared.screenLockPatternPathEnabled(enabled)
    }
    
    private func reloadPage() {
        self.dataSource = getDataSource()
        self.mainTableView.reloadData()
    }
    
    // MARK: - Notifications
    
    @objc private func screenLockDidChange(_ notification: NSNotification) {
        reloadPage()
    }
    
    @objc private func screenLockPatternDidChange(_ notification: NSNotification) {
        reloadPage()
    }
    
    @objc private func screenLockBindEmail(_ notification: NSNotification) {
        autoShowSettingVC()
    }
    
    @objc private func screenLockBindPhone(_ notification: NSNotification) {
        autoShowSettingVC()
    }
    
    func autoShowSettingVC() {
        if !shouldShowBindUI(), let itemType = currentOpenItemType {
            self.navigationController?.popViewController(animated: false) {
                if itemType == .pattern {
                    self.switchPatternOn(with: true)
                } else {
                    self.switchPasswordOn(with: true)
                }
            }
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    func formatScreenLock(timeout: Int, useShortFormat: Bool) -> String {
        if timeout <= 1 {
            return Localized("SCREEN_LOCK_ACTIVITY_TIMEOUT_NONE", comment: "Indicates a delay of zero seconds, and that 'screen lock activity' will timeout immediately.")
        }
        
        return NSString.formatDurationSeconds(UInt32(timeout), useShortFormat: useShortFormat)
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
    
    func showBindingTipsVC() {
        let alertVC = UIAlertController(
            title: Localized("SCREENLOCK_BINDING_ACCOUNT_TITLE"),
            message: Localized("SCREENLOCK_BINDING_ACCOUNT_TIPS"),
            preferredStyle: .alert
        )
        let cancelAction = UIAlertAction(title: Localized("SCREENLOCK_BINDING_CANCEL_ACTION"), style: .cancel)
        alertVC.addAction(cancelAction)
        let confirmAction = UIAlertAction(
                title: Localized("SCREENLOCK_BINDING_CONFIRM_ACTION"),
                style: .default
        ) { _ in
            if self.shouldShowVerifyVC() {
                let verifyVC = DTScreenLockBaseViewController.buildScreenLockView(viewType: .unlockScreen) { passcode in
                    self.navigationController?.popViewController(animated: false) {
                        self.showBindEmailPhoneAlert()
                    }
                }
                self.navigationController?.pushViewController(verifyVC, animated: false)
            } else {
                self.showBindEmailPhoneAlert()
            }
        }

        alertVC.addAction(confirmAction)
        present(alertVC, animated: true)
    }
    
}

// MARK: - UITableViewDataSource

extension ScreenLockSelectedViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return dataSource.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource[section].count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let settingItem = dataSource[indexPath.section][indexPath.row]
        if settingItem.cellStyle == .blank {
            return 26
        } else if settingItem.cellStyle == .plainTextType {
            return UITableView.automaticDimension
        } else {
            return 52
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let settingItem = dataSource[indexPath.section][indexPath.row]
        
        if settingItem.cellStyle == .blank {
            let cell = tableView.dequeueReusableCell(withIdentifier: reuse_identifier_style_blank, for: indexPath) as? DTBlankCell
            cell?.applyTheme()
            return cell ?? UITableViewCell()
        } else if settingItem.cellStyle == .onlySwitch {
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
        } else if settingItem.cellStyle == .accessoryAndDescription {
            let cell = tableView.dequeueReusableCell(withIdentifier: reuse_identifier_style_description, for: indexPath) as? DTSettingDescriptionCell
            guard let defaultStyleCell = cell else { return UITableViewCell.init()}
            defaultStyleCell.borderType = .all
            defaultStyleCell.selectionStyle = .none
            defaultStyleCell.reloadCell(model: settingItem)
            return defaultStyleCell
        }
        
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let settingItem = dataSource[indexPath.section][indexPath.row]
        if settingItem.tag == ScreenLockItemType.timeout.rawValue {
            showScreenLockTimeoutUI()
        }
    }
}

// MARK: - DTSettingSwitchCellDelegate
extension ScreenLockSelectedViewController: DTSettingSwitchCellDelegate {
    
    func switchValueChanged(isOn: Bool, cell: DTDefaultBaseStyleCell) {
        guard let indexPath = mainTableView.indexPath(for: cell) else { return }
        let settingItem = dataSource[indexPath.section][indexPath.row]
        
        if settingItem.tag == ScreenLockItemType.pattern.rawValue {
            let shouldBeEnabled = isOn;
            if shouldBeEnabled == isPatternUnlockEnabled() {
                Logger.error("\(self.logTag) ignoring redundant screen lock.")
                return;
            }
            if shouldBeEnabled {
                currentOpenItemType = .pattern
                switchPatternOn(with: false)
            } else {
                showVerifyVC(itemType: .pattern)
            }
            
        } else if settingItem.tag == ScreenLockItemType.password.rawValue {
            let shouldBeEnabled = isOn;
            if shouldBeEnabled == isPasswordUnlockEnabled() {
                Logger.error("\(self.logTag) ignoring redundant screen lock.")
                return;
            }
            
            Logger.info("\(self.logTag) trying to set is screen lock enabled: \(shouldBeEnabled)")
            
            if shouldBeEnabled {
                currentOpenItemType = .password
                switchPasswordOn(with: false)
            } else {
                showVerifyVC(itemType: .password)
            }
        } else if settingItem.tag == ScreenLockItemType.patternPath.rawValue {
            setPatternPathUnlockEnabled(isOn)
        }
    }
    
    func showBindEmailPhoneAlert() {
        let alert = UIAlertController(title: Localized("SETTINGS_VERIFY_EMAIL_NUMBER_TITLE"),
                                      message: Localized("SETTINGS_DRAW_CONTINUE_PATTERN"),
                                      preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: Localized("SETTINGS_VERIFY_EMAIL_ACTION"), style: .default) { _ in
            let  modifyEmailVC : DTModifyBindedInfoController = DTModifyBindedInfoController()
            modifyEmailVC.titleString = Localized("SETTINGS_VC_TITLE_CHANGE_EMAIL",comment: "modifyEmailVC title")
            modifyEmailVC.modifyType = DTModifyTypeChangeEmail
            self.navigationController?.pushViewController(modifyEmailVC, animated: true)
        })
        
        alert.addAction(UIAlertAction(title: Localized("SETTINGS_VERIFY_NUMBER_ACTION"), style: .default) { _ in
            let  modifyPhoneNumberVC : DTModifyBindedInfoController = DTModifyBindedInfoController()
            modifyPhoneNumberVC.titleString = Localized("SETTINGS_VC_TITLE_CHANGE_PHONE_NUMBER",comment: "modifyPhoneNumberVC title")
            modifyPhoneNumberVC.modifyType = DTModifyTypeChangePhoneNumber
            self.navigationController?.pushViewController(modifyPhoneNumberVC, animated: true)
        })

        alert.addAction(UIAlertAction(title: Localized("SETTINGS_VERIFY_EMAIL_NUMBER_CANCEL"), style: .cancel) { _ in
            self.reloadPage()
        })

        present(alert, animated: true)
    }
    
    
    func shouldShowBindUI() -> Bool {
        let email = TSAccountManager.shared.loadStoredUserEmail()
        let phoneNumber = TSAccountManager.shared.loadStoredUserPhone()
        return (!DTParamsUtils.validateString(email).boolValue && !DTParamsUtils.validateString(phoneNumber).boolValue)
    }
    
    func shouldShowVerifyVC() -> Bool {
        return isPatternUnlockEnabled() || isPasswordUnlockEnabled()
    }
}

extension ScreenLockSelectedViewController {
    func switchPatternOn(with notVerify: Bool) {
        // 默认开启轨迹
        setPatternPathUnlockEnabled(true)
        
        if notVerify {
            showPattenSetVC()
        } else {
            if shouldShowVerifyVC() {
                let verifyVC = DTScreenLockBaseViewController.buildScreenLockView(viewType: .unlockScreen) { passcode in
                    self.navigationController?.popViewController(animated: false) {
                        if self.shouldShowBindUI() {
                            self.showBindEmailPhoneAlert()
                        } else {
                            self.showPattenSetVC()
                        }
                    }
                }
                self.navigationController?.pushViewController(verifyVC, animated: false)
                
            } else {
                if self.shouldShowBindUI() {
                    self.showBindEmailPhoneAlert()
                } else {
                    showPattenSetVC()
                }
            }
        }
    }
    
    func switchPasswordOn(with notVerify: Bool) {
        if notVerify {
            showSetPasscodeVC()
        } else {
            if shouldShowVerifyVC() {
                let verifyVC = DTScreenLockBaseViewController.buildScreenLockView(viewType: .unlockScreen) { passcode in
                    self.navigationController?.popViewController(animated: false) {
                        if self.shouldShowBindUI() {
                            self.showBindEmailPhoneAlert()
                        } else {
                            self.showSetPasscodeVC()
                        }
                    }
                }
                self.navigationController?.pushViewController(verifyVC, animated: false)
            } else {
                if self.shouldShowBindUI() {
                    self.showBindEmailPhoneAlert()
                } else {
                    showSetPasscodeVC()
                }
            }
        }
    }
    
    
    private func showPattenSetVC() {
        let patternSetVC = DTScreenLockBaseViewController.buildScreenLockView(viewType: .patternSet) { passcode in
        }
        self.navigationController?.pushViewController(patternSetVC, animated: false)
    }

    private func showSetPasscodeVC() {
        let setPasscodeVc = DTScreenLockBaseViewController.buildScreenLockView(viewType: .setPasscode) { passcode in
            self.showConfirmPasswordVC(with: passcode)
        }
        self.navigationController?.pushViewController(setPasscodeVc, animated: false)
    }
    
    private func showConfirmPasswordVC(with passcode: String? ) {
        let confirmPasscodeVc = DTScreenLockBaseViewController.buildScreenLockView(viewType: .confirmPasscode) { verifiedPasscode in
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
        }
        let confirmPasscode = confirmPasscodeVc as! DTConfirmPasscodeViewController
        confirmPasscode.verifiedPasscode = passcode ?? ""
        self.navigationController?.pushViewController(confirmPasscodeVc, animated: false)
    }
    
    func showVerifyVC(itemType: ScreenLockItemType) {
        // 用手势验证
        let verifyVC = DTScreenLockBaseViewController.buildScreenLockView(viewType: .unlockScreen) { passcode in
            if itemType == .pattern {
                ScreenLock.shared.removePattern()
            } else {
                ScreenLock.shared.removePasscode()
            }
            self.navigationController?.popViewController(animated: false)
        }
        self.navigationController?.pushViewController(verifyVC, animated: false)
    }
}
