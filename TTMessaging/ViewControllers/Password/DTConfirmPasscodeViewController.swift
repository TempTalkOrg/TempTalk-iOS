//
//  DTConfirmPasscodeViewController.swift
//  TTMessaging
//
//  Created by Kris.s on 2024/8/29.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

public class DTConfirmPasscodeViewController: DTSetPasscodeViewController {
    
    @objc
    public var verifiedPasscode = ""
    
    public override func setupUI() {
        super.setupUI()
        tipsLabel.text = Localized("SCREENLOCK_CONFIRMPASSCODE_TIPS", comment: "")
        doneButton.setTitle(title: Localized("SCREENLOCK_CONFIRMPASSCODE_CONFIRM", comment: ""), font: OWSFlatButton.orignalFontForHeight(16), titleColor: UIColor.white)
    }
    
    public override func doneButtonClick() {
        guard let doneCallback = self.doneCallback else {
            Logger.info("unlockSuccess method not implemented!")
            return
        }
        
        if let passcode = self.passcodeField.text, passcode.count >= 4 && passcode.count <= 10 {
            if verifiedPasscode == passcodeField.text {
                passcodeField.resignFirstResponder()
                doneCallback(verifiedPasscode)
            } else {
                
                let alertController = UIAlertController(title: Localized("SCREENLOCK_CONFIRMPASSCODE_ERROR_TITLE", comment: ""),
                                                        message: Localized("SCREENLOCK_CONFIRMPASSCODE_ERROR_TIPS",
                                                                           comment: ""),
                                                        preferredStyle: .alert
                )
                let okAction = UIAlertAction(title: Localized("SCREENLOCK_CONFIRMPASSCODE_ERROR_OKBTN", comment: ""), style: .default)
                alertController.addAction(okAction)
                self.present(alertController, animated: true)
                
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
    
}
