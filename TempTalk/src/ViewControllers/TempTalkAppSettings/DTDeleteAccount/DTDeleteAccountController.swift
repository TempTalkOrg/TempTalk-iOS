//
//  DTDeleteAccountController.swift
//  Signal
//
//  Created by hornet on 2023/6/26.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
import UIKit
import TTMessaging
import JSQMessagesViewController


//删除账号
@objc
class DTDeleteAccountController: OWSViewController {
    
    private let margin : CGFloat = 16
    
    public lazy var backButton: UIButton = {
        let backButton = UIButton.init()
        backButton.addTarget(self, action: #selector(backButtonClick), for: .touchUpInside)
        backButton.setImage(UIImage(named: "nav_back_arrow_new"), for: .normal)
        return backButton
    }()
    
    private var confirmString: String?
    
    let deleteApi = DTDeleteAccountApi()

    private lazy var leftTitleLabel: UILabel = {
        let leftTitleLabel = UILabel.init()
        leftTitleLabel.font = UIFont.systemFont(ofSize: 20 ,weight: .bold)
        leftTitleLabel.textColor = Theme.primaryTextColor
        leftTitleLabel.textAlignment = .left
        leftTitleLabel.numberOfLines = 1
        return leftTitleLabel
    }()

    private lazy var topTipLabel: UILabel = {
        let tipLabel = UILabel.init()
        tipLabel.font = UIFont.systemFont(ofSize: 14)
        tipLabel.textColor = Theme.primaryTextColor
        tipLabel.text = Localized("PROFILE_STATUS_DELETE_ACCOUNT_TOP_TIP",comment: "Profile name tip")
        tipLabel.textAlignment = .left
        tipLabel.numberOfLines = 0
        return tipLabel
    }()
    
    private lazy var confirmTipLabel: UILabel = {
        
        let tipLabel = UILabel.init()
        tipLabel.font = UIFont.systemFont(ofSize: 14)
        tipLabel.textColor = Theme.primaryTextColor
        tipLabel.textAlignment = .left
        tipLabel.numberOfLines = 0
        return tipLabel
    }()
    
    
    lazy var infoTextfield: DTTextField = {
        let infoTextfield = DTTextField()
        infoTextfield.delegate = self
        infoTextfield.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        infoTextfield.becomeFirstResponder()
        infoTextfield.textContentType = nil
        infoTextfield.layer.borderWidth = 1
        infoTextfield.layer.cornerRadius = 8
        infoTextfield.clearButtonMode = .whileEditing
        infoTextfield.textColor = Theme.primaryTextColor
        return infoTextfield
    }()
     
    private lazy var nextButton: OWSFlatButton = {
        let nextButton = OWSFlatButton.button(title: Localized("PROFILE_VIEW_DELETE_BUTTON",
                                                               comment: "Action edit Profile"), font: OWSFlatButton.orignalFontForHeight(16), titleColor: UIColor.white, backgroundColor: UIColor.ows_themeBlue, target: self, selector: #selector(nextButtonClick))
        return nextButton
    }()
    
     public override func viewDidLoad() {
         super.viewDidLoad()
         setupNav()
         configUI()
         configUILayout()
         configProperty()
         configTheme()
    }
    
    func configUI() {
        view.backgroundColor = Theme.backgroundColor
        view.addSubview(topTipLabel)
        view.addSubview(confirmTipLabel)
        view.addSubview(infoTextfield)
        view.addSubview(nextButton)
    }
    
    func configUILayout() {
        topTipLabel.autoPinEdge(toSuperviewSafeArea: .top ,withInset: 12)
        topTipLabel.autoPinEdge(.left, to: .left, of: view, withOffset: margin)
        topTipLabel.autoPinEdge(.right, to: .right, of: view, withOffset: -margin)
        
        confirmTipLabel.autoPinEdge(.top, to: .bottom, of: topTipLabel, withOffset: 12)
        confirmTipLabel.autoPinEdge(.left, to: .left, of: view, withOffset: margin)
        confirmTipLabel.autoPinEdge(.right, to: .right, of: view, withOffset: -margin)
        
        infoTextfield.autoPinEdge(.top, to: .bottom, of: confirmTipLabel, withOffset: margin)
        infoTextfield.autoPinEdge(.left, to: .left, of: view, withOffset: margin)
        infoTextfield.autoPinEdge(.right, to: .right, of: view, withOffset: -margin)
        infoTextfield.autoSetDimension(.height, toSize: 48)
        
        nextButton.autoPinEdge(.top, to: .bottom, of: infoTextfield, withOffset: margin)
        nextButton.autoPinEdge(.left, to: .left, of: infoTextfield, withOffset: 0)
        nextButton.autoPinEdge(.right, to: .right, of: infoTextfield, withOffset: 0)
        nextButton.autoSetDimension(.height, toSize: 48)
    }
    
    override func applyTheme() {
        super.applyTheme()
        configTheme()
    }
    
    func configTheme() {
        infoTextfield.layer.borderColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x474D57).cgColor : UIColor.color(rgbHex: 0xEAECEF).cgColor
        nextButton.setTitleColor(UIColor.color(rgbHex: 0xFFFFFF), for: .selected)
        nextButton.setTitleColor(Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x5E6673) : UIColor.color(rgbHex: 0xB7BDC6), for: .normal)
        nextButton.setBackgroundColor(UIColor.color(rgbHex: 0x056FFA), for: .selected)
        nextButton.setBackgroundColor(Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x474D57) : UIColor.color(rgbHex: 0xEAECEF), for: .normal)
    }
    
    func setupNav() {
        self.leftTitleLabel.text = Localized("PROFILE_STATUS_DELETE_ACCOUNT",
                                           comment: "Action delete account")
        
        
        let backItem = UIBarButtonItem.init(customView: self.backButton)
        let leftTitleItem = UIBarButtonItem.init(customView: self.leftTitleLabel)
        self.navigationItem.leftBarButtonItems = [backItem,leftTitleItem]
    }
    
    func configProperty() {
        nextButton.isSelected = false
        nextButton.isUserInteractionEnabled = false
        
        var localNumber: String?
        self.databaseStorage.asyncRead { transaction in
            localNumber = self.tsAccountManager.localNumber(with: transaction)
        } completion: {
            if let localNumber = localNumber {
                let base58LocalNumber = NSString.base58EncodedString(localNumber)
                
                var ensureString = base58LocalNumber
                if base58LocalNumber.count > 6 {
                    ensureString = base58LocalNumber.substring(from: base58LocalNumber.count - 6)
                }
                self.confirmString = ensureString
                let tipLabelText = String(format: Localized("PROFILE_STATUS_DELETE_ACCOUNT_CONFIRM_TIP", comment: ""), ensureString)
                self.confirmTipLabel.text = tipLabelText
            }
        }
    }
    
    @objc func backButtonClick() {
        self.navigationController?.popViewController(animated: true)
    }
    
    @objc func nextButtonClick() {
        showDeleteAlert()
    }
    
    func showDeleteAlert() {
        let isRegistered = TSAccountManager.shared.isRegistered()
        let alertController = UIAlertController(title: Localized("CONFIRM_ACCOUNT_DELETE_TITLE",comment: "alert title logout"), message: Localized("CONFIRM_ACCOUNT_DELETE_DESC",comment: "alert logout desc"), preferredStyle: .alert)
        alertController.addAction(OWSAlerts.cancelAction)
        alertController.addAction(UIAlertAction(title: Localized("CONFIRM_ACCOUNT_ACTION_DELETE_ACCOUNT",comment: "Action logout desc"), style: .destructive,handler: {[weak self] _ in
            guard let self = self else { return  }
            DTToastHelper.showHud(in: self.view)
            self.deleteApi.deleteRequest{ entity in
                DTToastHelper.hide()
                SignalApp.resetAppData()
            } failure: { error, entity in
                DTToastHelper.hide()
                let errorMessage = NSError.errorDesc(error, errResponse: entity)
                DTToastHelper._showError(errorMessage)
            }
            
        }))
        if(isRegistered){
            self.present(alertController, animated: true)
        } else {
            let alertController = UIAlertController(title: Localized("",comment: "alert title logout"), message: Localized("STATUS_PLEASE_LOGIN",comment: "alert logout desc"), preferredStyle: .alert)
            alertController.addAction(OWSAlerts.okAction)
            alertController.addAction(UIAlertAction(title: Localized("CONFIRM_ACCOUNT_ACTION_DELETE_ACCOUNT",comment: "Action logout desc"), style: .destructive,handler: { [weak self]_ in
                ///跳到首页
                guard let self = self else { return  }
                RegistrationUtils.showReregistrationUI(from: self)

            }))
            self.present(alertController, animated: true)
        }
    }
    
    private func isConfirmStringCorrect(inputString: String) -> Bool {
        guard let confirmString = confirmString else { return false }
        
        return inputString == confirmString
    }
}

extension DTDeleteAccountController: UITextFieldDelegate {
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
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        checkNextButtonState(typeingTextFiled: textField, nextButton: nextButton)
    }
    
    func checkNextButtonState(typeingTextFiled textField: UITextField, nextButton: OWSFlatButton) {
        
        if textField == self.infoTextfield,
           let string = textField.text, !string.isEmpty,
           isConfirmStringCorrect(inputString: string) == true {
            nextButton.isSelected = true
            nextButton.isUserInteractionEnabled = true
        } else {
            nextButton.isSelected = false
            nextButton.isUserInteractionEnabled = false
        }
    }
}



