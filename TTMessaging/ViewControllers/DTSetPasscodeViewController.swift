//
//  DTSetPasscodeViewController.swift
//  TTMessaging
//
//  Created by Kris.s on 2024/8/29.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

public class DTSetPasscodeViewController: DTScreenLockBaseViewController {
    
    let exclamationIcon = UIImageView()
    let exclamationLabel: UILabel = UILabel()
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: false)
        
        passcodeField.becomeFirstResponder()
    }
    
    public override func setupUI() {
        
        titleLabel.font = .boldSystemFont(ofSize: 24.0)
        tipsLabel.text = String(format: Localized("SCREENLOCK_SETPASSCODE_TIPS"), TSConstants.appDisplayName)
        doneButton.setTitle(title: Localized("SCREENLOCK_SETPASSCODE_NEXT", comment: ""), font: OWSFlatButton.orignalFontForHeight(16), titleColor: UIColor.white)
        exclamationIcon.image = UIImage(named: "passcode_exclamation-circle")
        exclamationLabel.font = UIFont.systemFont(ofSize: 14)
        exclamationLabel.numberOfLines = 0;
        exclamationLabel.text = Localized("SCREENLOCK_SETPASSCODE_EXCLAMATION")
        
        view.addSubview(titleLabel)
        view.addSubview(tipsLabel)
        view.addSubview(passcodeField)
        view.addSubview(lineView)
        view.addSubview(doneButton)
        view.addSubview(exclamationIcon)
        view.addSubview(exclamationLabel)
        
    }
    
    public override func refreshTheme() {
        super.refreshTheme()
        exclamationLabel.textColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xB7BDC6) : UIColor.color(rgbHex: 0x474D57);
    }
    
    public override func autolayout() {
        titleLabel.autoPinEdge(toSuperviewSafeArea: .top, withInset: 66)
        titleLabel.autoSetDimension(.height, toSize: 32.0)
        titleLabel.autoHCenterInSuperview()
        
        tipsLabel.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: 32)
        tipsLabel.autoPinEdge(.left, to: .left, of: view, withOffset: 60)
        tipsLabel.autoPinEdge(.right, to: .right, of: view, withOffset: -60)
        tipsLabel.autoHCenterInSuperview()
        
        passcodeField.autoPinEdge(.top, to: .bottom, of: tipsLabel, withOffset: 32)
        passcodeField.autoPinEdge(.left, to: .left, of: view, withOffset: 20)
        passcodeField.autoPinEdge(.right, to: .right, of: view, withOffset: -12)
        passcodeField.autoSetDimension(.height, toSize: 48.0)
        
        lineView.autoPinEdge(.top, to: .bottom, of: passcodeField, withOffset: 0)
        lineView.autoPinEdge(.left, to: .left, of: view, withOffset: 60)
        lineView.autoPinEdge(.right, to: .right, of: view, withOffset: -60)
        lineView.autoSetDimension(.height, toSize: 1.0/UIScreen.main.scale)
        lineView.autoHCenterInSuperview()
        
        doneButton.autoPinEdge(.top, to: .bottom, of: lineView, withOffset: 48)
        doneButton.autoPinEdge(.left, to: .left, of: view, withOffset: 24)
        doneButton.autoPinEdge(.right, to: .right, of: view, withOffset: -24)
        doneButton.autoSetDimension(.height, toSize: 48)
        
        exclamationIcon.autoPinEdge(.top, to: .bottom, of: doneButton, withOffset: 24)
        exclamationIcon.autoPinEdge(.left, to: .left, of: doneButton)
        exclamationIcon.autoSetDimension(.width, toSize: 16)
        exclamationIcon.autoSetDimension(.height, toSize: 20)
        
        exclamationLabel.autoPinEdge(.top, to: .top, of: exclamationIcon, withOffset: 2)
        exclamationLabel.autoPinEdge(.left, to: .right, of: exclamationIcon, withOffset: 8)
        exclamationLabel.autoPinEdge(.right, to: .right, of: doneButton)
    }
    
    @objc public override func doneButtonClick() {
        guard let doneCallback = self.doneCallback else {
            Logger.info("unlockSuccess method not implemented!")
            return
        }
        
        passcodeField.resignFirstResponder()
        
        if let passcode = self.passcodeField.text, passcode.count >= 4 && passcode.count <= 10 {
            doneCallback(self.passcodeField.text)
        } else {
            let alertController = UIAlertController(title: Localized("SCREENLOCK_CONFIRMPASSCODE_ERROR_TITLE", comment: ""),
                                                    message: Localized("Passcode length error!",
                                                                       comment: ""),
                                                    preferredStyle: .alert
            )
            let okAction = UIAlertAction(title: Localized("SCREENLOCK_CONFIRMPASSCODE_ERROR_OKBTN", comment: ""), style: .default)
            alertController.addAction(okAction)
            self.present(alertController, animated: true)
            
        }
    }
    
}
