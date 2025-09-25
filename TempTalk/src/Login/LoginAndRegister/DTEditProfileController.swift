//
//  DTEditProfileController.swift
//  Signal
//
//  Created by hornet on 2022/12/24.
//  Copyright © 2022 Difft. All rights reserved.
//


import Foundation
import UIKit
import TTMessaging
import JSQMessagesViewController



@objc
 public class DTEditProfileController: OWSViewController {
    
     fileprivate let kMaxRemarkNameLength: Int32 = 30
    
    let skipButton: UIButton = UIButton()
    let iconView: UIImageView = UIImageView()
    let cacheImageView = UIImageView()
    var iconImage: UIImage?
    let nameTextfield: DTTextField = DTTextField()
    var defaultUserName: String?
    let avatarViewHelper : AvatarViewHelper = AvatarViewHelper()
    var account: SignalAccount?
    var nextButton: OWSFlatButton?
    var phoneNumber: String?
    let passKeyManager: DTPasskeyManager = TSAccountManager.sharedInstance().passKeyManager;
    var email: String?
    @objc public var loginType: DTLoginModeType = DTLoginModeTypeRegisterEmailFromLogin
    @objc
     required init(email: String?, phoneNumber: String?) {
        
        super.init()
        self.email = email
        self.phoneNumber = phoneNumber
        nextButton = OWSFlatButton.button(title: Localized("WEA_LOGIN_NEXT",
                                                                     comment: "Action edit Profile"), font: OWSFlatButton.orignalFontForHeight(16), titleColor: UIColor.white, backgroundColor: UIColor.ows_signalBrandBlue, target: self, selector: #selector(nextButtonClick))
        
        let array = email?.components(separatedBy: "@")
        let userName = array?.first;
        self.defaultUserName = userName
        
        let localNumber = TSAccountManager.shared.localNumber()
        self.databaseStorage.write { writeTransaction in
            guard let localNumber = localNumber else {return}
            let contactsManager = Environment.shared.contactsManager
            self.account = contactsManager?.signalAccount(forRecipientId: localNumber, transaction: writeTransaction)
            if self.account == nil {
                self.account = SignalAccount.init(recipientId: localNumber)
                let contact = Contact.init(recipientId: localNumber)
                self.account?.contact = contact
                self.account?.anyInsert(transaction: writeTransaction)
            }
        }
        
    }
     
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
     public override func loadView() {
        super.loadView()
    }
    
     public override func viewDidLoad() {
         super.viewDidLoad()
         setupNav()
         configUI()
         configUILayout()
         configProperty()
         avatarViewHelper.delegate = self
         nameTextfield.delegate = self
         nameTextfield.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
         nameTextfield.becomeFirstResponder()
         nameTextfield.textContentType = nil
    }
    
    func configUI() {
        guard let nextButton = nextButton else {return}
        view.backgroundColor = Theme.backgroundColor
        view.addSubview(iconView)
        view.addSubview(nameTextfield)
        view.addSubview(nextButton)
    }
    
    func configUILayout() {
        guard let nextButton = nextButton else {return}
        
        iconView.autoPinEdge(toSuperviewSafeArea: .top, withInset: 112)
        iconView.autoHCenterInSuperview()
        iconView.autoSetDimension(.width, toSize: 112)
        iconView.autoSetDimension(.height, toSize: 112)
        
        nameTextfield.autoPinEdge(.top, to: .bottom, of: iconView, withOffset: 24)
        nameTextfield.autoPinEdge(.left, to: .left, of: view, withOffset: 16)
        nameTextfield.autoPinEdge(.right, to: .right, of: view, withOffset: -16)
        nameTextfield.autoSetDimension(.height, toSize: 48)
        
        nextButton.autoPinEdge(.top, to: .bottom, of: nameTextfield, withOffset: 16)
        nextButton.autoPinEdge(.left, to: .left, of: nameTextfield, withOffset: 0)
        nextButton.autoPinEdge(.right, to: .right, of: nameTextfield, withOffset: 0)
        nextButton.autoSetDimension(.height, toSize: 48)
        
    }
    
    func setupNav() {
        self.leftTitle = Localized("PROFILE_STATUS_ONFO",
                                           comment: "Action edit Profile")
        if(self.loginType != DTLoginModeTypeRegisterEmailFromLogin && self.loginType != DTLoginModeTypeRegisterPhoneNumberFromLogin){
            let skipButton = UIButton()
            skipButton.setTitleColor(UIColor.color(rgbHex: 0x848E9C), for: .normal)
            skipButton.setTitle("Skip", for: .normal)
            skipButton.addTarget(self, action: #selector(skipButtonClick), for: .touchUpInside)
            let barSkipBarButtonItem = UIBarButtonItem.init(customView: skipButton)
            self.navigationItem.rightBarButtonItems = [barSkipBarButtonItem]
        }
    }
    
    func configProperty() {
        iconView.image = UIImage(named: "icon_header")
        iconView.isUserInteractionEnabled = true
        let tap: UITapGestureRecognizer = UITapGestureRecognizer.init(target: self, action: #selector(iconImageClick))
        iconView.addGestureRecognizer(tap)
        
        
        nameTextfield.placeholder = "Type your name here"
        nameTextfield.layer.borderWidth = 1
        nameTextfield.layer.borderColor = UIColor.color(rgbHex: 0xEAECEF).cgColor
        nameTextfield.layer.cornerRadius = 8
        nameTextfield.clearButtonMode = .whileEditing
        nameTextfield.textColor = Theme.primaryTextColor
       
        
        guard let nextButton = nextButton else {return}
        nextButton.setTitleColor(UIColor.color(rgbHex: 0xFFFFFF), for: .selected)
        nextButton.setTitleColor(Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x5E6673) : UIColor.color(rgbHex: 0xB7BDC6), for: .normal)
        nextButton.setBackgroundColor(UIColor.color(rgbHex: 0x056FFA), for: .selected)
        nextButton.setBackgroundColor(Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x474D57) : UIColor.color(rgbHex: 0xEAECEF), for: .normal)
        if let defaultUserName = defaultUserName, defaultUserName.stripped.count > 0 {
            nameTextfield.text = defaultUserName
            nextButton.isSelected = true
            nextButton.isUserInteractionEnabled = true
        } else {
            nextButton.isSelected = false
            nextButton.isUserInteractionEnabled = false
        }
    }
    
     @objc
     func iconImageClick() {
         avatarViewHelper.showChangeAvatarUI()
     }
     
    @objc
     func skipButtonClick() {
        showHomeView()
    }
    
    func showHomeView() {
        let appDelegate: AppDelegate? = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.switchToTabbarVC(fromRegistration: true)
    }
     
     func showSetUpPasskeyController() {
         let setUpPasskeysVC : DTSetUpPasskeysController = DTSetUpPasskeysController.init();
         setUpPasskeysVC.loginType = self.loginType;
         if(self.loginType == DTLoginModeTypeRegisterEmailFromLogin){
             setUpPasskeysVC.email = self.email;
         }
         
         if(self.loginType == DTLoginModeTypeRegisterPhoneNumberFromLogin){
             setUpPasskeysVC.phoneNumber = self.phoneNumber
         }
         self.navigationController?.pushViewController(setUpPasskeysVC, animated: true);
        //            [self.navigationController pushViewController:setUpPasskeysVC animated:true];
     }
    
    @objc
    func nextButtonClick() {
        uploadImageAndNameToServer()
    }
    
     public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
     
     func updateNameToServer(name: String) {
         let localNumber = TSAccountManager.shared.localNumber()
         let parms = ["name":name];
         let request = OWSRequestFactory.putV1Profile(withParams: parms)
         DTToastHelper.showHud(in: view)
         networkManager.makeRequest(request) { response in
             DTToastHelper.hide()
             guard let responseObject = response.responseBodyJson as? [String : Any]? else {return}
             if let status = responseObject?["status"] as? NSNumber ,status.intValue == 0 , let localNumber = localNumber{
                 let userName = name;
                 self.databaseStorage.asyncWrite { transation in
                     let contactsManager = Environment.shared.contactsManager;
                     let account = contactsManager?.signalAccount(forRecipientId: localNumber, transaction: transation)
                     account?.contact?.fullName = userName
                     guard let contactsManager = contactsManager, let account = account else {return}
                     contactsManager.updateSignalAccount(withRecipientId: localNumber, withNewSignalAccount: account, with: transation)
                 }
             } else {
                 if let reason = responseObject?["reason"] as? String{
                     DTToastHelper.toast(withText: reason)
                 } else {
                     DTToastHelper.toast(withText: kDTAPIDataErrorDescription)
                 }
             }
         } failure: { errorWrapper in
             let error = errorWrapper.asNSError
             let errorMessage = NSError.errorDesc(error, errResponse: nil)
             DTToastHelper.toast(withText: errorMessage)
             DTToastHelper.hide()
         }
     }
}

extension DTEditProfileController: AvatarViewHelperDelegate {
    public func avatarActionSheetTitle() -> String {
        return Localized("PROFILE_VIEW_AVATAR_ACTIONSHEET_TITLE",
                                 comment: "Action edit Profile")
    }
    
    public func avatarDidChange(_ image: UIImage) {
        let circleImage = JSQMessagesAvatarImageFactory.circularAvatarImage(image, withDiameter: 112);
        self.iconImage = circleImage
        self.iconView.image = circleImage
    }
    
    public func fromViewController() -> UIViewController {
        return self
    }
    
    public func hasClearAvatarAction() -> Bool {
        return false;
    }
    
    func uploadImageAndNameToServer() {
        guard let localNumber = TSAccountManager.shared.localNumber() else {return}
        guard let signalAccount = account , let contact = signalAccount.contact else {
            return
        }
        let img : UIImage?
        if(self.iconImage == nil){
            img = nil
        } else {
            img = self.iconImage
        }
        
        let newName : String?
        if(nameTextfield.text?.stripped != nil && nameTextfield.text?.stripped != contact.fullName){
            newName = nameTextfield.text?.stripped
        } else {
            newName = contact.fullName.stripped
        }
        DTToastHelper.show()
        OWSProfileManager.shared().updateLocalProfileName(newName, avatarImage: img) {
            DTToastHelper.hide()
            self.databaseStorage.asyncWrite { wTransaction in
                let contactsManager = Environment.shared.contactsManager;
                let avatar = OWSProfileManager.shared().localAvatar()
                contact.avatar = avatar
                if let newName = newName, newName.count > 0 {
                    contact.fullName = newName
                }
                signalAccount.contact = contact
                contactsManager?.updateSignalAccount(withRecipientId: localNumber, withNewSignalAccount: signalAccount, with: wTransaction)
                self.cacheImageView.setImageWithContactAvatar(contact.avatar, recipientId: localNumber, displayName: contact.fullName ,completion: nil)
            } completion: {
                if(self.loginType == DTLoginModeTypeRegisterEmailFromLogin || self.loginType == DTLoginModeTypeRegisterPhoneNumberFromLogin){
                    if(self.passKeyManager.isPasskeySupported()){
                        self.showSetUpPasskeyController()
                    } else {
                        self.showHomeView()
                    }
                } else {
                    self.showHomeView()
                }
            }
        } failure: {
            DTToastHelper.hide()
            DTToastHelper.toast(withText: Localized("PROFILE_VIEW_ERROR_UPDATE_FAILED",
                                                            comment: "Action edit Profile") , in: self.view.window!, durationTime: 3, afterDelay: 1)
        }
    }
}

extension DTEditProfileController: UITextFieldDelegate {
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        let currentLength = textField.text?.count ?? 0 // 当前长度
        if (range.length + range.location > currentLength){
            return false
        }
        // 禁用启用按钮
        let newLength = currentLength + string.count - range.length // 加上输入的字符之后的长度
        return newLength <= kMaxRemarkNameLength
    }
    
    
    @objc
    public func textFieldDidChange(_ textField: UITextField) {
        guard let nextButton = nextButton else {return}
        if let string = textField.text , string.count > 0  {
            nextButton.isSelected = true
            nextButton.isUserInteractionEnabled = true
        } else {
            nextButton.isSelected = false
            nextButton.isUserInteractionEnabled = false
        }
        guard let contentText = textField.text else { return }
            if(contentText.count > kMaxRemarkNameLength){
                let startIndex = contentText.index(contentText.startIndex, offsetBy: 0)
                let endIndex = contentText.index(contentText.startIndex, offsetBy: 30)
                
                let range = startIndex ..< endIndex
                let rangeRange = contentText.rangeOfComposedCharacterSequences(for:range)
                let result = "\(contentText[rangeRange])"
                textField.text = result;
            }
    }
    
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        guard let nextButton = nextButton else {return}
        if let string = textField.text , string.count > 0{
            nextButton.isSelected = true
            nextButton.isUserInteractionEnabled = true
        } else {
            nextButton.isSelected = false
            nextButton.isUserInteractionEnabled = false
        }
    }
}



