//
//  AppSettingsViewController.swift
//  Signal
//
//  Created by hornet on 2023/5/23.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import SnapKit

class AppSettingsViewController : SettingBaseViewController {

    let settingDescriptionCell_AppSettings = "DTSettingDescriptionCell_AppSettings"
    let reuse_identifier_style_blank = "DTSettingDescriptionCell_Blank_AppSettings"
    public lazy var mainTableView: UITableView = {
        let mainTableView = UITableView(frame: CGRect.zero, style: .plain)
        if #available(iOS 15.0, *) {
            mainTableView.sectionHeaderTopPadding = 0;
        }
        mainTableView.delegate = self
        mainTableView.dataSource = self
        mainTableView.separatorStyle = .none
        mainTableView.estimatedRowHeight = 44
        mainTableView.rowHeight = UITableView.automaticDimension
        mainTableView.register(DTSettingDescriptionCell.self, forCellReuseIdentifier: settingDescriptionCell_AppSettings)
        mainTableView.register(DTBlankCell.self, forCellReuseIdentifier: reuse_identifier_style_blank)
        return mainTableView
    }()
    
    var signalAccount: SignalAccount?
    
    public lazy var headerTopView: UIView = {
        let headerTopView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: 44))
        return headerTopView
    }()
    
    public lazy var userAvatarImageView: DTAvatarImageView = {
        let userAvatarImageView = DTAvatarImageView.init()
        let imageViewSize = CGSize(width:54,height:54)
        userAvatarImageView.autoSetDimensions(to: CGSize(width: imageViewSize.width, height: imageViewSize.height))
        let contactsManager = Environment.shared.contactsManager;
        userAvatarImageView.translatesAutoresizingMaskIntoConstraints = false
        userAvatarImageView.layer.cornerRadius = imageViewSize.width/2.0
        userAvatarImageView.clipsToBounds = true
        return userAvatarImageView
    }()
    
    public lazy var nameLabel: UILabel = {
        let nameLabel = UILabel.init()
        nameLabel.font = UIFont.ows_dynamicTypeTitle3
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.textColor = Theme.primaryTextColor
        return nameLabel
    }()
    
    public lazy var signatureLabel: UILabel = {
        let signatureLabel = UILabel.init()
        signatureLabel.font = UIFont.ows_dynamicTypeBody2
        signatureLabel.adjustsFontForContentSizeCategory = true
        signatureLabel.textColor = Theme.secondaryTextColor
        signatureLabel.text = Localized("PROFILE_VIEW_TITLE")
        return signatureLabel
    }()
    var userName : String?
    var signature : String?

    /// cellStyle 不同的值对应不同的cell类型
    ///blank = 0
    ///onlyAccessory = 1
    ///noAccessoryAndNoDescription = 2
    ///onlyDescription = 3
    ///accessoryAndDescription = 4
    ///onlySwitch = 5
    ///checkBox = 6
    ///plainTextType = 7
    public var dataSource: [[DTSettingMeItem]] = []
    override func loadView() {
        super.loadView()
        prepareUIData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        prepareHeaderView()
        prepareView()
        prepareLayout()
        prepareTheme()
        NotificationCenter.default.addObserver(self, selector: #selector(signalAccountsDidChange), name: NSNotification.Name.OWSContactsManagerSignalAccountsDidChange, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateUserInfo()
        if isiPhoneSE() {
            DispatchQueue.main.async {
                self.fixTableViewInset()
            }
        }
    }
    
    private func fixTableViewInset() {
        let safeBottom = view.safeAreaInsets.bottom
        let bottomInset: CGFloat = max(safeBottom, 34)
        mainTableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: bottomInset, right: 0)
        mainTableView.scrollIndicatorInsets = mainTableView.contentInset
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if isiPhoneSE() {
            mainTableView.contentInsetAdjustmentBehavior = .never // 再保险一次
            mainTableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 34, right: 0)
            mainTableView.scrollIndicatorInsets = mainTableView.contentInset
        }
    }
    
    private func isiPhoneSE() -> Bool {
        return screenWidth == 667 || screenHeight == 667
    }
    
    override func applyTheme() {
        super.applyTheme()
        view.backgroundColor = Theme.defaultBackgroundColor
        mainTableView.backgroundColor = Theme.defaultBackgroundColor
        self.mainTableView.tableHeaderView?.backgroundColor = Theme.defaultBackgroundColor
        signatureLabel.textColor = Theme.secondaryTextColor
        nameLabel.textColor = Theme.primaryTextColor
        prepareHeaderView()
        self.databaseStorage.asyncRead { sdsAnyReadTransaction in
            self.dataSource = self.getDataSource(transaction: sdsAnyReadTransaction)
        } completion: {
            self.mainTableView.reloadData()
//            self.tabBarItem.title = Localized("TABBAR_ME");
        }
    }
    
    override func applyLanguage() {
        super.applyLanguage()
        self.databaseStorage.asyncRead { sdsAnyReadTransaction in
            self.dataSource = self.getDataSource(transaction: sdsAnyReadTransaction)
        } completion: {
            self.mainTableView.reloadData()
//            self.tabBarItem.title = Localized("TABBAR_ME");
        }
    }
    @objc
    func signalAccountsDidChange() {
        updateUserInfo()
    }
    
    func updateUserInfo() {
        let contactsManager = Environment.shared.contactsManager;
        guard let localNum = TSAccountManager.localNumber() else { return }
        guard let account = contactsManager?.signalAccount(forRecipientId: localNum) else { return }
        signalAccount = account
        if let localProfileName = signalAccount?.contact?.fullName.stripped {
            self.nameLabel.text = localProfileName
            userName = localProfileName
        }

        guard let avatar = self.signalAccount?.contact?.avatar as? [String: Any] else { return }
        userAvatarImageView.setImage(avatar: avatar, recipientId: TSAccountManager.localNumber(), displayName: self.signalAccount?.contactFullName(), completion: nil)
        
        prepareHeaderView()
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
        self.databaseStorage.asyncRead { sdsAnyReadTransaction in
            let contactsManager = Environment.shared.contactsManager;
            guard let localNum = self.tsAccountManager.localNumber(with: sdsAnyReadTransaction) else { return }
            if let account = contactsManager?.signalAccount(forRecipientId: localNum, transaction: sdsAnyReadTransaction) {
                self.signalAccount = account
            } else {
                Logger.debug("request profile info")
                self.requestProfileInfoAndGenerateSignalAccount(localNumber: localNum)
            }
            self.dataSource = self.getDataSource(transaction: sdsAnyReadTransaction)
        } completion: {
            guard let avatar = self.signalAccount?.contact?.avatar as? [String: Any] else { return }
            self.userAvatarImageView.setImage(avatar: avatar, recipientId: TSAccountManager.localNumber(), displayName: self.signalAccount?.contactFullName(), completion: nil)
            self.signature = self.signalAccount?.contact?.signature
            self.mainTableView.reloadData()
        }
    }
    
    func requestProfileInfoAndGenerateSignalAccount(localNumber: String) {
        TSAccountManager.sharedInstance().getContactMessage(byReceptid: localNumber) { contact in
            let signalAccount = SignalAccount.init(recipientId: localNumber)
            signalAccount.contact = contact
            self.signalAccount = signalAccount
            self.databaseStorage.asyncWrite { wTransaction in
                let contactsManager = Environment.shared.contactsManager;
                contactsManager?.updateSignalAccount(withRecipientId: localNumber, withNewSignalAccount: signalAccount, with: wTransaction)
            } completion: {
                self.mainTableView.reloadData()
                self.updateUserInfo()
            }
        } failure: { error in
            OWSLogger.info("request Profile Info")
            let signalAccount = SignalAccount.init(recipientId: localNumber)
            signalAccount.contact = Contact.init(fullName: localNumber, phoneNumber: localNumber)
            self.signalAccount = signalAccount
            self.databaseStorage.asyncWrite { wTransaction in
                let contactsManager = Environment.shared.contactsManager;
                contactsManager?.updateSignalAccount(withRecipientId: localNumber, withNewSignalAccount: signalAccount, with: wTransaction)
            } completion: {
                self.mainTableView.reloadData()
                self.updateUserInfo()
            }
        }
    }
    
    func prepareView() {
        view.addSubview(mainTableView)
    }
    
    func prepareLayout() {
        mainTableView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0), excludingEdge: .bottom)
        mainTableView.autoPinBottomToSuperviewMargin(withInset: 15)
    }
    
    func prepareHeaderView() {
        let headerView = UIView()
        
        let headerContainerView = UIView()
        headerContainerView.clipsToBounds = true
        headerContainerView.layer.cornerRadius = 10
        headerView.addSubview(headerContainerView)
        
        let profileRowView = UIView()
        profileRowView.backgroundColor = UIColor.clear
        let tapProfileGesture = UITapGestureRecognizer(target: self, action: #selector(profileRowAction))
        profileRowView.addGestureRecognizer(tapProfileGesture)
        let shareContactRowView = UIView()
        shareContactRowView.backgroundColor = UIColor.clear
        let tapShareContactGesture = UITapGestureRecognizer(target: self, action: #selector(shareContactRowAction))
        shareContactRowView.addGestureRecognizer(tapShareContactGesture)
        
        let seperateLineView: UIView = UIView()
        seperateLineView.backgroundColor = Theme.defaultBackgroundColor
        headerContainerView.addSubview(seperateLineView)
        
        headerContainerView.addSubview(profileRowView)
        headerContainerView.addSubview(shareContactRowView)
        
        let profileArrowIcon = UIImageView()
        profileArrowIcon.image = UIImage(named: "default_accessory_arrow")
        let shareContactArrowIcon = UIImageView()
        shareContactArrowIcon.image = UIImage(named: "default_accessory_arrow")
        let shareContactLabel = UILabel()
        shareContactLabel.font = UIFont.ows_dynamicTypeBody
        shareContactLabel.adjustsFontForContentSizeCategory = true
        shareContactLabel.textColor = Theme.primaryTextColor
        shareContactLabel.text = Localized("CONTACT_SHARE_CONTACT_TO_FRIENTS")
        let shareContactQRIcon = UIImageView()
        shareContactQRIcon.image = UIImage(named: "setting_qrcode")
        
        profileRowView.addSubview(userAvatarImageView)
        profileRowView.addSubview(nameLabel)
        profileRowView.addSubview(signatureLabel)
        profileRowView.addSubview(profileArrowIcon)
        
        shareContactRowView.addSubview(shareContactLabel)
        shareContactRowView.addSubview(shareContactQRIcon)
        shareContactRowView.addSubview(shareContactArrowIcon)
        
        headerView.backgroundColor = Theme.defaultBackgroundColor
        headerContainerView.backgroundColor = Theme.defaultTableCellBackgroundColor
        mainTableView.tableHeaderView = headerView
        
        headerView.frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), 173)
        //If use autolayout an exception may occur in datasource
//        headerView.snp.makeConstraints { make in
//            make.height.equalTo(235)
//            make.width.equalTo(CGRectGetWidth(self.view.bounds))
//        }
        
        headerContainerView.snp.makeConstraints { make in
            make.height.equalTo(131)
            make.top.equalToSuperview().offset(16)
            make.left.equalTo(16)
            make.right.equalTo(-16)
        }
        
        profileRowView.snp.makeConstraints { make in
            make.top.equalTo(12)
            make.left.equalTo(16)
            make.height.equalTo(54)
            make.right.equalTo(-16)
        }
        
        seperateLineView.snp.makeConstraints { make in
            make.top.equalTo(profileRowView.snp.bottom).offset(12)
            make.left.right.equalToSuperview()
            make.height.equalTo(1)
        }
        
        shareContactRowView.snp.makeConstraints { make in
            make.top.equalTo(seperateLineView.snp.bottom).offset(12)
            make.left.equalTo(16)
            make.height.equalTo(24)
            make.right.equalTo(-16)
        }
        
        userAvatarImageView.snp.makeConstraints { make in
            make.width.height.equalTo(54)
            make.left.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        nameLabel.snp.makeConstraints { make in
            make.left.equalTo(userAvatarImageView.snp.right).offset(16)
            make.top.equalToSuperview()
        }
        
        signatureLabel.snp.makeConstraints { make in
            make.left.equalTo(nameLabel.snp.left)
            make.bottom.equalToSuperview()
        }
        
        profileArrowIcon.snp.makeConstraints { make in
            make.width.height.equalTo(16)
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        shareContactLabel.snp.makeConstraints { make in
            make.height.equalTo(24)
            make.top.left.equalToSuperview()
        }
        
        shareContactArrowIcon.snp.makeConstraints { make in
            make.width.height.equalTo(16)
            make.right.equalToSuperview()
            make.centerY.equalToSuperview()
        }
        
        shareContactQRIcon.snp.makeConstraints { make in
            make.width.height.equalTo(24)
            make.right.equalTo(shareContactArrowIcon.snp.left).offset(-4)
            make.centerY.equalToSuperview()
        }
        
    }
}

extension AppSettingsViewController : UITableViewDelegate,UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionArr = self.dataSource[section];
        return sectionArr.count
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
        let sectionArr = self.dataSource[indexPath.section]
        let settingMeItem = sectionArr[indexPath.row]
        if(settingMeItem.cellStyle == .blank){
            let cell = tableView.dequeueReusableCell(withIdentifier: reuse_identifier_style_blank, for: indexPath) as? DTBlankCell
            guard let defaultStyleCell = cell else { return UITableViewCell.init()}
            defaultStyleCell.applyTheme()
            return defaultStyleCell
        } else if(settingMeItem.cellStyle == .onlyAccessory || settingMeItem.cellStyle == .accessoryAndDescription) {
            let cell = tableView.dequeueReusableCell(withIdentifier: settingDescriptionCell_AppSettings, for: indexPath) as? DTSettingDescriptionCell
            guard let defaultStyleCell = cell else { return UITableViewCell.init()}
            if (indexPath.row == 0){
                if (sectionArr.count == 1 && indexPath.row == 0){
                    defaultStyleCell.borderType = .all
                } else {
                    defaultStyleCell.borderType = .top
                }
                
            } else if(indexPath.row == (sectionArr.count - 1)){
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
        case .some(.account):
            //TODO: theme等需要从该控制器移除
            let accountVC = DTAccountSettingController()
            self.navigationController?.pushViewController(accountVC, animated: true)
        case .some(.privacy):
            let privacyVC = DTSecurityAndPrivacyViewController()
            self.navigationController?.pushViewController(privacyVC, animated: true)
        case .some(.notifications):
            let notificationsVC = DTNotificationSettingsController()
            self.navigationController?.pushViewController(notificationsVC, animated: true)
        case .some(.linked_device):
            guard let linkedDevicesVC  = UIStoryboard.main.instantiateViewController(withIdentifier: "OWSLinkedDevicesTableViewController") as? OWSLinkedDevicesTableViewController else {
                return
            }
            linkedDevicesVC.hidesBottomBarWhenPushed = true;
            linkedDevicesVC.linkFrom = DTLinkDeviceFromMe;
            self.navigationController?.pushViewController(linkedDevicesVC, animated: true)
        case .some(.theme):
            //TODO: theme窗口需要单独提出来
            let themeSettingVC = DTThemeSettingsTableViewController()
            self.navigationController?.pushViewController(themeSettingVC, animated: true)
        case .some(.language):
            //TODO: 设置语言的接口
            let languageSettingVC = DTLanguageSettingTableViewController()
            self.navigationController?.pushViewController(languageSettingVC, animated: true)
        case .some(.feedback):
            presentFeedbackView()
        case .some(.about):
            let aboutVc = AboutTableViewController()
            self.navigationController?.pushViewController(aboutVc, animated: true)
        case .some(.chat):
            let chatVC = DTChatSettingsController()
            self.navigationController?.pushViewController(chatVC, animated: true)
        case .none:
            OWSLogger.info("SettingMeItemType type none")
        }
    }
    
    func presentFeedbackView() {
        let thread = TSContactThread.getOrCreateThread(contactId: "+10000")
        SignalApp.shared().presentTargetConversation(for: thread, action: .none, focusMessageId: nil)
    }
}

//MARK:  用户自定义的按钮点击事件
extension AppSettingsViewController  {
    @objc func shareContactRowAction() {
        let inviteCodeViewController = DTInviteCodeViewController()
        let navController = OWSNavigationController(rootViewController: inviteCodeViewController)
        self.navigationController?.present(navController, animated: true)
    }
    //TODO: 待处理
    @objc func profileRowAction() {
        let editProfileController = DTSettingEditProfileController(editProfileType: .modify)
        self.navigationController?.pushViewController(editProfileController, animated: true)
    }
    
}
