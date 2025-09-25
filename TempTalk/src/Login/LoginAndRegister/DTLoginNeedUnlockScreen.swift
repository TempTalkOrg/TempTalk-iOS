//
//  DTLoginNeedUnlockScreen.swift
//  Wea
//
//  Created by Kris.s on 2024/8/30.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

@objc
public class DTLoginNeedUnlockScreen: NSObject {
    
    public class func showErrorToast(processedVc: UIViewController) {
        DTToastHelper.toast(withText: "Sorry,encountered some problems!", in: processedVc.view, durationTime: 3.0, afterDelay: 0.2)
        Logger.error("transfer screenlock.passcodeSalt is empty!")
    }
    
    
    @objc
    public class func checkIfNeedScreenlock(vcode: String,
                                            screenlock: DTScreenLockEntity?,
                                            processedVc: UIViewController,
                                            completionCallback:  @escaping () -> Void,
                                            errorBlock:  @escaping (String) -> Void) {
        /*
        if let screenlock = screenlock,
            screenlock.requirePasscode {
            guard let passcodeSalt = screenlock.passcodeSalt else {
                showErrorToast(processedVc: processedVc)
                return
            }
            if passcodeSalt.isEmpty {
                showErrorToast(processedVc: processedVc)
                return
            }
            if screenlock.screenLockTimeout == nil {
                Logger.error("transfer screenLockTimeout is empty!");
            }
            
            
            let unlockScreenVc = DTScreenLockBaseViewController.buildScreenLockView(viewType: .unlockScreen) { passcode in
                register(vcode: vcode, pin:nil, passcode:passcode, screenlock: screenlock, processedVc: processedVc, completionCallback: completionCallback, errorBlock: errorBlock)
            }
            let unlockScreen = unlockScreenVc as! DTUnlockScreenViewController
            unlockScreen.salt = passcodeSalt
            unlockScreen.verifyToServer = true
            processedVc.navigationController?.pushViewController(unlockScreen, animated: true)
            DTToastHelper.hide()
        } else {
            register(vcode: vcode, pin:nil, passcode:nil, screenlock: nil, processedVc: processedVc, completionCallback: completionCallback, errorBlock: errorBlock)
        }
        */
        register(vcode: vcode, pin:nil, passcode:nil, screenlock: nil, processedVc: processedVc, completionCallback: completionCallback, errorBlock: errorBlock)
    }
    
    public class func register(vcode: String,
                               pin: String?,
                               passcode: String?,
                               screenlock: DTScreenLockEntity?,
                               processedVc: UIViewController,
                               completionCallback:  @escaping () -> Void,
                               errorBlock:  @escaping (String) -> Void){
        let accountManager = SignalApp.shared().accountManager
        DTToastHelper.show()
        
        accountManager.register(verificationCode: vcode, pin: pin, passcode: passcode).done { response in
            if let passcode = passcode, let screenLockTimeout = screenlock?.screenLockTimeout {
                if !passcode.isEmpty {
                    ScreenLock.shared.setScreenLockTimeout(TimeInterval(truncating: screenLockTimeout))
                    ScreenLock.shared.setPasscode(passcode)
                }
                processedVc.navigationController?.popToViewController(processedVc, animated: false, completion: nil)
            }
            completionCallback()
        }.catch { error in
            DTToastHelper.hide()
            var errorMessage  = ""
            if error.httpStatusCode == 413 {
                errorMessage = Localized("LOGIN_SUBIT_TOO_MANY_ATTEMPTS")
            } else if let screenlock = screenlock, screenlock.requirePasscode {
                errorMessage = Localized("SCREENLOCK_CONFIRMPASSCODE_ERROR_TIPS")
            } else {
                errorMessage = Localized("REGISTRATION_VERIFICATION_FAILED_TITLE")
            }
            DTToastHelper.toast(withText: errorMessage, durationTime: 2.0)
            
            Logger.error(errorMessage)
            errorBlock(errorMessage);
        }
    }
}
