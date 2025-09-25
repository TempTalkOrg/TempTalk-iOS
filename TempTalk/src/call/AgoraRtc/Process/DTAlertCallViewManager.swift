//
//  DTAlertCallViewManager.swift
//  TempTalk
//
//  Created by Ethan on 20/01/2025.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import TTServiceKit
import TTMessaging

extension DTAlertCallViewManager {
        
    private struct AssociatedKeys {
        static var lkAlertCallsKey: Int8 = 0
    }
    
    @objc var lkAlertCalls: [DTAlertCallModel] {
        get {
            if let value = objc_getAssociatedObject(self, &AssociatedKeys.lkAlertCallsKey) as? [DTAlertCallModel] {
                
                return value
            }
            
            return [DTAlertCallModel]()
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.lkAlertCallsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    func addLiveKitCallAlert(_ call: DTLiveKitCallModel) {
        
        guard let roomId = call.roomId else {
            return
        }
        
        let roomIds = lkAlertCalls.compactMap { $0.liveKitCall?.roomId }
        guard !roomIds.contains(roomId) else {
            return
        }
        
        Logger.info("\(logTag) add call")
        
        DispatchMainThreadSafe { [self] in
            let rootWindow = OWSWindowManager.shared().getToastSuitableWindow()
            
            let callAlertView = DTAlertCallView()
            callAlertView.delegate = self
            callAlertView.configLiveKitAlertCall(call)
            rootWindow.addSubview(callAlertView)
            
            callAlertView.autoHCenterInSuperview()
            callAlertView.autoPinTopToSuperviewMargin()
            callAlertView.autoSetDimension(.height, toSize: 131)
            callAlertView.autoSetDimension(.width, toSize: min(screenHeight, screenWidth) - 16)
            
            let timer = Timer.weakScheduledTimer(
                withTimeInterval: 60,
                target: self,
                selector: #selector(removeTimerAction),
                userInfo: ["roomId": roomId],
                repeats: false
            )
            
            let callAlert = DTAlertCallModel()
            callAlert.liveKitCall = call
            callAlert.callTimer = timer
            callAlert.alertCallView = callAlertView
            
            lkAlertCalls.append(callAlert)
        }
        
    }
    
    @objc
    func removeTimerAction(_ timer: Timer) {
        guard let userInfo = timer.userInfo as? [String: Any] else {
            return
        }
        
        guard let roomId = userInfo["roomId"] as? String, !roomId.isEmpty else {
            return
        }
        
        removeLiveKitAlertCall(roomId)
    }
    
    func removeLiveKitAlertCall(_ roomId: String) {
        
        guard let lkAlertCall = lkAlertCalls.first (where: {
            $0.liveKitCall?.roomId == roomId
        }) else {
            return
        }
        
        DispatchMainThreadSafe { [self] in
            let timer = lkAlertCall.callTimer
            timer.invalidate()
            
            let callAlertView = lkAlertCall.alertCallView
            if callAlertView.superview != nil {
                callAlertView.removeFromSuperview()
            }
            
            lkAlertCalls.removeAll {
                $0.liveKitCall?.roomId == roomId
            }
        }
    }
    
    func removeAllLiveKitAlertCall() {
      
        lkAlertCalls.forEach {
            guard let liveKitCall = $0.liveKitCall, let roomId = liveKitCall.roomId else {
                return
            }
            
            if case .private = liveKitCall.callType {
                Task {
                    await DTMeetingManager.shared.sendCallMessage(.reject, liveKitCall)
                    removeLiveKitAlertCall(roomId)
                }
            } else {
                removeLiveKitAlertCall(roomId)
            }
        }
        
    }
    
    func bringLiveKitAlertCalls(to window: UIWindow) {
        
        lkAlertCalls.forEach {
            let callAlertView = $0.alertCallView
            callAlertView.removeFromSuperview()
            window.addSubview(callAlertView)
            
            callAlertView.autoHCenterInSuperview()
            callAlertView.autoPinTopToSuperviewMargin()
            callAlertView.autoSetDimension(.height, toSize: 131)
            callAlertView.autoSetDimension(.width, toSize: min(screenHeight, screenWidth) - 16)
        }
    }
    
    func hasLiveKitCallAlert() -> Bool {
        !lkAlertCalls.isEmpty
    }
    
}

extension DTAlertCallViewManager: DTAlertCallViewDelegate {
    
    public func leftButtonAction(_ liveKitCall: DTLiveKitCallModel) {
        guard let roomId = liveKitCall.roomId else {
            return
        }
        
        if case .private = liveKitCall.callType {
            Task {
                await DTMeetingManager.shared.sendCallMessage(.reject, liveKitCall)
                removeLiveKitAlertCall(roomId)
            }
        } else {
            removeLiveKitAlertCall(roomId)
        }
    }
    
    public func rightButtonAction(_ liveKitCall: DTLiveKitCallModel) {
      
        let hasMeeting = DTMeetingManager.shared.hasMeeting
        guard !hasMeeting else {
            DTToastHelper.showCallToast(Localized("CALL_INCOMING_ALERT_ONGOING_TIP"))
            return
        }
        
        DTMeetingManager.shared.acceptCall(call: liveKitCall.copy() as! DTLiveKitCallModel)
        if let roomId = liveKitCall.roomId {
            removeLiveKitAlertCall(roomId)
        }
        removeAllLiveKitAlertCall()
    }
    
    public func swipeAction(_ liveKitCall: DTLiveKitCallModel) {
        guard let roomId = liveKitCall.roomId else {
            return
        }
        
        if case .private = liveKitCall.callType {
            Task {
                await DTMeetingManager.shared.sendCallMessage(.reject, liveKitCall)
                removeLiveKitAlertCall(roomId)
            }
        } else {
            removeLiveKitAlertCall(roomId)
        }
    }
    
    
}
