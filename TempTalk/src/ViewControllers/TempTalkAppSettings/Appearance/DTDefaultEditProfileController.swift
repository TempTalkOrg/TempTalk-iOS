//
//  DTSettingEditProfileController.swift
//  Signal
//
//  Created by hornet on 2023/5/25.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
import UIKit
import TTMessaging
import JSQMessagesViewController
import BlockiesSwift


@objc public enum EditProfileType: Int {
    case signup
    case modify
}

//APP内部编辑用户个人信息的页面 和 登录完成编辑用户的个人信息页面不是同一个页面
@objc
class DTSettingEditProfileController: OWSViewController {
    private let margin : CGFloat = 16
    
    var defaultUserName: String? {
        didSet {
            self.nameTextfield.text = defaultUserName
        }
    }
    let avatarViewHelper : AvatarViewHelper = AvatarViewHelper()
    var account: SignalAccount?
    
    private let loginAPiV2 = DTLoginApiV2()
    
    let skipButton: UIButton = UIButton()
    private lazy var iconView: UIImageView = {
        let iconView = UIImageView()
        iconView.layer.cornerRadius = 56
        iconView.layer.masksToBounds = true
        iconView.isUserInteractionEnabled = true
        let tap: UITapGestureRecognizer = UITapGestureRecognizer.init(target: self, action: #selector(iconImageClick))
        iconView.addGestureRecognizer(tap)
        return iconView
    }()
    
    private lazy var cameraImageView: UIImageView = {
        let cameraImageView = UIImageView(image: UIImage.init(named: "camera_icon"))
        return cameraImageView
    }()
    
    let cacheImageView = UIImageView()
    var iconImage: UIImage?

    private lazy var nameTipLabel: UILabel = {
        let nameLabel = UILabel.init()
        nameLabel.font = UIFont.systemFont(ofSize: 14)
        nameLabel.textColor = Theme.primaryTextColor
        let attributeText = NSMutableAttributedString(string: "*", attributes: [.foregroundColor : UIColor(rgbHex: 0xF84135)])
        attributeText.append(Localized("PROFILE_NAME_TIP",comment: "Profile name tip"))
        nameLabel.attributedText = attributeText
        nameLabel.textAlignment = .left
        nameLabel.numberOfLines = 1
        return nameLabel
    }()
    
    private lazy var nameTextfield: DTTextField = {
        let nameTextfield = DTTextField()
        nameTextfield.delegate = self
        nameTextfield.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
//        nameTextfield.textContentType = nil
        nameTextfield.placeholder = "Type your name here"
        nameTextfield.layer.borderWidth = 1
        nameTextfield.layer.cornerRadius = 8
        nameTextfield.clearButtonMode = .whileEditing
        nameTextfield.textColor = Theme.primaryTextColor
        nameTextfield.keyboardType = .default
        return nameTextfield
    }()
    
    private lazy var backButton: UIButton = {
        let backButton = UIButton.init()
        backButton.addTarget(self, action: #selector(backButtonClick), for: .touchUpInside)
        backButton.setImage(UIImage(named: "nav_back_arrow_new"), for: .normal)
        return backButton
    }()
    
    private lazy var refreshButton: UIButton = {
        let refreshButton = UIButton.init()
        refreshButton.addTarget(self, action: #selector(refreshButtonClick), for: .touchUpInside)
        refreshButton.setImage(UIImage(named: "signup_refresh"), for: .normal)
        return refreshButton
    }()
    
    private lazy var nextButton: OWSFlatButton = {
        let nextButton = OWSFlatButton()
        nextButton.setBackgroundColor(UIColor.ows_themeBlue, for: .normal)
        nextButton.setTitleColor(UIColor.white, for: .normal)
        nextButton.layer.cornerRadius = 8
        nextButton.layer.masksToBounds = true
        return nextButton
    }()
    
    private let editProfileType: EditProfileType
    
    public init(editProfileType: EditProfileType) {
        self.editProfileType = editProfileType
        
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func loadView() {
        super.loadView()
        self.navigationController?.navigationBar.isHidden = false
    }
    
     public override func viewDidLoad() {
         super.viewDidLoad()
         
         if .signup == editProfileType {
             setupNav()
         }
         configUI()
         configUILayout()
         configProperty()
         avatarViewHelper.delegate = self
         configTheme()
    }
    
    func configUI() {
        view.addSubview(iconView)
        view.addSubview(cameraImageView)
        view.addSubview(nameTipLabel)
        view.addSubview(nameTextfield)
        view.addSubview(nextButton)
    }
    
    func configUILayout() {
        iconView.autoPinEdge(toSuperviewSafeArea: .top, withInset: self.view.window?.safeAreaInsets.top ?? 24)
        iconView.autoHCenterInSuperview()
        iconView.autoSetDimension(.width, toSize: 112)
        iconView.autoSetDimension(.height, toSize: 112)
        
        cameraImageView.autoPinEdge(.right, to: .right, of: iconView, withOffset: -3)
        cameraImageView.autoPinEdge(.bottom, to: .bottom, of: iconView, withOffset: -3)
        cameraImageView.autoSetDimension(.width, toSize: 28)
        cameraImageView.autoSetDimension(.height, toSize: 28)
        
        nameTipLabel.autoPinEdge(.top, to: .bottom, of: iconView, withOffset: 24)
        nameTipLabel.autoPinEdge(.left, to: .left, of: view, withOffset: margin)
        nameTipLabel.autoSetDimension(.height, toSize: 20)
        nameTipLabel.autoSetDimension(.width, toSize: 150)
        
        nameTextfield.autoPinEdge(.top, to: .bottom, of: nameTipLabel, withOffset: 4)
        nameTextfield.autoPinEdge(.left, to: .left, of: view, withOffset: margin)
        nameTextfield.autoPinEdge(.right, to: .right, of: view, withOffset: -margin)
        nameTextfield.autoSetDimension(.height, toSize: 48)
        
       
        nextButton.autoPinEdge(.top, to: .bottom, of: nameTextfield, withOffset: margin)
        nextButton.autoPinEdge(.left, to: .left, of: nameTextfield, withOffset: 0)
        nextButton.autoPinEdge(.right, to: .right, of: nameTextfield, withOffset: 0)
        nextButton.autoSetDimension(.height, toSize: 48)
    }
    
    override func applyTheme() {
        super.applyTheme()
        configTheme()
    }
    
    private func configTheme() {
        view.backgroundColor = Theme.backgroundColor
        nameTextfield.layer.borderColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x474D57).cgColor : UIColor.color(rgbHex: 0xEAECEF).cgColor
        nextButton.setTitleColor(UIColor.color(rgbHex: 0xFFFFFF), for: .selected)
        nextButton.setTitleColor(Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x5E6673) : UIColor.color(rgbHex: 0xB7BDC6), for: .normal)
        nextButton.setBackgroundColor(UIColor.color(rgbHex: 0x056FFA), for: .selected)
        nextButton.setBackgroundColor(Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x474D57) : UIColor.color(rgbHex: 0xEAECEF), for: .normal)
    }
    
    func setupNav() {
        let backItem = UIBarButtonItem.init(customView: self.backButton)
        self.navigationItem.leftBarButtonItem = backItem
        
        let rightItem = UIBarButtonItem.init(customView: self.refreshButton)
        self.navigationItem.rightBarButtonItem = rightItem
    }
    
    func configProperty() {

        if .signup == editProfileType {
            
            nextButton.setTitle(title: Localized("SIGN_UP_START_TO_CHAT", comment: "Start to chat after signup"), font: OWSFlatButton.orignalFontForHeight(16), titleColor: .ows_white)
            nextButton.addTarget(target: self, selector: #selector(startToChatButtonClick))
            refreshRandomAvatarAndName()
        } else if .modify == editProfileType {
            
            var fullname: String?
            var localNumber: String?
            self.databaseStorage.asyncRead { readTransaction in
                guard let cLocalNumber = self.tsAccountManager.localNumber(with: readTransaction) else { return }
                localNumber = cLocalNumber
                let contactsManager = Environment.shared.contactsManager
                self.account = contactsManager?.signalAccount(forRecipientId: cLocalNumber, transaction: readTransaction)
                fullname = self.account?.contact?.fullName
            } completion: {
                self.defaultUserName = fullname
                if let avatar = self.account?.contact?.avatar as? [AnyHashable : Any]  {
                    self.iconView.setImageWithContactAvatar(avatar,
                                                            recipientId: localNumber,
                                                            displayName: self.account?.contact?.fullName ,
                                                            completion: nil)
                    
                } else {
                    self.iconView.image = UIImage(named: "icon_header")
                }
            }

            nextButton.setTitle(title: Localized("PROFILE_VIEW_SAVE_BUTTON", comment: "Action edit Profile"), font: OWSFlatButton.orignalFontForHeight(16), titleColor: .ows_white)
            nextButton.addTarget(target: self, selector: #selector(nextButtonClick))
            nextButton.isSelected = false
            nextButton.isUserInteractionEnabled = false
            
            self.title = Localized("PROFILE_STATUS_EDIT_ONFO",
                                   comment: "Action edit Profile")
            
        }
    }
    
    @objc func backButtonClick() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc func refreshButtonClick() {
        refreshRandomAvatarAndName()
    }
    
    @objc func startToChatButtonClick() {
        DTToastHelper.showHud(in: view)
        
        loginAPiV2.receiveNonceInfo { [weak self] entity in
            guard let self else { return }
            guard let responseJson = entity.data as? [String: Any],
            let uuid = responseJson["uuid"] as? String,
            let timestamp = responseJson["timestamp"] as? Int64,
            let powVer = responseJson["version"] as? Int64,
            let powDif = responseJson["difficulty"] as? Int64 else {
                Logger.warn("get nonce infomation params error")
                DTToastHelper.hide()
                let errorMessage = NSError.defaultErrorMessage()
                DTToastHelper.toast(withText: errorMessage, durationTime: 3.0)
                return
            }
            
            Logger.info("nonce info api success")
            
            let pow = SHA256Tool(difficulty: Int(powDif))
            let challenge = "\(uuid)\(timestamp)\(powVer)" // 增加时间戳
            var solution = ""
            while true {
                solution = RandomString(length: 30).nextString() // 生成随机字符串
                if pow.verifySolution(challenge: challenge, solution: solution) {
                    Logger.info("generate solution success")
                    break
                }
            }
            generateNoceCodeApi(uuid, solution: solution)
        } failure: { error in
            DTToastHelper.hide()
            let errorMessage = NSError.errorDesc(error, errResponse: nil)
            DTToastHelper.toast(withText: errorMessage, durationTime: 3.0)
            Logger.error("nonce info api failure")
        }
    }
    
    private func generateNoceCodeApi(_ uuid: String, solution: String?) {
        
        loginAPiV2.generateNonceCode(uuid, solution: solution, success: {  [weak self] entity in
            guard let self else { return }
            
            if let responseJson = entity.data as? [String: Any],
                let inviteCode = responseJson["code"] as? String, !inviteCode.isEmpty {
                self.register(inviteCode: inviteCode) { [weak self] in
                    
                    guard let self else { return }
                    Logger.info("register success")
                    
                    // 上传头像昵称成功与失败都有继续进行后续流程
                    self.uploadNameAndAvatarToServer { [weak self] in
                        guard let self else { return }
                        
                        // 拉取个人信息成功与失败都要进入首页
                        self.getProfileInfoFromServer {
                            
                            DTToastHelper.hide()
                            self.signupComplete()
                        }
                    }
                } failureBlock: { errorNotice in
                    
                    DTToastHelper.hide()
                    DTToastHelper.toast(withText: errorNotice, durationTime: 3.0)
                }
            } else {
                
                DTToastHelper.hide()
                let errorMessage = NSError.defaultErrorMessage()
                DTToastHelper.toast(withText: errorMessage, durationTime: 3.0)
            }
        }, failure: { error in
            
            DTToastHelper.hide()
            let errorMessage = NSError.errorDesc(error, errResponse: nil)
            DTToastHelper.toast(withText: errorMessage, durationTime: 3.0)
        })
    }
    
    // 默认从 male 姓名开始, 每次轮换
    private var isMale: Bool = true
    
    private func refreshRandomAvatarAndName() {
        let name = NameGenerator.generateRandomName(isMale: isMale)
        nameTextfield.text = name
        
        // implement string to base64 string
        let base64Name = name?.data(using: .utf8)?.base64EncodedString()
        let blockies = Blockies(seed: base64Name)
        let img = blockies.createImage(customScale: 10)
        iconView.image = img
        
        isMale = !isMale
        
        checkNextButtonState(typeingTextFiled: nameTextfield, nextButton: nextButton)
    }
    
     @objc
     func iconImageClick() {
         avatarViewHelper.showChangeAvatarUI()
     }
    
    func showHomeView() {
        let appDelegate: AppDelegate? = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.switchToTabbarVC(fromRegistration: true)
    }
    
    @objc
    func nextButtonClick() {
        uploadMessageToServer()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.isNavigationBarHidden = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        nameTextfield.becomeFirstResponder()
    }
}

extension DTSettingEditProfileController: AvatarViewHelperDelegate {
    public func avatarActionSheetTitle() -> String {
        return Localized("PROFILE_VIEW_AVATAR_ACTIONSHEET_TITLE",
                                 comment: "Action edit Profile")
    }
    
    public func avatarDidChange(_ image: UIImage) {
        let circleImage = JSQMessagesAvatarImageFactory.circularAvatarImage(image, withDiameter: 112);
        self.iconImage = circleImage
        self.iconView.image = circleImage
        if let string = self.nameTextfield.text, string.count > 0, circleImage != nil {
            nextButton.isSelected = true
            nextButton.isUserInteractionEnabled = true
        }
    }
    
    public func fromViewController() -> UIViewController {
        return self
    }
    
    public func hasClearAvatarAction() -> Bool {
        return false;
    }
    
    func uploadMessageToServer() {
        guard let localNumber = TSAccountManager.shared.localNumber() else {return}
        guard let signalAccount = account , let contact = signalAccount.contact else {return}
        let img : UIImage?
        if(self.iconImage == nil) {
            img = nil
        } else { img = self.iconImage}
        
        let newName : String?
        if(nameTextfield.text?.stripped != nil && nameTextfield.text?.stripped != contact.fullName){
            newName = nameTextfield.text?.stripped
        } else {
            newName = contact.fullName.stripped
        }
        DTToastHelper.show()
        OWSProfileManager.shared().updateLocalProfileName(newName, avatarImage: img) {
            self.databaseStorage.asyncWrite { wTransaction in
                let contactsManager = Environment.shared.contactsManager;
                let avatar = OWSProfileManager.shared().localAvatar()
                if(self.iconImage != nil){
                    contact.avatar = avatar
                }
                if let newName = newName, newName.count > 0 {
                    contact.fullName = newName
                }
                signalAccount.contact = contact
                contactsManager?.updateSignalAccount(withRecipientId: localNumber, withNewSignalAccount: signalAccount, with: wTransaction)
                if(self.iconImage != nil) {
                    self.cacheImageView.setImageWithContactAvatar(contact.avatar, recipientId: localNumber, displayName: contact.fullName ,completion: nil)
                }
            } completion: {
                DTToastHelper.hide()
                DispatchMainThreadSafe {
                    self.navigationController?.popViewController(animated: true)
                }
            }
        } failure: {
            DTToastHelper.hide()
            DTToastHelper.toast(withText: Localized("PROFILE_VIEW_ERROR_UPDATE_FAILED",
                                                            comment: "Action edit Profile") , in: self.view.window!, durationTime: 3, afterDelay: 1)
        }
    }
}

extension DTSettingEditProfileController: UITextFieldDelegate {
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let limitation = 30
        
        let currentLength = textField.text?.count ?? 0 // 当前长度
        if (range.length + range.location > currentLength){
            return false
        }
        // 禁用启用按钮
        let newLength = currentLength + string.count - range.length // 加上输入的字符之后的长度
        return newLength <= limitation
    }
    
    
    @objc
    public func textFieldDidChange(_ textField: UITextField) {
        checkNextButtonState(typeingTextFiled: textField, nextButton: nextButton)
        guard textField == self.nameTextfield, let contentText = textField.text else { return }
        if(contentText.count > 30){
            let startIndex = contentText.index(contentText.startIndex, offsetBy: 0)
            let endIndex = contentText.index(contentText.startIndex, offsetBy: 30)
            
            let range = startIndex ..< endIndex
            let rangeRange = contentText.rangeOfComposedCharacterSequences(for:range)
            let result = "\(contentText[rangeRange])"
            textField.text = result;
        }
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        checkNextButtonState(typeingTextFiled: textField, nextButton: nextButton)
    }
    
    func checkNextButtonState(typeingTextFiled textField: UITextField, nextButton: OWSFlatButton) {
        
        if .signup == editProfileType {
            
            if let name = textField.text, !name.isEmpty {
                nextButton.isSelected = true
                nextButton.isUserInteractionEnabled = true
            }
        } else if .modify == editProfileType {
            
            // case 1: 用户在名字的输入框中输入，且名字发生了变化, 签名不管它是不是发生了变化
            if textField == self.nameTextfield ,
               let string = textField.text , string.count > 0 ,
               string != defaultUserName {
                
                nextButton.isSelected = true
                nextButton.isUserInteractionEnabled = true
                
            } else {
               
                nextButton.isSelected = false
                nextButton.isUserInteractionEnabled = false
               
            }
        }
    }
}


extension DTSettingEditProfileController {
    
    func register(inviteCode: String, successBlock: (() -> Void)?, failureBlock: ((_ errorNotice: String) -> Void)?) {
        
        // 使用 invitecode 获取 vcode
        TSAccountManager.shared.exchangeAccount(withInviteCode: inviteCode) { [weak self] metaEntity in
            guard let self else { return }
            
            if let responseData = metaEntity.data as? [String: Any],
               let account = responseData["account"] as? String, !account.isEmpty,
               let vCode = responseData["vcode"] as? String, !vCode.isEmpty {
                
                self.tsAccountManager.phoneNumberAwaitingVerification = account
//                self.vCode = vCode
//                [self submitVerificationWithCode:self.vCode screenLock:nil];
                // 使用 vcode 登录
                DTLoginNeedUnlockScreen.checkIfNeedScreenlock(vcode: vCode, screenlock: nil, processedVc: self) {
                    successBlock?()
                } errorBlock: { errorString in
                    failureBlock?(errorString)
                }
            } else {
                failureBlock?(NSError.defaultErrorMessage())
            }
            
        } failure: { error in
            let errorMessage = NSError.errorDesc(error, errResponse: nil)
            failureBlock?(errorMessage)
        }
    }
}

extension DTSettingEditProfileController {
    
    private func uploadNameAndAvatarToServer(completeBlock: (() -> Void)?) {

        // signup 时有默认头像和昵称
        let avatarImage = iconView.image
        let fullName = nameTextfield.text?.stripped
        
        OWSProfileManager.shared().updateLocalProfileName(fullName, avatarImage: avatarImage) {

            completeBlock?()
        } failure: {
//            let errorNotice = Localized("PROFILE_VIEW_ERROR_UPDATE_FAILED", comment: "Action edit Profile")
            completeBlock?()
        }
    }
    
    private func getProfileInfoFromServer(completeBlock: (() -> Void)?) {
        if let localNumber = self.tsAccountManager.localNumber() {
            self.tsAccountManager.getContactMessage(byReceptid: localNumber) { contact in
                
                self.databaseStorage.asyncWrite { writeTransaction in
                    
                    let contactsManager = Environment.shared.contactsManager
                    
                    var account = contactsManager?.signalAccount(forRecipientId: localNumber, transaction: writeTransaction)
                    if account == nil {
                        account = SignalAccount.init(recipientId: localNumber)
                    }
                    account!.contact = contact
                    contactsManager?.updateSignalAccount(withRecipientId: localNumber, withNewSignalAccount: account!, with: writeTransaction)
                } completion: {
                    completeBlock?()
                }
            } failure: { error in
                completeBlock?()
            }
        }
    }
    
    private func signupComplete() {
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.switchToTabbarVC(fromRegistration: true)
        }
        
        DTCallManager.sharedInstance().requestForConfigMeetingversion()
    }
}
