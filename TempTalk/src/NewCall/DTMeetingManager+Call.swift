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
    /// Non-nil reason when the user's self-hosted proxy is ON but can't carry a private call:
    /// not actually running, missing TURN (`t`) media relay, no usable signaling channel, or the
    /// last reachability probe said unavailable. nil = OK to call. Keyed on `isEnabled` (user
    /// intent), so a call is never silently made direct and leaks the real IP.
    ///
    /// Signaling hides the IP one of two ways: QUIC-over-proxy (MASQUE, share-link `q`, any iOS) or
    /// WSS over the app's loopback CONNECT tunnel. The WSS tunnel relies on URLSession's
    /// `connectionProxyDictionary`, which `URLSessionWebSocketTask` only honors on iOS 17+; on older
    /// iOS it is silently ignored and the WebSocket connects directly. So without `q`, a call is only
    /// allowed on iOS 17+ — otherwise blocked, never leaked.
    var proxyCallBlockReason: String? {
        // In-call IP protection off → calls go direct (proxy doesn't carry them), so never block.
        guard ProxyManager.shared.protectCallIPEnabled else { return nil }
        guard ProxyManager.shared.isEnabled else { return nil }
        guard let cfg = ProxyManager.shared.activeConfig else { return "proxy not running" }
        if cfg.turnEnabled() == false { return "no TURN (t)" }
        // Signaling targets come exclusively from the call tunnel whitelist. If it resolved to no
        // host, MeetingConnectionPlanner builds zero attempts and the coordinator would spin through
        // every retry phase to a generic timeout — block early with the same proxy guidance instead.
        if ProxyTunnelConfig.tunnelDomains("call").isEmpty { return "no call tunnel domains" }
        if cfg.quicEnabled == false {
            guard #available(iOS 17, *) else { return "no QUIC relay (q); WSS proxy needs iOS 17+" }
        }
        if ProxyManager.shared.lastProbeStatus == .unavailable { return "proxy unavailable" }
        return nil
    }

    func startCall(thread: TSThread?,
                   recipientIds: [String]? = nil,
                   displayLoading: Bool = false)
    {
        Logger.info("\(logTag) start call with direct LiveKit connection, current state: \(lifecycleState)")

        // Block at the initiation entry — before any state change or call UI — so the tip lands on
        // the conversation page and persists, instead of flashing by on a call screen that is then
        // torn down. The deeper connect path keeps the same guard for the answer path.
        if let reason = proxyCallBlockReason {
            Logger.warn("\(logTag) startCall blocked: proxy on but unusable — \(reason)")
            DispatchMainThreadSafe {
                DTToastHelper.hide()
                DTToastHelper.show(withInfo: Localized("CALL_PROXY_TURN_REQUIRED_TIP"))
            }
            return
        }

        // TODO: 补丁代码——根因未定位，加详细日志收集线上数据后彻底根除
        if lifecycleState != .idle && roomContext == nil {
            Logger.error("\(logTag) [lifecycle-patch][startCall] stuck state=\(lifecycleState) roomContext=nil, last_fromSource=\(fromSource ?? "nil") isFromCallkit=\(isFromCallkit) isAnswering=\(isAnswering) currentCall.roomId=\(currentCall.roomId ?? "nil"); forcing reset")
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
                SDSDatabaseStorage.shared.read { tx in
                    roomName = DTGroupCryptoDisplayHelper.shared.resolveGroupDisplayName(
                        serverGroupId: groupThread.serverThreadId,
                        fallbackName: "",
                        transaction: tx)
                }
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
            if fromCallKit, let callKitUUID = currentCall.callKitUUID {
                DTCallKitManager.shared().endCallAction(callKitUUID, onlyForCallKit: true)
            }
            return
        }

        isAnswering = true

        if lifecycleState == .disconnecting || lifecycleState == .connected {
            let roomGone = roomContext == nil || roomContext?.room.connectionState == .disconnected
            if roomGone {
                Logger.error("\(logTag) [lifecycle-patch][acceptCall] stuck state=\(lifecycleState) roomContext=\(roomContext == nil ? "nil" : "disconnected"), last_fromSource=\(fromSource ?? "nil") isFromCallkit=\(isFromCallkit) isAnswering=\(isAnswering) currentCall.roomId=\(currentCall.roomId ?? "nil"); forcing reset")
                forceTransition(to: .idle)
            }
        }

        let currentState = lifecycleState
        guard currentState == .idle || currentState == .connecting else {
            DispatchMainThreadSafe {
                DTToastHelper.hide()
                DTToastHelper.dismiss(withInfo: Localized("ROOM_CONNECT_FAILED"))
            }
            Logger.error("\(logTag) cannot accept call, current state: \(currentState)")
            isAnswering = false
            if fromCallKit, let callKitUUID = currentCall.callKitUUID {
                DTCallKitManager.shared().endCallAction(callKitUUID, onlyForCallKit: true)
            }
            return
        }

        // 如果是 idle 状态，转换到 connecting
        if currentState == .idle {
            tryTransition(from: .idle, to: .connecting)
        }

        // 优先挂断callkit，走正常入会流程
        if !fromCallKit {
            let ckManager = DTCallKitManager.shared()
            let trackedUUID = currentCall.callKitUUID
            if let callKitUUID = trackedUUID {
                Logger.info("\(logTag) endCall uuid: \(callKitUUID)")
                ckManager.endCallAction(callKitUUID, onlyForCallKit: true)
            }

            if let stuckUUID = ckManager.uuidString(fromRoomId: roomId),
               stuckUUID != trackedUUID {
                Logger.info("\(logTag) endCall stuck uuid by roomId: \(stuckUUID)")
                ckManager.endCallAction(stuckUUID, onlyForCallKit: true)
            }
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
                if fromCallKit, let callKitUUID = currentCall.callKitUUID {
                    await MainActor.run {
                        DTCallKitManager.shared().endCallAction(callKitUUID, onlyForCallKit: true)
                    }
                }
                return
            }

            await ensureCleanConnectionState(roomId: capturedRoomId)

            guard lifecycleState == .connecting else {
                Logger.warn("\(logTag) state changed during cleanup, aborting acceptCall")
                isAnswering = false
                if fromCallKit, let callKitUUID = currentCall.callKitUUID {
                    await MainActor.run {
                        DTCallKitManager.shared().endCallAction(callKitUUID, onlyForCallKit: true)
                    }
                }
                return
            }

            await MainActor.run { [weak self] in
                self?.startConnectionPhaseTimer()
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

        // Defense-in-depth for the answer/other paths: never connect a call while the proxy is on
        // but unusable, which would leak the real IP via a direct connection.
        // The initiate path is already blocked earlier in startCall (toast on the conversation page).
        if let reason = proxyCallBlockReason {
            Logger.warn("\(logTag) call blocked: proxy on but unusable — \(reason)")
            await MainActor.run {
                DTToastHelper.hide()
                DTToastHelper.show(withInfo: Localized("CALL_PROXY_TURN_REQUIRED_TIP"))
            }
            isAnswering = false
            await hangupCall(needSyncCallKit: fromCallKit,
                             isByLocal: true,
                             forceEndGroupMeeting: false,
                             roomId: currentCall.roomId,
                             showErrorToast: false)
            return
        }

        do {
            currentCall.timestamp = timestamp

            let token = try await requestAuthToken()
            let collapseId = collapseId(timestamp: timestamp)

            // 失败不阻塞，coordinator 内部还会再尝试 fetch / assets 兜底
            _ = try? await CallServiceUrlManager.shared.ensureServiceUrlsForCall(timeout: 15)

            let baseOptions = buildBaseConnectOptions(
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

            if !skipCleanup {
                await ensureCleanConnectionState(roomId: roomId)
            }

            guard lifecycleState == .connecting else {
                Logger.warn("\(logTag) connectDirectlyToLiveKit aborted: state=\(lifecycleState) is not .connecting, call was cancelled during async wait")
                isAnswering = false
                return
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

            // 先出 UI
            await MainActor.run {
                DTToastHelper.hide()
                presentCallUI(callType: callType, isCaller: isCaller, fromCallKit: fromCallKit)
            }

            await connectRoomViaCoordinator(fromCallKit: fromCallKit, baseConnectOptions: baseOptions)

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

    /// transport / serverHost / caCertPem / cidTag / deviceType 由 RoomContext.connect 按 attempt 套上。
    private func buildBaseConnectOptions(
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
        let ttCallRequest: Livekit_TTCallRequest?
        if let cipherMessages, let encInfos, let publicKey {
            ttCallRequest = Livekit_TTCallRequest.with {
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
            }
        } else if let roomId {
            ttCallRequest = Livekit_TTCallRequest.with {
                $0.token = token
                $0.startCall = Livekit_TTStartCall.with {
                    $0.type = callType.rawValue
                    $0.roomID = roomId
                    $0.version = Self.meetingVersion
                    $0.timestamp = Int64(timestamp)
                }
                $0.userAgent = TSConstants.appUserAgent
            }
        } else {
            return ConnectOptions()
        }

        return ConnectOptions(
            autoSubscribe: true,
            reconnectAttempts: 20,
            reconnectAttemptDelay: 2,
            ttCallRequest: ttCallRequest,
            userAgent: TSConstants.appUserAgent
        )
    }

    /// `+73504107953` -> `73504107953`
    static func quicCidTag(for localNumber: String?) -> String {
        guard let number = localNumber, !number.isEmpty else { return "" }
        return number.hasPrefix("+") ? String(number.dropFirst()) : number
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
            await roomContext.disconnect()
            self.roomContext = nil
            Logger.info("\(logTag) disconnect completed, roomContext cleared")
        }

        if lifecycleState != .idle {
            Logger.info("\(logTag) ensureCleanConnectionState syncing state \(lifecycleState) -> idle")
            forceTransition(to: .idle)
        }
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

        roomContext = RoomContext(token: token, lkContext: appContext)
        Logger.info("\(logTag) created new roomContext (attempt-driven)")
        return true
    }

    @MainActor
    private func presentCallUI(callType: CallType, isCaller: Bool, fromCallKit: Bool) {
        if isCaller {
            let reachable = Reachability.forInternetConnection()?.isReachable() ?? false
            if !reachable {
                DTToastHelper.show(withInfo: Localized("SINGLE_CALL_CALLER_NETWORK_ABNORMAL"))
            }
        }

        guard let appContext, let roomContext else {
            Logger.info("\(logTag) appcontext roomContext init exception")
            DTToastHelper.show(withInfo: Localized("ERROR_DESCRIPTION_UNKNOWN_ERROR"))
            return
        }

        let contextView = RoomContextView()
            .environmentObject(appContext)
            .environmentObject(roomContext)
            .environmentObject(roomContext.room)

        let callVC = DTHostingController(rootView: AnyView(contextView))
        hostRoomContentVC = callVC
        tryTransition(from: .idle, to: .connecting)

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
            // Push the real call UI as soon as it's ready. answerVC is already the root of
            // callNavigationController (set synchronously in startCall), so no wait is needed.
            if let answerVC, let nav = answerVC.navigationController {
                nav.pushViewController(callVC, animated: false, completion: { [weak self] in
                    guard let self else { return }
                    Logger.info("\(logTag) answer nav removeViewController")
                    answerVC.navigationController?.removeViewController(ofType: type(of: answerVC))
                    self.answerVC = nil
                })
            } else {
                if answerVC != nil {
                    Logger.error("\(logTag) answer nav nil")
                } else {
                    Logger.info("\(logTag) isCaller = false, startCall")
                }
                self.answerVC = nil
                OWSWindowManager.shared().startCall(callVC, animated: false)
            }
        }
    }

    @MainActor
    private func connectRoomViaCoordinator(fromCallKit: Bool, baseConnectOptions: ConnectOptions) async {
        Logger.info("\(logTag) starting LiveKit connection via CallConnectionCoordinator")
        guard let roomContext else {
            Logger.error("\(logTag) connectRoomViaCoordinator: roomContext is nil, aborting")
            isAnswering = false
            await hangupCall(needSyncCallKit: fromCallKit,
                             isByLocal: true,
                             roomId: currentCall.roomId,
                             showErrorToast: true)
            return
        }

        let coordinator = CallConnectionCoordinator()
        do {
            _ = try await coordinator.connectToRoomWithFailover(
                connectAttempt: { [weak roomContext] attempt in
                    guard let roomContext else { throw CallError.roomContextCreationFailed }
                    _ = try await roomContext.connect(
                        fromCallKit: fromCallKit,
                        attempt: attempt,
                        baseConnectOptions: baseConnectOptions
                    )
                },
                reporter: CallStatisticsLogManager.shared
            )

            let state = roomContext.room.connectionState
            if state != .connected {
                Logger.error("\(logTag) coordinator returned success but room state=\(state), treating as failure")
                throw CallError.connectionFailed
            }
        } catch is CancellationError {
            Logger.info("\(logTag) room connect cancelled, skip hangup")
            isAnswering = false
        } catch {
            Logger.info("\(logTag) coordinator failover exhausted, error: \(error)")
            isAnswering = false
            let failedRoomId = currentCall.roomId
            let isPrivateCaller = currentCall.callType == .private && currentCall.isCaller
            await hangupCall(needSyncCallKit: fromCallKit,
                             isByLocal: true,
                             roomId: failedRoomId)
            if let lkError = error as? LiveKitError, lkError.type == .startCall {
                if lkError.response?.base.status == 22001 {
                    if let roomId = failedRoomId {
                        handleMeetingBar(roomId: roomId, action: .remove)
                    }
                    await DTToastHelper.dismiss(withInfo: Localized("CALL_NO_CONNECT_ENDED"))
                } else {
                    await DTToastHelper.dismiss(withInfo: lkError.response?.base.reason ?? Localized("ROOM_CONNECT_FAILED"))
                }
            } else if case CallError.tokenExpired = error, isPrivateCaller {
                await DTToastHelper.dismiss(withInfo: Localized("SINGLE_CALL_TIMEOUT"))
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
        tryTransition(from: .idle, to: .connecting)
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
                    if DTMeetingManager.isVoiceRecordingActive {
                        self.presentIncomingCallBanner(call: call, caller: caller, roomId: roomId, publicKey: publicKey, emk: emk)
                    } else {
                        self.presentAnswerVC(call: call, caller: caller, roomId: roomId, publicKey: publicKey, emk: emk)
                    }
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
            tryTransition(from: .idle, to: .connecting)
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

        // MeetingBar DB write is already async internally, fire-and-forget
        Task { [weak self] in
            guard let self else { return }
            await MainActor.run {
                self.handleMeetingBar(call: call, action: .add)
            }
        }

        // Room validity check — doesn't block answering
        Task { [weak self] in
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
        Task { [weak self] in
            await self?.hangupCoordinator.terminate(reason: .callError)
        }
    }

    private func handleStartCallFailure(error: Error) async {
        Logger.error("\(logTag) Handling start call failure: \(error), current state: \(lifecycleState)")
        await hangupCoordinator.terminate(reason: .startCallFailed)
    }

    /// 清理 AnswerVC 状态
    private func clearAnswerVCState() {
        answerVC = nil
    }

    // MARK: - Incoming Call Banner (during voice recording)

    @MainActor
    private func presentIncomingCallBanner(call: DTLiveKitCallModel, caller: String, roomId: String, publicKey: Data, emk: Data) {
        Logger.info("\(logTag) presenting incoming call banner (voice recording active)")

        deferredIncomingCall = (call, caller, roomId, publicKey, emk)

        let bannerView = IncomingCallBannerView(
            callerName: contactsManager.displayName(forPhoneIdentifier: caller),
            callerId: caller,
            isGroupCall: call.callType != .private,
            onAnswer: { [weak self] in
                guard let self, let deferred = consumeDeferredCall() else { return }
                stopCallTimeoutTimer()
                answerCall(caller: deferred.caller, roomId: deferred.roomId, publicKey: deferred.publicKey, emk: deferred.emk, fromCallKit: false)
            },
            onDecline: { [weak self] in
                guard let self, let deferred = consumeDeferredCall() else { return }
                stopCallTimeoutTimer()
                if deferred.call.callType != .private {
                    handleMeetingBar(call: deferred.call, action: .add)
                }
                Task { await self.rejectRemoteCall() }
            }
        )

        let hostingVC = UIHostingController(rootView: bannerView)
        hostingVC.view.backgroundColor = .clear

        let window = UIWindow(frame: UIScreen.main.bounds)
        window.windowLevel = .alert + 1
        window.rootViewController = hostingVC
        window.backgroundColor = .clear
        window.makeKeyAndVisible()
        incomingCallBannerWindow = window

        voiceRecordingEndObserver = NotificationCenter.default.addObserver(
            forName: .voiceRecordingDidEnd,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onVoiceRecordingEnded()
        }
    }

    /// Consumes the deferred incoming call and dismisses the banner. Returns the call info, or nil if already consumed.
    @MainActor
    private func consumeDeferredCall() -> (call: DTLiveKitCallModel, caller: String, roomId: String, publicKey: Data, emk: Data)? {
        guard let deferred = deferredIncomingCall else { return nil }
        deferredIncomingCall = nil
        dismissIncomingCallBanner()
        return deferred
    }

    @MainActor
    func dismissIncomingCallBanner() {
        if let observer = voiceRecordingEndObserver {
            NotificationCenter.default.removeObserver(observer)
            voiceRecordingEndObserver = nil
        }
        incomingCallBannerWindow?.isHidden = true
        incomingCallBannerWindow = nil
    }

    @MainActor
    private func onVoiceRecordingEnded() {
        guard let deferred = consumeDeferredCall() else { return }
        Logger.info("\(logTag) voice recording ended, presenting deferred incoming call UI")
        presentAnswerVC(call: deferred.call, caller: deferred.caller, roomId: deferred.roomId, publicKey: deferred.publicKey, emk: deferred.emk)
    }
}
