//
//  DTSetUpPasskeys.swift
//  Signal
//
//  Created by hornet on 2023/7/17.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation

@objc
public class DTSetUpPasskeysController: OWSViewController {
    let titleLabel: UILabel = UILabel.init()
    
    let safeIconImageView = UIImageView()
    let safeTipLabel: UILabel = UILabel.init()
    let safeDecLabel: UILabel = UILabel.init()
    
    let passwordLessIconImageView = UIImageView()
    let passwordLessLabel = UILabel.init()
    let passwordLessDecLabel = UILabel.init()
    var setupButton = OWSFlatButton()
    let profileInfoApi = DTProfileInfoApi()
    @objc public var email : String?
    @objc public var phoneNumber : String?
    @objc public var loginType: DTLoginModeType = DTLoginModeTypeRegisterEmailFromLogin
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupNav()
        setupUIPropety()
        setupUI()
        autolayout()
        refreshTheme()
    }
    
    private func setupUIPropety() {
        titleLabel.text = Localized("PASSKEYS_SET_UP_TITLE", comment: "Action edit Profile")
        titleLabel.font = UIFont.systemFont(ofSize: 24)
        titleLabel.textAlignment = .center
        
        safeIconImageView.image =  UIImage(named: "tabler_safety_icon")
        safeTipLabel.text = Localized("PASSKEYS_SAFE_TITLE",comment: "Passkeys for safeTipLabel")
        safeTipLabel.font = UIFont.systemFont(ofSize: 16)
        safeTipLabel.textAlignment = .left
        
        safeDecLabel.text = Localized("PASSKEYS_SAFE_DESC",comment: "Passkeys for safeDecLabel")
        safeDecLabel.font = UIFont.systemFont(ofSize: 14)
        safeDecLabel.textAlignment = .left
        safeDecLabel.numberOfLines = 0
        
        passwordLessIconImageView.image = UIImage(named: "tabler_face_icon")
        passwordLessLabel.text = Localized("PASSKEYS_PASSWORDLESS_TITLE",comment: "Passkeys for passwordLessLabel")
        passwordLessLabel.font = UIFont.systemFont(ofSize: 16)
        passwordLessLabel.textAlignment = .left
        
        passwordLessDecLabel.text = Localized("PASSKEYS_PASSWORDLESS_DESC",comment: "Passkeys for passwordLessDecLabel")
        passwordLessDecLabel.font = UIFont.systemFont(ofSize: 14)
        passwordLessDecLabel.textAlignment = .left
        passwordLessDecLabel.numberOfLines = 0
        
        setupButton = OWSFlatButton.button(title: Localized("PASSKEYS_SET_UP_TITLE",
                                                                    comment: "Action edit Profile"),
                                           font: OWSFlatButton.orignalFontForHeight(16),
                                           titleColor: UIColor.white,
                                           backgroundColor: UIColor.ows_signalBrandBlue,
                                           target:self,
                                           selector: #selector(setupButtonClick))
    }
    
    func setupNav() {
        if self.loginType != DTLoginModeTypeViaRegisterPasskeyAuthFromMe {
            let backButton = UIButton()
            backButton.addTarget(self, action: #selector(backButtonClick), for: .touchUpInside)
            backButton.setImage(UIImage(named: "nav_back_arrow_new"), for: .normal)
            let item = UIBarButtonItem(customView: backButton)
            navigationItem.leftBarButtonItem = item
            
            let skipButton = UIButton()
            skipButton.setTitleColor(UIColor.color(rgbHex: 0x848E9C), for: .normal)
            skipButton.setTitle(Localized("NAV_SKIP",comment: "skip button"), for: .normal)
            skipButton.addTarget(self, action: #selector(skipButtonClick), for: .touchUpInside)
            let barSkipBarButtonItem = UIBarButtonItem.init(customView: skipButton)
            self.navigationItem.rightBarButtonItems = [barSkipBarButtonItem]
        }
    }
    
    private func setupUI() {
        view.addSubview(titleLabel)
        
        view.addSubview(safeIconImageView)
        view.addSubview(safeTipLabel)
        view.addSubview(safeDecLabel)
        
        view.addSubview(passwordLessIconImageView)
        view.addSubview(passwordLessLabel)
        view.addSubview(passwordLessDecLabel)
        
        view.addSubview(setupButton)
        
    }
    
    private func autolayout() {
        titleLabel.autoPinEdge(toSuperviewSafeArea: .top, withInset: 36)
        titleLabel.autoHCenterInSuperview()
        titleLabel.autoSetDimension(.width, toSize: 185)
        titleLabel.autoSetDimension(.height, toSize: 32)
        
        safeIconImageView.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: 32)
        safeIconImageView.autoPinEdge(.left, to: .left, of: view, withOffset: 20)
        safeIconImageView.autoSetDimensions(to: CGSize(width: 20, height: 20))
        
        safeTipLabel.autoPinEdge(.top, to: .top, of: safeIconImageView, withOffset: 0)
        safeTipLabel.autoPinEdge(.left, to: .right, of: safeIconImageView, withOffset: 8)
        safeTipLabel.autoPinEdge(.right, to: .right, of: view, withOffset: -20)
        safeTipLabel.autoSetDimension(.height, toSize: 20)
        
        safeDecLabel.autoPinEdge(.top, to: .bottom, of: safeTipLabel, withOffset: 0)
        safeDecLabel.autoPinEdge(.left, to: .left, of: safeTipLabel, withOffset: 0)
        safeDecLabel.autoPinEdge(.right, to: .right, of: view, withOffset: -20)
        
        passwordLessIconImageView.autoPinEdge(.top, to: .bottom, of: safeDecLabel, withOffset: 32)
        passwordLessIconImageView.autoPinEdge(.left, to: .left, of: view, withOffset: 20)
        passwordLessIconImageView.autoSetDimensions(to: CGSize(width: 20, height: 20))
        
        passwordLessLabel.autoPinEdge(.top, to: .top, of: passwordLessIconImageView, withOffset: 0)
        passwordLessLabel.autoPinEdge(.left, to: .right, of: passwordLessIconImageView, withOffset: 8)
        passwordLessLabel.autoPinEdge(.right, to: .right, of: view, withOffset: -20)
        passwordLessLabel.autoSetDimension(.height, toSize: 20)
        
        passwordLessDecLabel.autoPinEdge(.top, to: .bottom, of: passwordLessLabel, withOffset: 0)
        passwordLessDecLabel.autoPinEdge(.left, to: .left, of: passwordLessLabel, withOffset: 0)
        passwordLessDecLabel.autoPinEdge(.right, to: .right, of: view, withOffset: -20)
        
        setupButton.autoPinEdge(.top, to: .bottom, of: passwordLessDecLabel, withOffset: 32)
        setupButton.autoPinEdge(.left, to: .left, of: view, withOffset: 20)
        setupButton.autoPinEdge(.right, to: .right, of: view, withOffset: -20)
        setupButton.autoSetDimension(.height, toSize: 48)
        
    }
    
    private func refreshTheme() {
        view.backgroundColor = Theme.backgroundColor
        titleLabel.textColor = Theme.primaryTextColor
        safeTipLabel.textColor = Theme.primaryTextColor
        safeDecLabel.textColor = Theme.secondaryTextColor
        passwordLessLabel.textColor = Theme.primaryTextColor
        passwordLessDecLabel.textColor = Theme.secondaryTextColor
    }
    public override func applyTheme() {
        super.applyTheme()
        refreshTheme()
    }
    
    @objc func setupButtonClick() {
        let keyWindow = OWSWindowManager.shared().rootWindow;
        self.databaseStorage.asyncRead { transaction in
            guard let localNum = TSAccountManager.sharedInstance().localNumber() else {return}
            
            let contactsManager = Environment.shared.contactsManager;
            let account = contactsManager?.signalAccount(forRecipientId: localNum, transaction: transaction)
            
            var userName = account?.contact?.fullName
            if(!DTParamsUtils.validateString(userName).boolValue){
                userName = localNum;
            }
            
            if #available(iOS 16.0, *) {
                TSAccountManager.shared.passKeyManager.signUpWith(userName: userName!, anchor: keyWindow) { error in
                    guard error == nil else {
                        Logger.info("DTSetUpPasskeysController signUp error")
                        if let errorMessage = error?.localizedDescription{
                            DTToastHelper.toast(withText: errorMessage)
                        }
                        return
                    }
                    self.presentNextPage()
                }
            } else {
                Logger.info("DTSetUpPasskeysController oS version error")
            }
        }
    }
    
    @objc func backButtonClick() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc func skipButtonClick() {
        self.presentNextPage()
    }
    
    
    func cachePrivateSettingInKeyChain(passkeysSwitch: UInt, key: String) {
        DTTokenKeychainStore.setPassword("\(passkeysSwitch)", forAccount: key)
    }
    
    func presentNextPage() {
        if (self.loginType == DTLoginModeTypeLoginViaEmail ||
                   self.loginType == DTLoginModeTypeLoginViaPhone ||
                   self.loginType == DTLoginModeTypeRegisterEmailFromLogin ||
                   self.loginType == DTLoginModeTypeRegisterPhoneNumberFromLogin){
            //            self.navigationController?.popViewController(animated: true)
            //TODO: 到首页
            let appDelegate = UIApplication.shared.delegate as? AppDelegate;
            appDelegate?.switchToTabbarVC(fromRegistration: true)
        } else if (self.loginType == DTLoginModeTypeViaRegisterPasskeyAuthFromMe){
            self.navigationController?.popViewController(animated: true)
        } else {
            
        }
    }
}
