//
//  DTUnlockScreenViewController.swift
//  TTMessaging
//
//  Created by Kris.s on 2024/8/29.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

public class DTUnlockScreenViewController: DTScreenLockBaseViewController {
    
    @objc public var salt = ""
    @objc public var verifyToServer = false
    
    let forgotBtn: UIButton = UIButton(type: .custom)
    
    let attemptsThreshold = 5

    public override func setupUI() {
        
        view.addSubview(logoIconImageView)
        view.addSubview(titleLabel)
        view.addSubview(passcodeField)
        view.addSubview(lineView)
        view.addSubview(errorTipsLabel)
        let attempts = ScreenLock.shared.attempts()
        if attempts >= attemptsThreshold {
            self.showNextTime(nextAttempts: attempts)
        } else {
            self.errorTipsLabel.isHidden = true
        }
        
        view.addSubview(doneButton)
        
        forgotBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        forgotBtn.setTitleColor(UIColor.ows_gray45, for: .normal)
        forgotBtn.setTitle(Localized("SCREENLOCK_SETPASSCODE_FORGOT_TIPS"), for: .normal)
        forgotBtn.addTarget(self, action: #selector(forgotAction), for: .touchUpInside)
        
        view.addSubview(forgotBtn)
    }
    
    public override func autolayout() {
        
        logoIconImageView.autoPinEdge(toSuperviewSafeArea: .top, withInset: 88)
        logoIconImageView.autoSetDimensions(to: CGSize(width: 160, height: 160))
        logoIconImageView.autoHCenterInSuperview()
        
        titleLabel.autoPinEdge(.top, to: .bottom, of: logoIconImageView, withOffset: 10)
        titleLabel.autoSetDimension(.height, toSize: 28.0)
        titleLabel.autoHCenterInSuperview()
        
        passcodeField.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: 24)
        passcodeField.autoPinEdge(.left, to: .left, of: view, withOffset: 20)
        passcodeField.autoPinEdge(.right, to: .right, of: view, withOffset: -12)
        passcodeField.autoSetDimension(.height, toSize: 30.0)
        
        lineView.autoPinEdge(.top, to: .bottom, of: passcodeField, withOffset: 0)
        lineView.autoPinEdge(.left, to: .left, of: view, withOffset: 60)
        lineView.autoPinEdge(.right, to: .right, of: view, withOffset: -60)
        lineView.autoSetDimension(.height, toSize: 1.0/UIScreen.main.scale)
        lineView.autoHCenterInSuperview()
        
        errorTipsLabel.autoPinEdge(.top, to: .bottom, of: lineView, withOffset: 0)
        errorTipsLabel.autoPinEdge(.left, to: .left, of: view, withOffset: 60)
        errorTipsLabel.autoPinEdge(.right, to: .right, of: view, withOffset: -60)
        errorTipsLabel.autoSetDimension(.height, toSize: 31.0)
        errorTipsLabel.autoHCenterInSuperview()
        
        doneButton.autoPinEdge(.top, to: .bottom, of: errorTipsLabel, withOffset: 16)
        doneButton.autoPinEdge(.left, to: .left, of: view, withOffset: 20)
        doneButton.autoPinEdge(.right, to: .right, of: view, withOffset: -20)
        doneButton.autoSetDimension(.height, toSize: 48)
        
        forgotBtn.autoPinEdge(.top, to: .bottom, of: doneButton, withOffset: 12)
        forgotBtn.autoHCenterInSuperview()
        forgotBtn.autoSetDimension(.height, toSize: 20)
        forgotBtn.autoSetDimension(.width, toSize: 118)
    }
    
    @objc private func forgotAction() {
        let alertVC = UIAlertController(
            title: Localized("SCREENLOCK_SETPASSCODE_FORGOT_TIPS"),
            message: Localized("SCREENLOCK_SETPASSCODE_FORGOT_Alert_CONTENT"),
            preferredStyle: .alert
        )
        let confirmAction = UIAlertAction(title: Localized("SCREENLOCK_SETPASSCODE_FORGOT_Alert_OK"), style: .default)
        alertVC.addAction(confirmAction)
        present(alertVC, animated: true)
    }
    
