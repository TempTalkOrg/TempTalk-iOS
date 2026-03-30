//
//  DTMeetingManager+Call.swift
//  Difft
//
//  Created by Henry on 2025/7/2.
//  Copyright © 2025 Difft. All rights reserved.
//

import DTProto
import LiveKit
import SwiftUI

extension DTMeetingManager {
    /// - Parameters:
    ///   - thread: 发起1on1/group时传入
    ///   - recipientIds: 发起instant会议时需要
    ///   - displayLoading: 是否展示loading
    func startCall(thread: TSThread?,
                   recipientIds: [String]? = nil,
                   displayLoading: Bool = false)
    {
        Logger.info("\(logTag) start call with direct LiveKit connection, current state: \(lifecycleState)")

        // 状态恢复：如果状态卡在非 idle 状态，但没有活跃的 roomContext，强制重置
        if lifecycleState != .idle && roomContext == nil {
            Logger.warn("\(logTag) State stuck at \(lifecycleState) without roomContext, forcing reset to idle")
            forceTransition(to: .idle)
        }

        // 原子性尝试转换到 connecting 状态
        guard tryTransition(from: .idle, to: .connecting) else {
            Logger.error("\(logTag) cannot start call, current state: \(lifecycleState)")
            DispatchMainThreadSafe {
                DTToastHelper.hide()
                DTToastHelper.dismiss(withInfo: Localized("ROOM_CONNECT_FAILED"))
            }
            return
        }

        guard let localNumber = TSAccountManager.localNumber() else {
            Logger.error("\(logTag) No local number.")
            DispatchMainThreadSafe {
                DTToastHelper.hide()
                DTToastHelper.dismiss(withInfo: Localized("ROOM_CONNECT_FAILED"))
            }
            forceTransition(to: .idle)
            return
        }

        if currentCall.ttcalResponseBody != nil {
            Logger.error("\(logTag) the call has exist")
            forceTransition(to: .idle)
            DispatchMainThreadSafe {
                DTToastHelper.hide()
                DTToastHelper.show(withInfo: Localized("MEETING_DOING_FREQUENTLY_TIPS"))
            }
            return
        }

        if let thread {
            startCallThread = thread
        }

        if let recipientIds {
            startCallRecipientIds = recipientIds
        }

        var callType: CallType = .instant
        var conversationId: String?
        var roomName = ""
        var recipientIdentifiers = [String]()
        if let thread {
            if thread.isGroupThread(),
               let groupThread = thread as? TSGroupThread
            {
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
                   let contact = signalAccount.contact
                {
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
                recipient.split(separator: ".").first.map { String($0) } ?? recipient
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
            newCall.callees = recipientIdentifiers.filter {
                $0 != localNumber
            }
        }

        let timestamp = Date.ows_millisecondTimestamp()
        newCall.timestamp = timestamp
        newCall.createCallMsg = createCallMsgEnabled()
        newCall.controlType = DTMeetingManager.sourceControlStart
        newCall.inviteCallees = recipientIdentifiers

        currentCall = newCall
        hasTriggeredRating = false
        // 主动发起通话，不是来自 CallKit
        isFromCallkit = false

        Logger.info("\(logTag) start call create message")

        Task { [weak self] in
            guard let self else { return }

            do {
                let mKey = DTProtoAdapter().generateKey(version: Self.meetingVersion)

                guard let callMessage = await createCallMessage(
                    localNumber: localNumber,
                    callType: newCall.callType,
                    conversationId: conversationId,
                    caller: newCall.caller,
                    recipientIds: recipientIdentifiers,
                    roomId: nil,
                    roomName: newCall.roomName,
                    mKey: mKey,
                    createCallMsg: createCallMsgEnabled(),
                    controlType: DTMeetingManager.sourceControlStart,
                    callees: [],
                    timestamp: timestamp
                ) else {
                    throw CallError.messageCreationFailed
                }

                let stringPublicKey = callMessage.keyResult.eKey.base64EncodedString()

                let protoMessages: [Livekit_TTCipherMessages] = parseCipherMessages(callMessage.cipherMessages)
                let protoEncInfos: [Livekit_TTEncInfo] = parseEncInfoArray(callMessage.encInfos)

                fromSource = "startCall"

                await connectDirectlyToLiveKit(
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
                Logger.error("\(logTag) Start call failed: \(error)")
                await handleStartCallFailure(error: error)
            }
        }
    }

    func acceptCall(call: DTLiveKitCallModel) {
        Logger.info("\(logTag) accept call entry")

        guard let roomId = call.roomId else {
            DispatchMainThreadSafe {
                DTToastHelper.hide()
                DTToastHelper.dismiss(withInfo: Localized("ROOM_CONNECT_FAILED"))
            }
            Logger.error("\(logTag) accept call roomid nil")
            return
        }

        currentCall = call

        Logger.info("\(logTag) accept meeting, roomId: \(roomId)")

        acceptCall(
            type: call.callType,
            roomId: roomId,
            publicKey: nil,
            emk: nil,
            fromCallKit: false
        )
    }

    func answerCall(caller _: String, roomId: String, publicKey: Data, emk: Data, fromCallKit: Bool) {
        Logger.info("\(logTag) answer call entry, fromCallKit: \(fromCallKit)")

        stopSound()

        acceptCall(type: currentCall.callType,
                   roomId: roomId,
                   publicKey: publicKey,
                   emk: emk,
                   fromCallKit: fromCallKit)
    }
}

extension DTMeetingManager {
    private func acceptCall(type: CallType,
                            roomId: String,
                            version _: Int32 = DTMeetingManager.meetingVersion,
                            publicKey _: Data?,
                            emk _: Data?,
                            fromCallKit: Bool)
    {
        Logger.info("\(logTag) accept call base, current state: \(lifecycleState)")

        guard !isAnswering else {
            DispatchMainThreadSafe {
                DTToastHelper.hide()
                DTToastHelper.dismiss(withInfo: Localized("ROOM_CONNECT_FAILED"))
            }
            Logger.error("\(logTag) already answering, ignore duplicate acceptCall")
            if fromCallKit, let caller = currentCall.caller {
                DTCallKitManager.shared().endCallAction(caller, onlyForCallKit: true)
            }
            return
        }

        isAnswering = true

        if lifecycleState == .disconnecting && roomContext == nil {
            Logger.warn("\(logTag) State stuck at disconnecting without roomContext, forcing reset to idle")
            forceTransition(to: .idle)
        }

        let currentState = lifecycleState
        guard currentState == .idle || currentState == .connecting else {
            DispatchMainThreadSafe {
                DTToastHelper.hide()
                DTToastHelper.dismiss(withInfo: Localized("ROOM_CONNECT_FAILED"))
            }
            Logger.error("\(logTag) cannot accept call, current state: \(currentState)")
            isAnswering = false
            if fromCallKit, let caller = currentCall.caller {
                DTCallKitManager.shared().endCallAction(caller, onlyForCallKit: true)
            }
            return
        }

        // 如果是 idle 状态，转换到 connecting
        if currentState == .idle {
            tryTransition(from: .idle, to: .connecting)
        }

        // 优先挂断callkit，走正常入会流程
        if !fromCallKit, let caller = currentCall.caller {
            Logger.info("\(logTag) endCall caller: \(caller)")
            DTCallKitManager.shared().endCallAction(caller, onlyForCallKit: true)
        }

        Logger.info("\(logTag) accept call with direct LiveKit connection, roomId: \(roomId)")

        let capturedRoomId = roomId
        let capturedConversationId = currentCall.conversationId

        clearCriticalHightMessagesAsync()

        Task {
            fromSource = "acceptCall"

            guard lifecycleState == .connecting else {
                Logger.warn("\(logTag) state changed during async wait, aborting acceptCall")
                isAnswering = false
                if fromCallKit, let caller = currentCall.caller {
                    await MainActor.run {
                        DTCallKitManager.shared().endCallAction(caller, onlyForCallKit: true)
                    }
                }
                return
            }

            await ensureCleanConnectionState(roomId: capturedRoomId)

            guard lifecycleState == .connecting else {
                Logger.warn("\(logTag) state changed during cleanup, aborting acceptCall")
                isAnswering = false
                if fromCallKit, let caller = currentCall.caller {
                    await MainActor.run {
                        DTCallKitManager.shared().endCallAction(caller, onlyForCallKit: true)
                    }
                }
                return
            }

            await connectDirectlyToLiveKit(
                callType: type,
                roomId: capturedRoomId,
                conversationId: capturedConversationId,
                timestamp: Date.ows_millisecondTimestamp(),
                isCaller: false,
                fromCallKit: fromCallKit,
                cipherMessages: nil,
                encInfos: nil,
                publicKey: nil,
                skipCleanup: true // 已在上面清理过，跳过重复清理
            )
        }
    }
    
    func clearCriticalHightMessages() {
        if let conversationId = currentCall.conversationId, !conversationId.isEmpty {
            let callType = currentCall.callType
            databaseStorage.asyncWrite { writeTransaction in
                if callType == .private {
                    if let contactThread = TSContactThread.getThread(contactId: conversationId, transaction: writeTransaction) {
                        contactThread.removeCriticalAlertMsg(with: writeTransaction)
                    }
                } else {
                    if let localGroupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: conversationId),
                       let groupThread = TSGroupThread.getWithGroupId(localGroupId, transaction: writeTransaction)
                    {
                        groupThread.removeCriticalAlertMsg(with: writeTransaction)
                    }
                }
            }
        }
    }

    private func clearCriticalHightMessagesAsync() {
        if let conversationId = currentCall.conversationId, !conversationId.isEmpty {
            let callType = currentCall.callType
            // 在后台异步执行，不阻塞当前流程
            databaseStorage.asyncWrite { writeTransaction in
                if callType == .private {
                    if let contactThread = TSContactThread.getThread(contactId: conversationId, transaction: writeTransaction) {
                        contactThread.removeCriticalAlertMsg(with: writeTransaction)
                    }
                } else {
                    if let localGroupId = TSGroupThread.transformToLocalGroupId(withServerGroupId: conversationId),
                       let groupThread = TSGroupThread.getWithGroupId(localGroupId, transaction: writeTransaction)
                    {
                        groupThread.removeCriticalAlertMsg(with: writeTransaction)
                    }
                }
            }
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
        publicKey: String?,
        skipCleanup: Bool = false
    ) async {
        Logger.info("\(logTag) connecting directly to LiveKit with ttCallRequest, skipCleanup: \(skipCleanup)")

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

            // 确保在连接前清理旧的连接状态（如果还没有清理过）
            if !skipCleanup {
                await ensureCleanConnectionState(roomId: roomId)
            }

            guard await setupRoomContextIfNeeded(token: token, publicKey: publicKey ?? "") else {
                await MainActor.run {
                    DTToastHelper.hide()
                    DTToastHelper.dismiss(withInfo: Localized("ROOM_CONNECT_FAILED"))
                }
                isAnswering = false
                await hangupCall(needSyncCallKit: fromCallKit,
                                 isByLocal: true,
                                 forceEndGroupMeeting: false,
                                 roomId: currentCall.roomId,
                                 showErrorToast: false)
                return
            }

            // 先出UI
            await MainActor.run {
                DTToastHelper.hide()
                presentCallUI(callType: callType, isCaller: isCaller, fromCallKit: fromCallKit)
            }

            // 后连接
            await connectRoomSafely(fromCallKit: fromCallKit, connectOptions: connectOptions)

            // 连接完成后，主动检查屏幕共享（onAppear 时 room 未连接，检测不到）
            if fromCallKit {
                await MainActor.run {
                    roomContext?.checkAndPresentScreenShareIfNeeded()
                }
            }
        } catch {
            Logger.error("\(logTag) request token error: \(error)")
            isAnswering = false
            await hangupCall(needSyncCallKit: fromCallKit,
                             isByLocal: true,
                             forceEndGroupMeeting: false,
                             roomId: currentCall.roomId,
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

        // Determine transport kind based on gray release
        let transportKind: TransportKind = GrayReleaseManager.shared.isQuicEnabled ? .quic : .websocket
        if let cipherMessages,
           let encInfos,
           let publicKey
        {
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
                userAgent: TSConstants.appUserAgent,
                transportKind: transportKind
            )
        } else if let roomId {
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
                userAgent: TSConstants.appUserAgent,
                transportKind: transportKind
            )
        }

        return connectOptions
    }

    @MainActor
    private func ensureCleanConnectionState(roomId _: String?) async {
        guard let roomContext else {
            Logger.info("\(logTag) no existing roomContext, connection state is clean")
            return
        }

        let connectionState = roomContext.room.connectionState
        Logger.info("\(logTag) existing roomContext found, connectionState: \(connectionState)")

        if case .disconnected = connectionState {
            self.roomContext = nil
        } else {
            // Initiate disconnect but don't wait — clear reference immediately
            await roomContext.disconnect()
            self.roomContext = nil
            Logger.info("\(logTag) disconnect initiated, roomContext cleared immediately")
        }
        // Minimal yield to let RunLoop process once
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
    }

    @MainActor
    private func setupRoomContextIfNeeded(token: String, publicKey _: String) async -> Bool {
        if roomContext != nil {
            Logger.error("\(logTag) roomContext still exists after cleanup, forcing cleanup")
            await ensureCleanConnectionState(roomId: currentCall.roomId)
        }

        guard roomContext == nil else {
            Logger.error("\(logTag) roomContext still exists after cleanup attempt")
            DTToastHelper.hide()
            return false
        }

        let serviceUrlManager = TTCallServiceUrlManager()
        guard let url = await serviceUrlManager.getCurrentUrl() else { return false }

        roomContext = RoomContext(url: url, token: token, lkContext: appContext)
        roomContext?.serviceUrlManager = serviceUrlManager
        Logger.info("\(logTag) created new roomContext")
        return true
    }

    @MainActor
    private func presentCallUI(callType: CallType, isCaller: Bool, fromCallKit: Bool) {
        let reachable = Reachability.forInternetConnection()?.isReachable() ?? false
        if reachable == false {
            DTToastHelper.show(withInfo: Localized("SINGLE_CALL_CALLER_NETWORK_ABNORMAL"))
            return
        }

        guard let appContext, let roomContext else {
            Logger.info("\(logTag) appcontext roomContext init exception")
            DTToastHelper.show(withInfo: Localized("ERROR_DESCRIPTION_UNKNOWN_ERROR"))
            return
        }

        let contextView = RoomContextView()
            .environmentObject(appContext)
            .environmentObject(roomContext)

        let callVC = DTHostingController(rootView: AnyView(contextView))
        hostRoomContentVC = callVC
        hasMeeting = true

        if isCaller {
            Logger.info("\(logTag) isCaller = true, startCall")
            OWSWindowManager.shared().startCall(callVC, animated: true)
            if case .private = callType {
                startCallTimeoutTimer()
                if !fromCallKit {
                    playSound(.callOutgoing1v1, playMode: .playback)
                }
            }
        } else {
            if let answerVC {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
                    if let nav = answerVC.navigationController {
                        nav.pushViewController(callVC, animated: false, completion: { [weak self] in
                            guard let self else { return }
                            Logger.error("\(logTag) answer nav removeViewController")
                            answerVC.navigationController?.removeViewController(ofType: type(of: answerVC))
                            self.answerVC = nil
                        })
                    } else {
                        Logger.error("\(logTag) answer nav nil")
                        self.answerVC = nil
                        OWSWindowManager.shared().startCall(callVC, animated: false)
                    }
                }
            } else {
                Logger.info("\(logTag) isCaller = false, startCall")
                OWSWindowManager.shared().startCall(callVC, animated: false)
            }
        }
    }

    /// 安全发起连接
    private func connectRoomSafely(fromCallKit: Bool, connectOptions: ConnectOptions) async {
        Logger.info("\(logTag) starting direct LiveKit connection with ttCallRequest")
        do {
            _ = try await roomContext?.connect(fromCallKit: fromCallKit, connectOptions: connectOptions)
        } catch is CancellationError {
            Logger.info("\(logTag) room connect cancelled, skip hangup")
            isAnswering = false
        } catch {
            Logger.info("\(logTag) hangup callkit room connect failed, error: \(error)")
            // 连接失败时重置 isAnswering 标志，允许重新尝试
            isAnswering = false
            // 先捕获 roomId，hangupCall 执行后 currentCall 会被清空
            let failedRoomId = currentCall.roomId
            await hangupCall(needSyncCallKit: fromCallKit)
            if let lkError = error as? LiveKitError, lkError.type == .startCall {
                if lkError.response?.base.status == 22001 {
                    // 会议已结束，无论 callType 都移除 meetingBar
                    if let roomId = failedRoomId {
                        handleMeetingBar(roomId: roomId, action: .remove)
                    }
                    await DTToastHelper.dismiss(withInfo: Localized("CALL_NO_CONNECT_ENDED"))
                } else {
                    await DTToastHelper.dismiss(withInfo: lkError.response?.base.reason ?? Localized("ROOM_CONNECT_FAILED"))
                }
            } else {
                await DTToastHelper.dismiss(withInfo: Localized("ROOM_CONNECT_FAILED"))
            }
        }
    }

    func showAnswer(call: DTLiveKitCallModel, fromCallKit: Bool = false, onPlaySound: (() -> Void)? = nil) {
        Logger.info("\(logTag) show answer controller: fromCallKit=\(fromCallKit)")

        if !fromCallKit, isFromCallkit, currentCall.roomId == call.roomId {
            Logger.info("\(logTag) already answered via CallKit, skipping incoming call UI")
            return
        }

        currentCall = call
        hasMeeting = true
        hasTriggeredRating = false
        if fromCallKit {
            isFromCallkit = true
        }

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

                if let existingAnswerVC = answerVC {
                    Logger.info("\(logTag) dismissing existing answerVC before CallKit answer")
                    await MainActor.run {
                        OWSWindowManager.shared().endCall(existingAnswerVC) {}
                        self.answerVC = nil
                    }
                }

                answerCall(caller: caller, roomId: roomId, publicKey: publicKey, emk: emk, fromCallKit: true)
                onPlaySound?()

                // ✅ UI update runs async, doesn't block the answer flow
                Task { @MainActor in
                    handleMeetingBar(call: call, action: .add)
                }

                // ✅ Async room validity check — doesn't block answering
                Task.detached { [weak self] in
                    guard let self else { return }
                    if let result = await DTMeetingManager.checkRoomIdValid(roomId) {
                        if result.anotherDeviceJoined || result.userStopped {
                            Logger.info("\(logTag) roomId invalid, hanging up after CallKit answer")
                            await hangupCall(
                                needSyncCallKit: true,
                                isByLocal: true,
                                roomId: roomId,
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

                // Final check after network call completes
                if isFromCallkit, currentCall.roomId == roomId {
                    Logger.info("\(logTag) already answered via CallKit (post-network check), skipping incoming call UI")
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

    /// CallKit 专用接听入口 — 在 Swift concurrency Task 上下文中调用，不经过主线程
    /// 避免 DispatchMainThreadSafe 导致的主线程阻塞，防止 0xBAADCA11 watchdog timeout
    func showAnswerFromCallKit(call: DTLiveKitCallModel) async {
        Logger.info("\(logTag) showAnswerFromCallKit entry")

        await MainActor.run {
            currentCall = call
            hasMeeting = true
            hasTriggeredRating = false
            isFromCallkit = true
        }

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

        Logger.info("\(logTag) answer from CallKit (async path)")

        // ✅ Start answering on cooperative thread pool — not main thread
        answerCall(caller: caller, roomId: roomId, publicKey: publicKey, emk: emk, fromCallKit: true)

        // ✅ MeetingBar DB write is already async internally, fire-and-forget
        Task.detached { [weak self] in
            guard let self else { return }
            await MainActor.run {
                self.handleMeetingBar(call: call, action: .add)
            }
        }

        // ✅ Room validity check — fully detached, doesn't block answering
        Task.detached { [weak self] in
            guard let self else { return }
            if let result = await DTMeetingManager.checkRoomIdValid(roomId) {
                if result.anotherDeviceJoined || result.userStopped {
                    Logger.info("\(self.logTag) roomId invalid, hanging up after CallKit answer")
                    await self.hangupCall(
                        needSyncCallKit: true,
                        isByLocal: true,
                        roomId: roomId,
                        showErrorToast: true
                    )
                }
            }
        }
    }

    @MainActor
    private func presentAnswerVC(call: DTLiveKitCallModel, caller: String, roomId: String, publicKey: Data, emk: Data) {
        let answerVC = DTHostingController(rootView:
            CallAnswerView(
                currentCall: call,
                autoAccept: isFromCallkit,
                isConnecting: isFromCallkit,
                onAnswer: { [weak self] in
                    guard let self else { return }
                    Logger.info("\(logTag) answer from alertView")
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
                }
            ))

        OWSWindowManager.shared().startCall(answerVC, animated: !isFromCallkit)
        self.answerVC = answerVC
    }

    func handleCallError() {
        Logger.error("\(logTag) handleCallError, current state: \(lifecycleState)")
        // 先转到 disconnecting，performCompleteCleanup 会在最后转到 idle
        transitionToDisconnecting()

        // 捕获当前 roomContext 引用，避免清理新创建的 roomContext
        let roomContextToClean = self.roomContext

        DispatchMainThreadSafe { [weak self] in
            Task { @MainActor [weak self] in
                await self?.performCompleteCleanup(roomContextToClean: roomContextToClean)
            }
        }
    }

    private func handleStartCallFailure(error: Error) async {
        Logger.error("\(logTag) Handling start call failure: \(error), current state: \(lifecycleState)")
        // 先转到 disconnecting，performCompleteCleanup 会在最后转到 idle
        transitionToDisconnecting()
        await performCompleteCleanup()
        DispatchMainThreadSafe {
            DTToastHelper.dismiss(withInfo: "Call start failed: \(error.localizedDescription)")
        }
    }

    /// 清理 AnswerVC 状态
    private func clearAnswerVCState() {
        answerVC = nil
    }
}
