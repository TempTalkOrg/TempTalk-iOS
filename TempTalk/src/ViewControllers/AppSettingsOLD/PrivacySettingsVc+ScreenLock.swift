//
//  PrivacySettingsVc+ScreenLock.swift
//  Signal
//
//  Created by Kris.s on 2024/8/29.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

@objc
public extension PrivacySettingsTableViewController {
    
    func screenLockEnabledChangeAction(sender: UISwitch) {
        let shouldBeEnabled = sender.isOn;
        if shouldBeEnabled == ScreenLock.shared.isScreenLockEnabled() {
            Logger.error("\(self.logTag) ignoring redundant screen lock.")
            return;
        }
        
        Logger.info("\(self.logTag) trying to set is screen lock enabled: \(shouldBeEnabled)")
        
        if shouldBeEnabled {
            let setPasscodeVc = DTScreenLockBaseViewController.buildScreenLockView(viewType: .setPasscode) { passcode in
                let confirmPasscodeVc = DTScreenLockBaseViewController.buildScreenLockView(viewType: .confirmPasscode) { verifiedPasscode in
                    //上报passcode
                    let screenLockTimeout = round(ScreenLock.shared.screenLockTimeout())
                    let screenlockCrypto = DTScreenLockCrypto()
                    
                    guard let verifiedPasscode = verifiedPasscode else{
                        Logger.error("verifiedPasscode is empty!")
                        return
                    }
                    
                    guard let passcodeHash = screenlockCrypto.hashPasscode(passcode: verifiedPasscode) else{
                        DTToastHelper.toast(withText: "Sorry,encountered some problems!", in: self.view, durationTime: 3.0, afterDelay: 0.2)
                        Logger.error("passcodeHash is empty!")
                        return
                    }
                    
                    DTToastHelper.show()
                    let setPasscodeApi = DTScreenLockSetPasscodeApi()
                    setPasscodeApi.sendSetPasscodeRequest(passcode: passcodeHash,
                                                          screenLockTimeout: screenLockTimeout) {_ in
                        DTToastHelper.hide()
                        ScreenLock.shared.setPasscode(passcodeHash)
                        self.navigationController?.popToViewController(self, animated: false)
                        let passcodeSuccessVc = DTScreenLockBaseViewController.buildScreenLockView(viewType: .passcodeSuccess) { _ in
                            self.navigationController?.popToViewController(self, animated: false)
                        }
                        self.navigationController?.pushViewController(passcodeSuccessVc, animated: true)
                        
                    } failure: { error in
                        DTToastHelper.hide()
                        DTToastHelper.toast(withText: error.localizedDescription, in: self.view, durationTime: 3.0, afterDelay: 0.2)
                    }
                    
                }
                let confirmPasscode = confirmPasscodeVc as! DTConfirmPasscodeViewController
                confirmPasscode.verifiedPasscode = passcode ?? ""
                self.navigationController?.pushViewController(confirmPasscodeVc, animated: false)
            }
            
            self.navigationController?.pushViewController(setPasscodeVc, animated: false)
            
        } else {
            DTToastHelper.show()
            let deletePasscodeApi = DTScreenLockDeletePasscodeApi();
            deletePasscodeApi.sendDeletePasscodeRequest { _ in
                DTToastHelper.hide()
                ScreenLock.shared.removePasscode()
            } failure: { error in
                DTToastHelper.hide()
                DTToastHelper.toast(withText: error.localizedDescription, in: self.view, durationTime: 3.0, afterDelay: 0.2)
                sender.isOn = true
            }
        }
    }
}
    