    private func showNextTime(nextAttempts: Int) {
        //显示下一次的预计时间
        let nextDelay = (nextAttempts - 4) * (nextAttempts - 4)
        errorTipsLabel.text = String(format: Localized("SCREENLOCK_PASSCODESUCCESS_ATTEMPTS"), nextDelay)
        errorTipsLabel.isHidden = false
    }
    
    private func checkShowLoadingView(completion: @escaping () -> Bool) {
        let attempts = ScreenLock.shared.attempts()
        let nextAttempts = attempts + 1
        
        if attempts >= attemptsThreshold - 1 {
            //本次等待时间
            let delay = (attempts - 4) * (attempts - 4)
            if attempts >= attemptsThreshold {
                DTToastHelper.showHud(in: self.view)
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(delay)){
                    DTToastHelper.hide()
                    if !completion() {
                        self.showNextTime(nextAttempts: nextAttempts)
                    } else {
                        self.errorTipsLabel.isHidden = true
                    }
                }
            } else {
                if !completion() {
                    self.showNextTime(nextAttempts: nextAttempts)
                } else {
                    self.errorTipsLabel.isHidden = true
                }
            }
        } else {
            self.errorTipsLabel.isHidden = true
            if !completion() {
                //do nothing!
            }
        }
    }
    
    @objc public override func doneButtonClick() {
        guard let doneCallback = self.doneCallback else {
            Logger.info("unlockSuccess method not implemented!")
            return
        }
        
        if let passcode = self.passcodeField.text, passcode.count >= 4 && passcode.count <= 10 {
            let targetHash = ScreenLock.shared.passcode()
            let screenlockCrypto = DTScreenLockCrypto()
            if !verifyToServer {
                self.checkShowLoadingView {
                    let result = screenlockCrypto.verifyPasscode(passcode: passcode, targetHash: targetHash)
                    if result {
                        self.passcodeField.resignFirstResponder()
                        doneCallback(passcode)
                        ScreenLock.shared.clearAttempts()
                        return true
                    } else {
                        let alertController = UIAlertController(title: Localized("SCREENLOCK_CONFIRMPASSCODE_ERROR_TITLE", comment: ""),
                                                                message: Localized("SCREENLOCK_CONFIRMPASSCODE_ERROR_TIPS",
                                                                                   comment: ""),
                                                                preferredStyle: .alert
                        )
                        let okAction = UIAlertAction(title: Localized("SCREENLOCK_CONFIRMPASSCODE_ERROR_OKBTN", comment: ""), style: .default)
                        alertController.addAction(okAction)
                        self.present(alertController, animated: true)
                        self.passcodeField.text = ""
                        ScreenLock.shared.increaseAttempts()
                        return false
                    }
                }
            } else {
                
                if(salt.isEmpty){
                    DTToastHelper.toast(withText: "Sorry,encountered some problems!", in: self.view, durationTime: 3.0, afterDelay: 0.2)
                    Logger.error(" DTUnlockScreenViewController salt is empty!")
                    return
                }
                
                guard let passcodeHash = screenlockCrypto.hashPasscode(passcode: passcode, salt: salt) else{
                    DTToastHelper.toast(withText: "Sorry,encountered some problems!", in: self.view, durationTime: 3.0, afterDelay: 0.2)
                    Logger.error(" DTUnlockScreenViewController passcodeHash is empty!")
                    return
                }
                
                passcodeField.resignFirstResponder()
                doneCallback(passcodeHash)
                
            }
            
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
    
    public override func autoSubmit() {
        
        guard let doneCallback = self.doneCallback else {
            Logger.info("unlockSuccess method not implemented!")
            return
        }
        
        //大于等于阈值不走自动验证逻辑
        let attempts = ScreenLock.shared.attempts()
        if attempts >= attemptsThreshold {
            return
        }
        
        if let passcode = self.passcodeField.text, passcode.count >= 4 && passcode.count <= 10 {
            let targetHash = ScreenLock.shared.passcode()
            let screenlockCrypto = DTScreenLockCrypto()
            if !verifyToServer {
                let result = screenlockCrypto.verifyPasscode(passcode: passcode, targetHash: targetHash)
                if result {
                    passcodeField.resignFirstResponder()
                    doneCallback(passcode)
                    ScreenLock.shared.clearAttempts()
                }
            }
            
        }
    }
    
}
