//
//  DTToastHelper+Call.swift
//  TempTalk
//
//  Created by Ethan on 10/01/2025.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import TTServiceKit
import SVProgressHUD

extension DTToastHelper {
    
    static func showCallToast(_ toast: String) {
                
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard CurrentAppContext().isMainAppAndActive else {
                return
            }

            let window = OWSWindowManager.shared().getToastSuitableWindow()
            SVProgressHUD.setContainerView(window)
            DTToastHelper.toast(withText: toast, durationTime: 3) {
                SVProgressHUD.setContainerView(nil)
            }
        }
        
    }
    
    static func showCallLoading() {
        
        DispatchQueue.main.async {
            guard CurrentAppContext().isMainAppAndActive else {
                return
            }
            
            let window = OWSWindowManager.shared().getToastSuitableWindow()
            SVProgressHUD.setContainerView(window)
            SVProgressHUD.show()
        }
    }
    
    static func hideCallLoading() {
        
        DispatchQueue.main.async {
            guard CurrentAppContext().isMainAppAndActive else {
                return
            }
            
            DTToastHelper.dismiss(withDelay: 0.2) {
                SVProgressHUD.setContainerView(nil)
            }
        }
    }
    
}
