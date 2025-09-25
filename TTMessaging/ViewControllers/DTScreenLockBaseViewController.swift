//
//  DTScreenLockBaseViewController.swift
//  TTMessaging
//
//  Created by Kris.s on 2024/8/29.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

@objc
public class DTScreenLockBaseViewController: OWSViewController, UITextFieldDelegate {
    
    @objc public enum DTScreenLockViewType: Int {
        case setPasscode = 0
        case confirmPasscode = 1
        case passcodeSuccess = 2
        case unlockScreen = 3
    }
    
    let logoIconImageView = UIImageView()
    let titleLabel: UILabel = UILabel()
    let tipsLabel: UILabel = UILabel()
    let passcodeField: UITextField = UITextField()
    let lineView: UIView = UIView()
    let errorTipsLabel: UILabel = UILabel()
    var doneButton = OWSFlatButton()
    var doneCallback : ((String?) -> Void)?
    
    @objc
    public class func buildScreenLockView(viewType: DTScreenLockViewType, doneCallback:  @escaping (String?) -> Void) -> DTScreenLockBaseViewController {
        switch viewType {
        case .setPasscode:
            return DTSetPasscodeViewController(doneCallback: doneCallback)
        case .confirmPasscode:
            return DTConfirmPasscodeViewController(doneCallback: doneCallback)
        case .passcodeSuccess:
            return DTPasscodeSuccessViewController(doneCallback: doneCallback)
        case .unlockScreen:
            return DTUnlockScreenViewController(doneCallback: doneCallback)
        }
    }
    
    @objc public init(doneCallback:  @escaping (String?) -> Void) {
        self.doneCallback = doneCallback
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        
        passcodeField.becomeFirstResponder()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        passcodeField.resignFirstResponder()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupUIPropety()
        setupUI()
        autolayout()
        refreshTheme()
    }
    
    private func setupUIPropety() {
        
        titleLabel.text = Localized("UNLOCKSCREEN_TITLE", comment: "")
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20.0)
        titleLabel.textAlignment = .center
        
        tipsLabel.text = ""
        tipsLabel.font = UIFont.systemFont(ofSize: 14)
        tipsLabel.textAlignment = .center
        tipsLabel.numberOfLines = 0;
        
        logoIconImageView.image =  UIImage(named: "logo_chative")
        
        passcodeField.delegate = self;
        passcodeField.keyboardAppearance = Theme.keyboardAppearance;
        passcodeField.isSecureTextEntry = true
        passcodeField.keyboardType = .numberPad
        passcodeField.textAlignment = .center;
        passcodeField.font = .boldSystemFont(ofSize: 32.0);
        passcodeField.defaultTextAttributes.updateValue(8.0, forKey: .kern)
        
        errorTipsLabel.text = ""
        errorTipsLabel.font = UIFont.systemFont(ofSize: 12)
        errorTipsLabel.textAlignment = .center
        errorTipsLabel.textColor = UIColor.color(rgbHex: 0xF84135)
        errorTipsLabel.numberOfLines = 1;
        
        doneButton = OWSFlatButton.button(title: Localized("UNLOCKSCREEN_DONE", comment: ""),
                                          font: OWSFlatButton.orignalFontForHeight(16),
                                          titleColor: UIColor.white,
                                          backgroundColor: UIColor.ows_signalBrandBlue,
                                          target:self,
                                          selector: #selector(doneButtonClick))
        doneButton.setEnabled(false)
        
    }
    
    public func setupUI() {
        fatalError("Must Override setupUI")
    }
    
    public func autolayout() {
        fatalError("Must Override autolayout")
    }
    
    public override func applyTheme() {
        super.applyTheme()
        self.refreshTheme()
    }
    
    @objc public func doneButtonClick() {
        fatalError("Must Override doneButtonClick")
    }
    
    
    public func refreshTheme() {
        view.backgroundColor = Theme.backgroundColor
        titleLabel.textColor = Theme.primaryTextColor
        passcodeField.textColor = Theme.secondaryTextAndIconColor
        tipsLabel.textColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xB7BDC6) : UIColor.color(rgbHex: 0x474D57);
        lineView.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x474D57) : UIColor.color(rgbHex: 0xEAECEF);
    }
    
    
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let maxLength = 10
        let currentString = (textField.text ?? "") as NSString
        let newString = currentString.replacingCharacters(in: range, with: string)
        let inputEnable = newString.count <= maxLength
        return inputEnable
    }
    
    public func textFieldDidChangeSelection(_ textField: UITextField) {
        let currentString = textField.text ?? ""
        let doneEnable = currentString.count >= 4 && currentString.count <= 10
        doneButton.setEnabled(doneEnable)
        if doneEnable {
            self.autoSubmit()
        }
    }
    
    public func autoSubmit() {
        
    }
    
}
