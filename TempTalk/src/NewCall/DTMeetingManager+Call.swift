//
//  DTMeetingManager+Call.swift
//  Difft
//
//  Created by Henry on 2025/7/2.
//  Copyright © 2025 Difft. All rights reserved.
//

import DTProto
import LiveKit
import SwiftUICore

extension DTMeetingManager {
    /// - Parameters:
    ///   - thread: 发起1on1/group时传入
    ///   - recipientIds: 发起instant会议时需要
    ///   - displayLoading: 是否展示loading
    func startCall(thread: TSThread?,
                   recipientIds: [String]? = nil,
                   displayLoading: Bool = false) {
        guard !hasMeeting else {
            Logger.info("\(logTag) already in meeting or connecting, ignore duplicate startCall")
            return
        }
        hasMeeting = true

        if let thread = thread {
            startCallThread = thread
        }
        
        if let recipientIds = recipientIds {
            startCallRecipientIds = recipientIds
        }
        
        guard let localNumber = TSAccountManager.localNumber() else {
            Logger.error("\(logTag) No local number.")
            return
        }
        
        if let body = currentCall.ttcalResponseBody {
            Logger.info("\(logTag) the call has exist")
            DispatchMainThreadSafe {
                DTToastHelper.show(withInfo: Localized("MEETING_DOING_FREQUENTLY_TIPS"))
            }
            return
        }
        
        Logger.info("\(logTag) start call with direct LiveKit connection")
                 
        var callType: CallType = .instant
        var conversationId: String?
        var roomName = ""
        var recipientIdentifiers = [String]()
        if let thread {
            if thread.isGroupThread(),
               let groupThread = thread as? TSGroupThread {
                Logger.info("\(logTag) currentThread is groupThread")
                callType = .group
                conversationId = groupThread.serverThreadId
                roomName = thread.name(with: nil)
            } else if let contactThread = thread as? TSContactThread {
                Logger.info("\(logTag) currentThread is TSContactThread")
                let contactIdentifier = contactThread.contactIdentifier().components(separatedBy: ".").first ?? ""
                callType = .private
                conversationId = contactIdentifier
                
                if let signalAccount = contactsManager.signalAccount(forRecipientId: contactIdentifier),
                   let contact = signalAccount.contact {

                    if let remark = contact.remark {
                        roomName = remark
                    } else {
                        roomName = contact.fullName
                    }
                }
            }
            
            recipientIdentifiers = thread.recipientIdentifiers
            recipientIdentifiers.append(localNumber)
            
            let filteredIdentifiers = recipientIdentifiers.map { recipient in
                return recipient.split(separator: ".").first.map { String($0) } ?? recipient
            }
            
            recipientIdentifiers = filteredIdentifiers

        } else {
            if let recipientIds {
                recipientIdentifiers = recipientIds
            }
            
            let localName = contactsManager.displayName(forPhoneIdentifier: localNumber)
            roomName = "\(localName)'s Meeting"
        }
        
        if displayLoading {
            DispatchMainThreadSafe {
                DTToastHelper.show01LoadingHudIsDark(Theme.isDarkThemeEnabled, in: nil)
            }
        }
        
        let newCall = DTLiveKitCallModel()
        newCall.caller = localNumber
        newCall.roomName = roomName
        newCall.callType = callType
        newCall.callState = .outgoing
        newCall.conversationId = conversationId
        Logger.info("\(logTag) currentCall callType is \(callType)")

        if newCall.callType == .private {
            newCall.callees = recipientIdentifiers.filter({
                $0 != localNumber
            })
        }
        
        let timestamp = Date.ows_millisecondTimestamp()
        newCall.timestamp = timestamp
        newCall.createCallMsg = createCallMsgEnabled()
        newCall.controlType = DTMeetingManager.sourceControlStart
        newCall.inviteCallees = recipientIdentifiers
        
        currentCall = newCall
        hasTriggeredRating = false

        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                let mKey = DTProtoAdapter().generateKey(version: Self.meetingVersion)
                
                guard let callMessage = await self.createCallMessage(
                    localNumber: localNumber,
                    callType: newCall.callType,
                    conversationId: conversationId,
                    caller: newCall.caller,
                    recipientIds: recipientIdentifiers,
                    roomId: nil,
                    roomName: newCall.roomName,
                    mKey: mKey,
                    createCallMsg: self.createCallMsgEnabled(),
                    controlType: DTMeetingManager.sourceControlStart,
                    callees: [],
                    timestamp: timestamp) else {
                    throw CallError.messageCreationFailed
                }
                
                let stringPublicKey = callMessage.keyResult.eKey.base64EncodedString()
                
                let protoMessages: [Livekit_TTCipherMessages] = parseCipherMessages(callMessage.cipherMessages)
                let protoEncInfos: [Livekit_TTEncInfo] = parseEncInfoArray(callMessage.encInfos)
                
                fromSource = "startCall"
                
                try await self.connectDirectlyToLiveKit(
                    callType: newCall.callType,
                    conversationId: conversationId,
                    timestamp: timestamp,
                    isCaller: true,
                    fromCallKit: false,
                    cipherMessages: protoMessages,
                    encInfos: protoEncInfos,
                    publicKey: stringPublicKey
                )
            } catch {
                Logger.error("\(self.logTag) Start call failed: \(error)")
                await self.handleStartCallFailure(error: error)
            }
        }
    }
    
    func acceptCall(call: DTLiveKitCallModel) {
        
        currentCall = call
        guard let roomId = call.roomId else {
            Logger.error("\(logTag) accept call roomid nil")
            return
        }
        
        Logger.info("\(logTag) accept meeting")

        DTMeetingManager.shared.acceptCall(
            type: call.callType,
            roomId: roomId,
            publicKey: nil,
            emk: nil,
            fromCallKit: false
        )
    }
    
    
    func answerCall(caller: String, roomId: String, publicKey: Data, emk: Data, fromCallKit: Bool) {
        
        guard !isAnswering else {
            Logger.info("\(logTag) already answering, ignore duplicate answerCall")
            return
        }
        
        isAnswering = true
        stopSound()
        
        Logger.info("\(logTag) answer meeting")
        
        acceptCall(type: currentCall.callType,
                   roomId: roomId,
                   publicKey: publicKey,
                   emk:emk,
                   fromCallKit: fromCallKit)
        if !fromCallKit {
            DTCallKitManager.shared().answerCallAction(caller)
        }
    }
}

