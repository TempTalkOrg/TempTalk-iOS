//
//  AboutTableViewController.swift
//  Signal
//
//  Created by Kris.s on 2024/11/15.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import SafariServices
import TTServiceKit

class AboutTableViewController : SettingBaseViewController {
    
    fileprivate let websiteUrl = "https://TempTalk.app"
    
    fileprivate let reuse_identifier_style_blank = "DTDefaultStyleCell_SecurityAndPrivacy_style_blank"
    fileprivate let reuse_identifier_style_description = "DTDefaultStyleCell_SecurityAndPrivacy_style_description"
    
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
        self.title = Localized("SETTINGS_ITEM_ABOUT", comment: "")
        prepareTheme()
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
}

//MARK: tableView delegate
extension AboutTableViewController : UITableViewDelegate, UITableViewDataSource {
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
            defaultStyleCell.titleTextColor = Theme.primaryTextColor
            return defaultStyleCell
            
        } else {
            
            return UITableViewCell.init()
            
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let settingItem = dataSource[indexPath.section][indexPath.row]
        if settingItem.tag == AboutViewItemType.checkForUpdate.rawValue {
            doUpdateCheck()
        } else if settingItem.tag == AboutViewItemType.website.rawValue {
            if let requestURL = URL(string: websiteUrl){
                let safariVC = SFSafariViewController(url: requestURL)
                safariVC.modalPresentationStyle = .fullScreen;
                self.navigationController?.present(safariVC, animated: true)
                
            }
        }
    }
    
    func doUpdateCheck() {
        guard let updater = ATAppUpdater.shared() else{
            return
        }
        
        updater.alertTitle = Localized("APP_UPDATE_NAG_ALERT_TITLE")
        updater.alertUpdateButtonTitle = Localized("APP_UPDATE_NAG_ALERT_UPDATE_BUTTON")
        updater.alertCancelButtonTitle = CommonStrings.cancelButton()
        updater.noUpdateAlertMessage = Localized("APP_UPDATE_NO_NEW_VERSION")
        updater.alertDoneTitle = Localized("OK")
        updater.showUpdateWithConfirmation()
    }
    
    func reloadPage() {
        self.dataSource = self.getDataSource()
        self.mainTableView.reloadData()
    }
}

//MARK:  DataSource
extension AboutTableViewController {
    
    enum AboutViewItemType: Int {
        case platform  = 0
        case version = 1
        case build = 2
        case checkForUpdate = 3
        case website = 4
    }
 
    func getDataSource() -> [[DTSettingItem]] {
        
        let spaceItem = DTSettingItem(icon: "", title: "", description: "", cellStyle: SettingCellStyle.blank.rawValue)
        
        let platformItem = DTSettingItem(icon: "", title: Localized("SETTINGS_PLATFORM"), description: "iOS", cellStyle: SettingCellStyle.onlyDescription.rawValue, plainText:  "")
        let versionItem = DTSettingItem(icon: "", title: Localized("SETTINGS_VERSION"), description: AppVersion.shared().currentAppReleaseVersion, cellStyle: SettingCellStyle.onlyDescription.rawValue, plainText:  "")
        let buildItem = DTSettingItem(icon: "", title: Localized("BUILD_SETTINGS_VERSION"), description: AppVersion.shared().currentAppBuildVersion, cellStyle: SettingCellStyle.onlyDescription.rawValue, plainText: "")
        let checkForUpdateItem = DTSettingItem(icon: "", title: Localized("CHECK_NEW_VERSION"), description: "", cellStyle: SettingCellStyle.accessoryAndDescription.rawValue, plainText: "")
        checkForUpdateItem.tag = AboutViewItemType.checkForUpdate.rawValue
        let websiteItem = DTSettingItem(icon: "", title: Localized("SETTINGS_WEBSITE"), description: "TempTalk.app", cellStyle: SettingCellStyle.accessoryAndDescription.rawValue, plainText: "")
        websiteItem.tag = AboutViewItemType.website.rawValue
        
        return [
            [spaceItem],
            [
                platformItem,
                versionItem,
                buildItem
            ],
            [spaceItem],
            [checkForUpdateItem],
            [spaceItem],
            [websiteItem]
        ]
    }
    
}

