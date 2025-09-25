//
//  ConversationViewController+Calls.swift
//  Signal
//
//  Created by Jaymin on 2024/2/1.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

@objc
extension ConversationViewController {
    var isCanCall: Bool {
        if self.thread.isKind(of: TSContactThread.self) {
            let isNotBot = (self.thread.contactIdentifier()?.count ?? 0) > 6
            
            return !self.thread.isNoteToSelf && isNotBot && isFriend
        }
        return true
    }
    
    @objc(didTapCallNavBtnWithThread:)
    func didTapCallNavBtn(_ thread: TSThread? = nil) {
        dismissKeyBoard()
        guard !isUserDeregistered() else { return }
        
        if DTMeetingManager.shared.hasMeeting, OWSWindowManager.shared().hasCall() {
            OWSWindowManager.shared().showCallView()
            return
        }
        
        guard isCanSpeak else { return }
        guard isCanCall else {
            OWSLogger.warn("Tried to initiate a call but thread is not callable.")
            return
        }
        
        let threadToUse = thread ?? self.thread

        // 检查目标会话是否在会议中
        DTMeetingManager.shared.startLiveKitCall(thread: threadToUse) {
            self.startCall()
        } joinCall: { targetCall in
            self.joinCall(targetCall)
        }
    }
    
    private func startCall() {
        DTMeetingManager.shared.startCall(
            thread: self.thread,
            displayLoading: true
        )
    }
    
    private func joinCall(_ targetCall: DTLiveKitCallModel) {
        DTMeetingManager.shared.acceptCall(call: targetCall)
    }
}