extension DTMeetingManager {
    private func acceptCall(type: CallType,
                    roomId: String,
                    version: Int32 = DTMeetingManager.meetingVersion,
                    publicKey: Data?,
                    emk: Data?,
                    fromCallKit: Bool) {
        
        Logger.info("\(logTag) accept call with direct LiveKit connection")
        
        // 清理高亮消息
        if let conversationId = currentCall.conversationId, !conversationId.isEmpty {
            self.databaseStorage.write { writeTransaction in
                if currentCall.callType == .private {
                    if let contactThread = TSContactThread.getThread(contactId: conversationId, transaction: writeTransaction) {
                        contactThread.removeCriticalAlertMsg(with: writeTransaction)
                    }
                } else {
                    if let localGroupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: conversationId),
                       let groupThread = TSGroupThread.getWithGroupId(localGroupId, transaction: writeTransaction) {
                        groupThread.removeCriticalAlertMsg(with: writeTransaction)
                    }
                }
            }
        }
        
        Task {
            fromSource = "acceptCall"
            
            await connectDirectlyToLiveKit(
                callType: type,
                roomId: roomId,
                conversationId: currentCall.conversationId,
                timestamp: Date.ows_millisecondTimestamp(),
                isCaller: false,
                fromCallKit: fromCallKit,
                cipherMessages: nil,
                encInfos: nil,
                publicKey: nil
            )
        }
    }
    
    private func connectDirectlyToLiveKit(
        callType: CallType,
        roomId: String? = nil,
        conversationId: String?,
        timestamp: UInt64,
        isCaller: Bool = true,
        fromCallKit: Bool = false,
        cipherMessages: [Livekit_TTCipherMessages]?,
        encInfos: [Livekit_TTEncInfo]?,
        publicKey: String?
    ) async {
        Logger.info("\(logTag) connecting directly to LiveKit with ttCallRequest")
        
        do {
            currentCall.timestamp = timestamp
    
            let token = try await requestAuthToken()
            let collapseId = collapseId(timestamp: timestamp)

            let connectOptions = buildConnectOptions(
                callType: callType,
                roomId: roomId,
                conversationId: conversationId,
                timestamp: timestamp,
                publicKey: publicKey,
                cipherMessages: cipherMessages,
                encInfos: encInfos,
                collapseId: collapseId,
                token: token
            )
            
            guard await setupRoomContextIfNeeded(token: token, publicKey: publicKey ?? "") else {
                await MainActor.run {
                    DTToastHelper.hide()
                    DTToastHelper.dismiss(withInfo: "roomContext connect room failed")
                }
                return
            }
            
            // 先出UI
            await MainActor.run {
                DTToastHelper.hide()
                presentCallUI(callType: callType, isCaller: isCaller, fromCallKit: fromCallKit)
            }
            
            // 后连接
            await connectRoomSafely(fromCallKit: fromCallKit, connectOptions: connectOptions)
        } catch {
            Logger.error("\(logTag) request token error: \(error)")
            await hangupCall(needSyncCallKit: false,
                             isByLocal: true,
                             forceEndGroupMeeting: false,
                             roomId: currentCall.roomId,
                             removeMeetingBar: false,
                             showErrorToast: true)
        }
    }
    
    private func buildConnectOptions(
        callType: CallType,
        roomId: String?,
        conversationId: String?,
        timestamp: UInt64,
        publicKey: String? = nil,
        cipherMessages: [Livekit_TTCipherMessages]? = nil,
        encInfos: [Livekit_TTEncInfo]? = nil,
        collapseId: String,
        token: String
    ) -> ConnectOptions {
        var connectOptions = ConnectOptions()
        if let cipherMessages = cipherMessages,
            let encInfos = encInfos,
            let publicKey = publicKey {
            connectOptions = ConnectOptions(
                reconnectAttempts: 20,
                reconnectAttemptDelay: 2,
                ttCallRequest: Livekit_TTCallRequest.with {
                    $0.token = token
                    $0.startCall = Livekit_TTStartCall.with {
                        $0.type = callType.rawValue
                        $0.version = Self.meetingVersion
                        $0.timestamp = Int64(timestamp)
                        $0.conversationID = conversationId ?? ""
                        $0.publicKey = publicKey
                        $0.cipherMessages = cipherMessages
                        $0.encInfos = encInfos
                        $0.notification = Livekit_TTNotification.with {
                            $0.type = Int32(DTApnsMessageType.ENC_CALL.rawValue)
                            $0.args = .with { $0.collapseID = collapseId }
                        }
                    }
                    $0.userAgent = TSConstants.appUserAgent
                },
                userAgent: TSConstants.appUserAgent
            )
        } else if let roomId = roomId {
            connectOptions = ConnectOptions(
                reconnectAttempts: 20,
                reconnectAttemptDelay: 2,
                ttCallRequest: Livekit_TTCallRequest.with {
                    $0.token = token
                    $0.startCall = Livekit_TTStartCall.with {
                        $0.type = callType.rawValue
                        $0.roomID = roomId
                        $0.version = Self.meetingVersion
                        $0.timestamp = Int64(timestamp)
                    }
                    $0.userAgent = TSConstants.appUserAgent
                },
                userAgent: TSConstants.appUserAgent
            )
        }
        
        return connectOptions
    }
    
    @MainActor
    private func setupRoomContextIfNeeded(token: String, publicKey: String) async -> Bool {
        if roomContext != nil {
            Logger.info("\(logTag) roomContext not nil")
            DTToastHelper.hide()
            return false
        }
        let serviceUrlManager = TTCallServiceUrlManager()
        guard let url = await serviceUrlManager.getCurrentUrl() else { return false }
        
        roomContext = RoomContext(url: url, token: token, lkContext: appContext)
        roomContext?.serviceUrlManager = serviceUrlManager
        return true
    }
    
    @MainActor
    private func presentCallUI(callType: CallType, isCaller: Bool, fromCallKit: Bool) {
        let reachable = Reachability.forInternetConnection()?.isReachable() ?? false
        if reachable == false {
            DTToastHelper.show(withInfo: Localized("SINGLE_CALL_CALLER_NETWORK_ABNORMAL"))
            return
        }
        
        guard let appContext = appContext, let roomContext = roomContext else {
            Logger.info("\(logTag) appcontext roomContext init exception")
            DTToastHelper.show(withInfo: Localized("ERROR_DESCRIPTION_UNKNOWN_ERROR"))
            return
        }
                
        let contextView = RoomContextView()
            .environmentObject(appContext)
            .environmentObject(roomContext)
        
        let callVC = DTHostingController(rootView: AnyView(contextView))
        self.hostRoomContentVC = callVC
        hasMeeting = true
        
        if isCaller {
            OWSWindowManager.shared().startCall(callVC, animated: true)
            if case .private = callType {
                startCallTimeoutTimer()
                if !fromCallKit {
                    playSound(.callOutgoing1v1, playMode: .playback)
                }
            }
        } else {
            dismissAnswerVCIfNeeded()
            OWSWindowManager.shared().startCall(callVC, animated: false)
        }
    }
    
    @MainActor
    private func dismissAnswerVCIfNeeded() {
        guard let answerVC else { return }
        
        switch answerVCPresentationStyle {
        case .windowManager:
            OWSWindowManager.shared().endCall(answerVC) {
                self.clearAnswerVCState()
            }
            
        case .modal:
            answerVC.dismiss(animated: false) { [weak self] in
                self?.clearAnswerVCState()
            }
            
        case .navigation:
            if let nav = answerVC.navigationController {
                nav.popViewController(animated: false)
                self.clearAnswerVCState()
            } else {
                self.clearAnswerVCState()
            }
        }
    }
    
    /// 安全发起连接
    private func connectRoomSafely(fromCallKit: Bool, connectOptions: ConnectOptions) async {
        Logger.info("\(logTag) starting direct LiveKit connection with ttCallRequest")
        do {
            let _ = try await roomContext?.connect(connectOptions: connectOptions)
        } catch {
            Logger.info("\(self.logTag) hangup callkit room connect failed")
            await hangupCall(needSyncCallKit: fromCallKit)
            await DTToastHelper.dismiss(withInfo: "connect room failed")
        }
    }
    
    func showAnswer(call: DTLiveKitCallModel, fromCallKit: Bool = false, onPlaySound: (() -> Void)? = nil) {
        Logger.info("\(logTag) show answer controller: fromCallKit=\(fromCallKit)")
        currentCall = call
        hasMeeting = true
        hasTriggeredRating = false
        isFromCallkit = fromCallKit

        guard let publicKey = call.publicKey, let emk = call.emk else {
            Logger.error("\(logTag) publicKey or emk is nil.")
            DTToastHelper.showCallToast("Unkonwn caller information")
            return
        }
        
        guard let caller = call.caller else {
            Logger.error("\(logTag) No caller information.")
            DTToastHelper.showCallToast("Unkonwn caller information")
            return
        }
        
        guard let roomId = call.roomId else {
            Logger.error("\(logTag) No roomId information.")
            DTToastHelper.showCallToast("Unkonwn call information")
            return
        }
              
        Task {
            if fromCallKit {
                Logger.info("\(logTag) answer from CallKit")
                handleMeetingBar(call: call, action: .add)

                guard !isAnswering else {
                    Logger.info("\(logTag) already answering, ignore duplicate answerCall from CallKit")
                    return
                }

                answerCall(caller: caller, roomId: roomId, publicKey: publicKey, emk: emk, fromCallKit: true)
                onPlaySound?()

                Task.detached { [weak self] in
                    guard let self = self else { return }
                    if let result = await DTMeetingManager.checkRoomIdValid(roomId) {
                        if result.anotherDeviceJoined || result.userStopped {
                            Logger.info("\(self.logTag) roomId invalid, hanging up after CallKit answer")
                            await self.hangupCall(
                                needSyncCallKit: true,
                                isByLocal: true,
                                roomId: roomId,
                                removeMeetingBar: true,
                                showErrorToast: true
                            )
                        }
                    }
                }
            } else {
                guard let result = await DTMeetingManager.checkRoomIdValid(roomId) else {
                    return
                }
                
                if result.anotherDeviceJoined || result.userStopped {
                    Logger.info("\(logTag) checkRoomIdValid anotherDeviceJoined\(result.anotherDeviceJoined) userStopped\(result.userStopped)")
                    return
                }
                
                onPlaySound?()
                
                DispatchMainThreadSafe {
                    self.startCallTimeoutTimer()
                    self.presentAnswerVC(call: call, caller: caller, roomId: roomId, publicKey: publicKey, emk: emk)
                }
            }
        }
    }
    
    @MainActor
    private func presentAnswerVC(call: DTLiveKitCallModel, caller: String, roomId: String, publicKey: Data, emk: Data) {
        let answerVC = DTHostingController(rootView:
                                            CallAnswerView(
                                                currentCall: call,
                                                autoAccept: false,
                                                isConnecting: false,
                                                onAnswer: { [weak self] in
                    guard let self else { return }
                    Logger.info("\(logTag) answer from alertView")
                    guard !isAnswering else {
                        Logger.info("\(logTag) already answering, ignore duplicate answerCall from alertView")
                        return
                    }
                    clearAnswerVCState()
                    stopCallTimeoutTimer()
                    answerCall(caller: caller, roomId: roomId, publicKey: publicKey, emk: emk, fromCallKit: false)
                                                },
                                                
                                                onDecline: { [weak self] in
                    guard let self else { return }
                    
                    Logger.info("\(logTag) reject from alertView")
                    clearAnswerVCState()
                    stopCallTimeoutTimer()
                    if currentCall.callType != .private {
                        handleMeetingBar(call: call, action: .add)
                    }
                    Task {
                        await self.rejectRemoteCall()
                        Logger.info("\(self.logTag) reject remote call")
                    }
                }))
        
        OWSWindowManager.shared().startCall(answerVC, animated: true)
        self.answerVC = answerVC
        self.answerVCPresentationStyle = .windowManager
    }
    

    func handleCallError() {
        DispatchMainThreadSafe { [weak self] in
            guard let self = self else { return }
            self.performCompleteCleanup()
        }
    }
    
    private func handleStartCallFailure(error: Error) async {
        Logger.error("\(logTag) Handling start call failure: \(error)")
        
        hasMeeting = false
        inMeeting = false
        callState = .error
        
        performCompleteCleanup()

        DispatchMainThreadSafe {
            DTToastHelper.dismiss(withInfo: "Call start failed: \(error.localizedDescription)")
        }
    }
    
    /// 清理 AnswerVC 状态
    private func clearAnswerVCState() {
        answerVC = nil
        answerVCPresentationStyle = .windowManager
    }
}
