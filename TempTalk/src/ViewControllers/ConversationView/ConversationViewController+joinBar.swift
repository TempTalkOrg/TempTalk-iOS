//
//  ConversationViewController+joinBar.swift
//  Difft
//
//  Created by Henry on 2025/8/27.
//  Copyright © 2025 Difft. All rights reserved.
//

// MARK: - Join Bar 管理
extension ConversationViewController {
    
    func setupJoinBarView() {
        if joinCallView.superview != nil {
            refreshJoinBarView()
        } else {
            view.addSubview(joinCallView)
            joinCallView.isHidden = true
            
            joinCallView.autoPinEdge(toSuperviewSafeArea: .top)
            joinCallView.autoPinEdge(toSuperviewEdge: .left)
            joinCallView.autoPinEdge(toSuperviewEdge: .right)
            joinCallView.autoSetDimension(.height, toSize: 44)
            
            joinCallView.joinButton.addTarget(self, action: #selector(joinTapped), for: .touchUpInside)
            
            refreshJoinBarView()
        }
    }
    
    // MARK: - 状态刷新
    func refreshJoinBarView() {
        // 是否允许显示
        guard !DTMeetingManager.shared.isMinimize,
              !DTMeetingManager.shared.allMeetings.isEmpty,
              let callModel = DTMeetingManager.shared.allMeetings.first else {
            dismissJoinCallView()
            return
        }
        
        let recipientId = resolveRecipientId(for: callModel)
        showJoinCallView(with: recipientId, callModel: callModel)
    }
    
    private func dismissJoinCallView() {
        joinCallView.isHidden = true
        curCallModel = nil
        curRecipientId = nil
    }
    
    private func showJoinCallView(with recipientId: String, callModel: DTLiveKitCallModel) {
        curRecipientId = recipientId
        curCallModel = callModel
        joinCallView.isHidden = false
        updateJoinBarUI(recipientId: recipientId, callModel: callModel)
    }
    
    // MARK: - 数据解析
    private func resolveRecipientId(for callModel: DTLiveKitCallModel) -> String {
        switch callModel.callType {
        case .private:
            return callModel.isCaller ? (callModel.conversationId ?? "") : (callModel.caller ?? "")
        case .group:
            return callModel.caller ?? callModel.conversationId ?? ""
        default:
            return callModel.conversationId ?? ""
        }
    }
    
    // MARK: - UI 更新
    private func updateJoinBarUI(recipientId: String, callModel: DTLiveKitCallModel) {
        switch callModel.callType {
        case .private:
            updatePrivateCallUI(recipientId: recipientId, callModel: callModel)
        case .group:
            updateGroupCallUI(callModel: callModel)
        case .instant:
            joinCallView.avatarView.image = UIImage.icInstantMeeting
            joinCallView.textLabel.text = callModel.roomName
        }
    }
    
    private func updatePrivateCallUI(recipientId: String, callModel: DTLiveKitCallModel) {
        joinCallView.avatarView.image = UIImage.profileAvatarDefault
        let displayName = Environment.shared.contactsManager.displayName(forPhoneIdentifier: recipientId)
        
        guard let roomId = callModel.roomId else { return }
        
        Task {
            guard let result = await DTMeetingManager.checkRoomIdValid(roomId) else { return }
            DispatchMainThreadSafe {
                if result.anotherDeviceJoined {
                    self.joinCallView.avatarView.setImageWithRecipientId(TSAccountManager.localNumber())
                    self.joinCallView.textLabel.text = Localized("CONVERSATION_JOIN_BAR_PRIVATE_ANOTHER_DEVICE")
                } else {
                    self.joinCallView.avatarView.setImageWithRecipientId(recipientId)
                    self.joinCallView.textLabel.text = "\(displayName)\(Localized("CONVERSATION_JOIN_BAR_PRIVATE_CALLING"))"
                }
            }
        }
    }
    
    private func updateGroupCallUI(callModel: DTLiveKitCallModel) {
        updateGroupAvatar()
        joinCallView.textLabel.text = callModel.roomName
    }
    
    private func updateGroupAvatar() {
        guard let callModel = curCallModel,
              let conversationId = callModel.conversationId,
              let groupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: conversationId) else { return }
        
        databaseStorage.asyncWrite { transaction in
            if let groupThread = TSGroupThread(groupId: groupId, transaction: transaction) {
                transaction.addAsyncCompletionOffMain {
                    self.joinCallView.avatarView.setImageWith(
                        groupThread,
                        diameter: 24,
                        contactsManager: Environment.shared.contactsManager
                    )
                }
            }
        }
    }
    
    // MARK: - Join 行为
    @objc private func joinTapped() {
        guard let callModel = curCallModel else { return }
        DTMeetingManager.shared.acceptCall(call: callModel)
    }
    
    // MARK: - 外部通知
    @objc func didChangeRefreshJoinBarStatus(_ notification: NSNotification) {
        setupJoinBarView()
    }
    
    func showJoinBarView() -> Bool {
        guard !DTMeetingManager.shared.isMinimize,
              !DTMeetingManager.shared.allMeetings.isEmpty,
              let callModel = DTMeetingManager.shared.allMeetings.first else {
            return false
        }
        return true
    }
       
    func showJoinBarViewHeight() -> CGFloat {
        return 44
    }
}
