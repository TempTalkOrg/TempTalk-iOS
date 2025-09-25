//
//  DTHostingController.swift
//  TempTalk
//
//  Created by Ethan on 09/01/2025.
//  Copyright © 2025 Difft. All rights reserved.
//

import SwiftUI
import UIKit
import Foundation

class DTHostingController<Content: View>: UIHostingController<Content> {
    
//    private var orientations: UIInterfaceOrientationMask = .portrait
    
    var autoLeaveTipView: DTAutoLeaveTipView?
    var hasShowLeaveTipView: Bool = false

    init(rootView: Content, backgroundColor: UIColor = UIColor(rgbHex: 0x181A20)/*, orientations: UIInterfaceOrientationMask = .portrait*/) {
        super.init(rootView: rootView)
        
        self.overrideUserInterfaceStyle = .dark
        self.view.backgroundColor = backgroundColor
//        self.orientations = orientations
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(themeDidChange),
            name: .ThemeDidChange,
            object: nil
        )

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        additionalSafeAreaInsets = .zero
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
        
    @objc
    func themeDidChange() {
        
        // 保证会议vc背景始终为深色
        view.backgroundColor = .black
    }

    @available(*, unavailable)
    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc
    func showAutoLipView(_ isSoloMember: Bool) {
        if !hasShowLeaveTipView {
            self.autoLeaveTipView = DTAutoLeaveTipView.init(confirmBlock: {
                self.autoLeaveTipView?.removeFromSuperview()
                self.hasShowLeaveTipView = false
                self.autoLeaveTipView?.stopTimeoutTimer()
                DTMeetingManager.shared.stopCheckTalking()
                DTMeetingManager.shared.currentCallTalkingPop()
                if DTMeetingManager.shared.currentCall.callType == .private {
                    Task { [weak self] in
                        await DTMeetingManager.shared.sendRemoteSyncContinueStatus()
                    }
                }
            }, timeoutBlock: {
                self.autoLeaveTipView?.removeFromSuperview()
                self.hasShowLeaveTipView = false
                self.autoLeaveTipView?.stopTimeoutTimer()
                DTMeetingManager.shared.stopCheckTalking()
                Task {
                    Logger.info("\(self.logTag) hangup auto leave meeting")
                    await DTMeetingManager.shared.hangupCall(needSyncCallKit: true,
                                                             isByLocal: true)
                }
            })
            
            self.autoLeaveTipView?.frame = self.view.bounds
            self.autoLeaveTipView?.updateTipsLabel(isSoloMember)
            self.autoLeaveTipView?.startTimeoutTimer(UInt(DTMeetingManager.shared.reminderTimeoutResult))
            self.view.addSubview(self.autoLeaveTipView!)
            hasShowLeaveTipView = true
        }
    }
    
    @objc
    func dismissAutoLipView() {
        if hasShowLeaveTipView {
            self.autoLeaveTipView?.stopTimeoutTimer()
            self.autoLeaveTipView?.removeFromSuperview()
            hasShowLeaveTipView = false
        }
    }
}
