//
//  DTMeetingManager+FloatingView.swift
//  TempTalk
//
//  Created by Ethan on 06/01/2025.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import TTMessaging

extension DTMeetingManager {
    
    private struct AssociatedKeys {
        static var floatingViewKey: Int8 = 0
        static var isMinimizeKey: Int8 = 1
    }

    var floatingView: DTFloatingView {
        get {
            if let value = objc_getAssociatedObject(self, &AssociatedKeys.floatingViewKey) as? DTFloatingView {
                
                return value
            }
            let newValue = DTFloatingView()
            newValue.floatViewAction = { [weak self] in
                guard let self else { return }
              
                isMinimize = false
                OWSWindowManager.shared().showCallView()
                newValue.removeFromSuperview()
                
                let callWindow = OWSWindowManager.shared().callViewWindow
                callAlertManager.bringLiveKitAlertCalls(to: callWindow)
                
                DispatchMainThreadSafe {
                    UIDevice.current.isProximityMonitoringEnabled = true
                }
                
                NotificationCenter.default.post(name: Notification.Name("CallShareZoomDidChange"), object: nil)
            }
            
            objc_setAssociatedObject(self, &AssociatedKeys.floatingViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            return newValue
        }
        
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.floatingViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    var isMinimize: Bool {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.isMinimizeKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.isMinimizeKey, newValue, .OBJC_ASSOCIATION_ASSIGN)
        }
    }
    
    func minimizeCallWindow() {
        isMinimize = true
        OWSWindowManager.shared().leaveCallView()
        OWSWindowManager.shared().showFloatingCall(self.floatingView)
        
        let rootWindow = OWSWindowManager.shared().rootWindow
        callAlertManager.bringLiveKitAlertCalls(to: rootWindow)
        
        DispatchMainThreadSafe {
            UIDevice.current.isProximityMonitoringEnabled = false
        }
        NotificationCenter.default.post(name: Notification.Name.DTRefreshJoinBarStatusChange, object: nil)
    }
    
    
}
