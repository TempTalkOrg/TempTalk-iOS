//
//  DTChatSettingsController.swift
//  Difft
//
//  Created by Henry on 2025/6/13.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

class DTChatSettingsController : SettingBaseViewController {
    fileprivate let reuse_identifier_style_blank = "DTDefaultStyleCell_Chat_style_blank"
    fileprivate let reuse_identifier_style_description = "DTDefaultStyleCell_Chat_style_description"
    fileprivate let reuse_identifier_style_switch = "DTDefaultStyleCell_Chat_style_switch"
    fileprivate let reuse_identifier_style_plaintext = "DTDefaultStyleCell_Chat_style_plaintext"
    
    let profileInfoApi = DTChatProfileInfoApi()
    let setProfileApi = DTChatSetProfileApi()
    var isSavePhotos: Bool = true //是否保存到相册，默认是true
    
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
    
    
    override func loadView() {
        super.loadView()
        prepareView()
        prepareLayout()
        dataSource = getDataSource()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = Localized("SETTINGS_CHAT", comment: "")
        prepareTheme()
        getProfileInfo()
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        // 刷新数据以更新语音播放速度等设置
        reloadPage()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func applyTheme() {
        super.applyTheme()
        view.backgroundColor = Theme.bgpageSecondaryColor
        mainTableView.backgroundColor = Theme.bgpageSecondaryColor
        self.mainTableView.tableHeaderView?.backgroundColor = Theme.defaultColor
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
    
    func getProfileInfo() {
        self.profileInfoApi.profileInfo(sucess: { entity in
            if entity?.status == 0,
               let data = entity?.data,
               let contacts = data["contacts"] as? [[String: Any]],
               let contactDict = contacts.first {
                do {
                    let contact = try MTLJSONAdapter.model(of: Contact.self, fromJSONDictionary: contactDict) as? Contact
                    if let contact = contact,
                       let privateConfigs = contact.privateConfigs {
                        self.isSavePhotos = privateConfigs.saveToPhotos
                        MediaSavePolicyManager.shared.updateSaveToPhoto(needSave: self.isSavePhotos)
                    }
                } catch {
                    Logger.error("getProfileInfo: Failed to parse Contact model: \(error)")
                }
            }
            self.reloadPage()
        }) { _ in
            self.reloadPage()
        }
    }
    
}

//MARK: tableView delegate
extension DTChatSettingsController : UITableViewDelegate, UITableViewDataSource {
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
    
    func reloadPage() {
        self.dataSource = self.getDataSource()
        self.mainTableView.reloadData()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let settingItem = self.dataSource[indexPath.section][indexPath.row]
        if settingItem.tag == ChatItemType.voicePlaybackSpeed.rawValue {
            // 打开播放速度选择页面
            let speedVC = VoicePlaybackSpeedViewController()
            speedVC.delegate = self
            navigationController?.pushViewController(speedVC, animated: true)
        } else if settingItem.tag == ChatItemType.voiceChanger.rawValue {
            // 打开变声选择页面
            let voiceChangerVC = VoiceChangerSettingViewController()
            voiceChangerVC.delegate = self
            navigationController?.pushViewController(voiceChangerVC, animated: true)
        }
    }
}

//MARK:  DataSource
extension DTChatSettingsController {
    
    enum ChatItemType: Int {
        case savePhotos = 0
        case voicePlaybackSpeed = 1
        case voiceChanger = 2
    }

    func getDataSource() -> [[DTSettingItem]] {
        let blanckItem = DTSettingItem(icon: "", title: "", description: "", cellStyle: SettingCellStyle.blank.rawValue)

        // Save Photos Section
        let chatSwitchItem = DTSettingItem(icon: "", title: Localized("SETTINGS_CHAT_SAVE_PHOTOS"), description: "", cellStyle: SettingCellStyle.onlySwitch.rawValue, openSwitch: MediaSavePolicyManager.shared.getSaveToPhotoStatus())
        chatSwitchItem.tag = ChatItemType.savePhotos.rawValue
        let chatTipsItem = DTSettingItem(icon: "", title: "", description: "", cellStyle: SettingCellStyle.plainTextType.rawValue, plainText:  Localized("SETTINGS_CHAT_SAVE_PHOTOS_DESCRIPTION"))

        // Voice Playback Speed Section
        let currentRate = MediaSavePolicyManager.shared.getPlaybackSpeed()
        let rateText: String
        if currentRate == 1.5 {
            rateText = "1.5x"
        } else if currentRate == 2.0 {
            rateText = "2x"
        } else {
            rateText = "1x"
        }
        let voiceSpeedItem = DTSettingItem(icon: "", title: Localized("SETTINGS_CHAT_VOICE_PLAYBACK_SPEED"), description: rateText, cellStyle: SettingCellStyle.accessoryAndDescription.rawValue)
        voiceSpeedItem.tag = ChatItemType.voicePlaybackSpeed.rawValue
        let voiceSpeedTipsItem = DTSettingItem(icon: "", title: "", description: "", cellStyle: SettingCellStyle.plainTextType.rawValue, plainText: Localized("SETTINGS_CHAT_VOICE_PLAYBACK_SPEED_DESCRIPTION"))

        // Voice Changer Section
        let currentPreset = CallSettingsManager.shared.getVoicePreset() ?? CallSettingsManager.defaultVoicePreset
        let presetNameKey = DTUpdateNoiseController.voicePresets.first { $0.key == currentPreset }?.nameKey ?? "CALLING_VOICE_PRESET_ORIGINAL"
        let voiceChangerItem = DTSettingItem(icon: "", title: Localized("SETTINGS_CHAT_VOICE_CHANGER"), description: Localized(presetNameKey), cellStyle: SettingCellStyle.accessoryAndDescription.rawValue)
        voiceChangerItem.tag = ChatItemType.voiceChanger.rawValue
        let voiceChangerTipsItem = DTSettingItem(icon: "", title: "", description: "", cellStyle: SettingCellStyle.plainTextType.rawValue, plainText: Localized("SETTINGS_CHAT_VOICE_CHANGER_DESCRIPTION"))

        return [[blanckItem],
                [chatSwitchItem],
                [chatTipsItem],
                [blanckItem],
                [voiceSpeedItem],
                [voiceSpeedTipsItem],
                [blanckItem],
                [voiceChangerItem],
                [voiceChangerTipsItem]]
    }
}

//MARK:  switch action
extension DTChatSettingsController : DTSettingSwitchCellDelegate  {

    func switchValueChanged(isOn: Bool, cell: DTDefaultBaseStyleCell) {
        if let settingItem = cell.model {
            if settingItem.tag == ChatItemType.savePhotos.rawValue {
                chatEnabledChangeAction(isOn: isOn, cell: cell)
            }
        }
    }

    func chatEnabledChangeAction(isOn: Bool, cell: DTDefaultBaseStyleCell) {
        // 直接本地保存，不再调用服务端接口
        self.isSavePhotos = isOn
        MediaSavePolicyManager.shared.updateSaveToPhoto(needSave: self.isSavePhotos)
    }
}

//MARK: VoicePlaybackSpeedDelegate
extension DTChatSettingsController: VoicePlaybackSpeedDelegate {
    func didSelectPlaybackSpeed(_ speed: Float) {
        // 刷新页面显示新的速度
        reloadPage()
    }
}

//MARK: VoiceChangerSettingDelegate
extension DTChatSettingsController: VoiceChangerSettingDelegate {
    func didSelectVoiceChangerPreset(_ preset: String) {
        // 刷新页面显示新的变声预设
        reloadPage()
    }
}

