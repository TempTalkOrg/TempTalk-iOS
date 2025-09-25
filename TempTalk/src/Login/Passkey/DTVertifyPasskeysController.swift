//
//  DTVertifyPasskeysController.swift
//  Signal
//
//  Created by hornet on 2023/7/17.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation

@objc
public class DTVertifyPasskeysController: OWSViewController {
    let titleLabel: UILabel = UILabel()
    
    let verfityIconImageView = UIImageView()
    let verfityDecLabel: UILabel = UILabel()
    var verfityButton = OWSFlatButton()
    var tryOtherLabel = UILabel()
    var user_id : String?
    var email : String?
    var phoneNumber : String?
    var loginType: DTLoginModeType = DTLoginModeTypeRegisterEmailFromLogin
    var signInFinishHandler : ((_ loginViaPassKey : Bool) -> Void)?
    
    @objc init(loginType: DTLoginModeType = DTLoginModeTypeLoginViaEmail, email: String?, phoneNumber: String?, userId: String?,callBackHandler:  @escaping (_ loginViaPassKey : Bool) -> Void) {
        self.loginType = loginType
        self.email = email
        self.user_id = userId
        self.phoneNumber = phoneNumber
        self.signInFinishHandler = callBackHandler
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        tryOtherLabel.isUserInteractionEnabled = true
    }
    
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupNav()
        setupUIPropety()
        setupUI()
        autolayout()
        refreshTheme()
    }
    
    private func setupUIPropety() {
        
        titleLabel.text = Localized("PASSKEYS_VERIFY_TITLE", comment: "passkeys for  verfity titleLabel")
        titleLabel.font = UIFont.systemFont(ofSize: 24)
        titleLabel.textAlignment = .center
        
        verfityIconImageView.image =  UIImage(named: "passkeys_verify")
        
        verfityDecLabel.text = Localized("PASSKEYS_VERIFY_DESC",comment: "Passkeys for verfityDecLabel")
        verfityDecLabel.font = UIFont.systemFont(ofSize: 14)
        verfityDecLabel.textAlignment = .center
        verfityDecLabel.numberOfLines = 0
        
        verfityButton = OWSFlatButton.button(title: Localized("PASSKEYS_VERIFY_TEXT",
                                                                     comment: "passkeys for verfityButton"),
                                               font: OWSFlatButton.orignalFontForHeight(16),
                                               titleColor: UIColor.white,
                                               backgroundColor: UIColor.ows_signalBrandBlue,
                                               target:self,
                                               selector: #selector(verfityButtonClick))
        
        tryOtherLabel.text = Localized("PASSKEYS_OTHER_WAY", comment: "passkeys for tryOtherLabel")
        tryOtherLabel.textColor = UIColor.color(rgbHex: 0x056FFA)
        tryOtherLabel.font = UIFont.systemFont(ofSize: 14)
        tryOtherLabel.textAlignment = .center
        tryOtherLabel.isUserInteractionEnabled = true
        
        let tap = UITapGestureRecognizer.init(target: self, action: #selector(tryOtherLabelClick))
        tryOtherLabel.addGestureRecognizer(tap)
    }
    
    func setupNav() {
        let backButton = UIButton()
        backButton.addTarget(self, action: #selector(backButtonClick), for: .touchUpInside)
        backButton.setImage(UIImage(named: "nav_back_arrow_new"), for: .normal)
        let item = UIBarButtonItem(customView: backButton)
        navigationItem.leftBarButtonItem = item
        
        if(self.loginType == DTLoginModeTypeLoginViaEmailByPasskeyAuth ||
           self.loginType == DTLoginModeTypeLoginViaPhoneByPasskeyAuth){
            return
        }
        
        let skipButton = UIButton()
        skipButton.setTitleColor(UIColor.color(rgbHex: 0x848E9C), for: .normal)
        skipButton.setTitle(Localized("NAV_SKIP",comment: "skip button"), for: .normal)
        skipButton.addTarget(self, action: #selector(skipButtonClick), for: .touchUpInside)
        let barSkipBarButtonItem = UIBarButtonItem.init(customView: skipButton)
        self.navigationItem.rightBarButtonItems = [barSkipBarButtonItem]
    }
    
    private func setupUI() {
        view.addSubview(titleLabel)
        view.addSubview(verfityIconImageView)
        view.addSubview(verfityDecLabel)
        view.addSubview(verfityButton)
        view.addSubview(tryOtherLabel)
    }
    
    private func autolayout() {
        
        titleLabel.autoPinEdge(toSuperviewSafeArea: .top, withInset: 36)
        titleLabel.autoHCenterInSuperview()
        titleLabel.autoPinEdge(.left, to: .left, of: view, withOffset: 20)
        titleLabel.autoPinEdge(.right, to: .right, of: view, withOffset: -20)
        
        verfityIconImageView.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: 34)
        verfityIconImageView.autoHCenterInSuperview()
        verfityIconImageView.autoSetDimensions(to: CGSize(width: 100, height: 50))
        
        verfityDecLabel.autoPinEdge(.top, to: .bottom, of: verfityIconImageView, withOffset: 24)
        verfityDecLabel.autoPinEdge(.left, to: .left, of: view, withOffset: 20)
        verfityDecLabel.autoPinEdge(.right, to: .right, of: view, withOffset: -20)
        verfityDecLabel.autoHCenterInSuperview()
        
        verfityButton.autoPinEdge(.top, to: .bottom, of: verfityDecLabel, withOffset: 44)
        verfityButton.autoPinEdge(.left, to: .left, of: view, withOffset: 20)
        verfityButton.autoPinEdge(.right, to: .right, of: view, withOffset: -20)
        verfityButton.autoSetDimension(.height, toSize: 48)

        tryOtherLabel.autoPinEdge(.top, to: .bottom, of: verfityButton, withOffset: 24)
        tryOtherLabel.autoHCenterInSuperview()
        tryOtherLabel.autoSetDimension(.height, toSize: 20)
    }
    
    private func refreshTheme() {
        view.backgroundColor = Theme.backgroundColor
        titleLabel.textColor = Theme.primaryTextColor
        verfityDecLabel.textColor = Theme.secondaryTextColor
    }
    public override func applyTheme() {
        super.applyTheme()
        self.refreshTheme()
    }
    
    @objc func verfityButtonClick() {
        guard let signInFinishHandler = self.signInFinishHandler else {
            Logger.info("signInFinishHandler 未实现")
            return
        }
        signInFinishHandler(true)
    }
    
    @objc func backButtonClick() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc func skipButtonClick() {
        loginViaVcode()
    }
    
    @objc func tryOtherLabelClick() {
        Logger.info("[login module] tryOtherLabelClick")
        loginViaVcode()
    }
    
    func loginViaVcode() {
        guard let signInFinishHandler = self.signInFinishHandler else {
            Logger.info("signInFinishHandler 未实现")
            return
        }
        signInFinishHandler(false)
    }
    
}
