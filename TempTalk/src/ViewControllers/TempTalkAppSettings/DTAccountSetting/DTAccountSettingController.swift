//
//  DTAccountController.swift
//  Signal
//
//  Created by hornet on 2023/5/31.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation

@objc
class DTAccountSettingController : SettingBaseViewController , DTDefaultBaseStyleCellLongPressDelegate{
    let reuse_identifier_style_blank = "DTDefaultStyleCell_AccountSetting_style_blank"
    let reuse_identifier_style_description = "DTDefaultStyleCell_AccountSetting_style_description"
    let reuse_identifier_style_switch = "DTDefaultStyleCell_AccountSetting_style_switch"
    let reuse_identifier_style_plaintext = "DTDefaultStyleCell_AccountSetting_style_plaintext"
    
    var notificationTypeValue : NSNumber = NSNumber(value: -1000)
    var contact : Contact?
    let logoutApi = DTLogoutApi()
    let profileInfoApi = DTProfileInfoApi()
    
    
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
        mainTableView.register(DTSettingPlanTextCell.self, forCellReuseIdentifier: reuse_identifier_style_plaintext)
        return mainTableView
    }()
    var signalAccount: SignalAccount?
    
    public lazy var dataSource: [[DTAccountSettingItem]] = {
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
        self.title = Localized("SETTINGS_ITEM_ACCOUNT", comment: "")
        prepareTheme()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        prepareUIData()
        getProfileInfo()
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

extension DTAccountSettingController : UITableViewDelegate,UITableViewDataSource {
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
        
        let settingMeItem : DTAccountSettingItem? = self.dataSource[indexPath.section][indexPath.row]
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
            defaultStyleCell.longPressDelegate = self
            defaultStyleCell.reloadCell(model: settingMeItem)
            if(settingMeItem.type == .logout){
                defaultStyleCell.titleTextColor = UIColor.color(rgbHex: 0xF84135)
            } else {
                defaultStyleCell.titleTextColor = Theme.primaryTextColor
            }
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
            defaultStyleCell.selectionStyle = .none
            defaultStyleCell.reloadCell(model: settingMeItem)
            return defaultStyleCell
            
        } else if(settingMeItem.cellStyle == .plainTextType){
            
            let cell = tableView.dequeueReusableCell(withIdentifier: reuse_identifier_style_plaintext, for: indexPath) as? DTSettingPlanTextCell
            guard let defaultStyleCell = cell else { return UITableViewCell.init()}
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
        case .some(.id):return
        case .some(.email):
            let  modifyEmailVC : DTModifyBindedInfoController = DTModifyBindedInfoController()
            modifyEmailVC.titleString = Localized("SETTINGS_VC_TITLE_CHANGE_EMAIL",comment: "modifyEmailVC title")
            modifyEmailVC.modifyType = DTModifyTypeChangeEmail
            self.navigationController?.pushViewController(modifyEmailVC, animated: true)
            return
        case .some(.phoneNumber):
            let  modifyPhoneNumberVC : DTModifyBindedInfoController = DTModifyBindedInfoController()
            modifyPhoneNumberVC.titleString = Localized("SETTINGS_VC_TITLE_CHANGE_PHONE_NUMBER",comment: "modifyPhoneNumberVC title")
            modifyPhoneNumberVC.modifyType = DTModifyTypeChangePhoneNumber
            self.navigationController?.pushViewController(modifyPhoneNumberVC, animated: true)
            return
        case .some(.logout):
            self.showlogoutAccountUI()
            return
        case .none:
            return
        }
    }
    
    func showlogoutAccountUI() {
        // 如果没有绑定手机号和邮箱信息, 给出提示
        let settingItems = dataSource.first { settingItems in
            let settingItem = settingItems.first { item in
                if item.type == .email {
                    return item.description != Localized("SETTINGS_ITEM_UNLINK_TIP",comment: "Action desc Unlink")
                } else if item.type == .phoneNumber {
                    return item.description != Localized("SETTINGS_ITEM_UNLINK_TIP",comment: "Action desc Unlink")
                } else {
                    return false
                }
            }
            
            return settingItem != nil
        }
        
        if let _ = settingItems {
            showLogoutAlert()
        } else { // 如果未绑定邮箱或者手机号, 提示用户删除账户
            showDeleteAccountAlert()
        }
    }
    
    private func showDeleteAccountAlert() {
        
        let alertController = UIAlertController(title: nil, message: Localized("ACCOUNT_LOGOUT_NOT_LINK_DESCRIPTION",comment: "alert account not link desc"), preferredStyle: .alert)
        alertController.addAction(OWSAlerts.cancelAction)
        alertController.addAction(UIAlertAction(title: Localized("PROCEED_BUTTON",comment: "proceed button"), style: .destructive,handler: { _ in
            self.deleteAccount()
        }))
        self.present(alertController, animated: true)
    }
    
    private func showLogoutAlert() {
        
        let alertController = UIAlertController(title: Localized("CONFIRM_ACCOUNT_LOGOUT_TITLE",comment: "alert title logout"), message: Localized("CONFIRM_ACCOUNT_LOGOUT_TIP_MESSAGE",comment: "alert logout desc"), preferredStyle: .alert)
        alertController.addAction(OWSAlerts.cancelAction)
        alertController.addAction(UIAlertAction(title: Localized("CONFIRM_ACCOUNT_ACTION_DELETE_AND_LOGOUT",comment: "Action logout desc"), style: .destructive,handler: { _ in
            self.logoutAccount()
        }))
        self.present(alertController, animated: true)
    }
    
    func deleteAccount() {
        let deleteAccount = DTDeleteAccountController()
        navigationController?.pushViewController(deleteAccount, animated: true)
    }
    
    func logoutAccount() {
        ModalActivityIndicatorViewController.present(fromViewController: self, canCancel: false) { modalActivityIndicator in
            self.logoutApi.logoutRequest { entity in
                SignalApp.resetAppData()
            } failure: { error, entity in
                DispatchMainThreadSafe {
                    modalActivityIndicator.dismiss {
                        SignalApp.resetAppData()
                    }
                }
            }
        }
    }
    
    func longPressClick(_ cell: DTDefaultBaseStyleCell, longPressGesture: UILongPressGestureRecognizer) {
        if(longPressGesture.state != .began){
            return
        }
        guard let indexPath = self.mainTableView.indexPath(for: cell) else { return  }
        let settingMeItem = self.dataSource[indexPath.section][indexPath.row]
        if(settingMeItem.type == .id || settingMeItem.type == .email || settingMeItem.type == .phoneNumber){
            self.copyWith(content: settingMeItem.description)
        }
    }
    
    func copyWith(content: String?) {
        if(!DTParamsUtils.validateString(content).boolValue){
            return
        }
        let pasteboard = UIPasteboard.general
        pasteboard.string = content
        DTToastHelper.toast(withText: Localized("COPYID",comment: "copy to pastboard"), durationTime: 2)
    }
    
    func getProfileInfo() {
        self.profileInfoApi.profileInfo(sucess: { _ in
            self.reloadPage()
        }) { _ in
            //            self.mainTableView.reloadData()
        }
    }
    
    func reloadPage() {
        self.dataSource = self.getDataSource()
        self.mainTableView.reloadData()
    }
}
