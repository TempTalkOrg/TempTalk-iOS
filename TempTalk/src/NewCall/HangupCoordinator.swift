import Foundation
import TTServiceKit

enum HangupReason: String, CustomStringConvertible {
    case localHangup
    case localCancel
    case localReject
    case remoteHangup
    case remoteReject
    case remoteCancel
    case meetingEnded
    case startCallFailed
    case connectError
    case callError
    case appWillTerminate

    var description: String { rawValue }
}

struct TerminationOptions {
    var roomId: String? = nil
    var showErrorToast: Bool = false
    var forceEndGroupMeeting: Bool = false
    var fromCallKit: Bool = false
    var needSyncCallKit: Bool? = nil
}

@MainActor
protocol HangupCoordinatorDependencies: AnyObject {
    var currentCall: DTLiveKitCallModel { get }
    var roomContext: RoomContext? { get set }
    var lifecycleState: DTMeetingManager.MeetingLifecycleState { get }
    var hasEverConnectedToRoom: Bool { get }

    func transitionToDisconnecting()
    func forceTransitionToIdle()
    func sendCallMessage(_ type: DTCallMessageType, forceEndGroupMeeting: Bool) async
    func syncCallKitState(needSyncCallKit: Bool)
    func handleMeetingBar(roomId: String, action: MeetingBarAction, transaction: SDSAnyWriteTransaction?)
    func performResourceCleanup(roomContextToClean: RoomContext?, roomIdToClean: String?) async
    func showErrorToastIfNeeded(_ message: String)
    func onTerminationCompleted()
}

@MainActor
final class HangupCoordinator {
    private weak var deps: HangupCoordinatorDependencies?
    private var isTerminating = false

    nonisolated init(dependencies: HangupCoordinatorDependencies) {
        self.deps = dependencies
    }

    func terminate(reason: HangupReason, options: TerminationOptions = .init()) async {
        guard let deps else { return }

        guard !isTerminating else {
            Logger.info("[HangupCoordinator] already terminating, ignore \(reason)")
            return
        }

        if deps.lifecycleState == .idle, deps.roomContext == nil {
            Logger.info("[HangupCoordinator] already idle, skip \(reason)")
            return
        }

        isTerminating = true
        // 异常安全保险：无论 phase1-7 是否因 Task cancel 或其他原因提前退出，
        // phase8 (state → idle) 必须执行，避免 lifecycleState 卡在 disconnecting 中间态
        defer {
            isTerminating = false
            if let deps = self.deps, deps.lifecycleState != .idle {
                Logger.info("[HangupCoordinator] defer ensuring state idle (was \(deps.lifecycleState))")
                deps.forceTransitionToIdle()
            }
        }

        Logger.info("[HangupCoordinator] start terminate reason=\(reason)")

        let wasConnected = deps.hasEverConnectedToRoom

        phase1_transitionState(reason: reason)
        let contextSnapshot = phase2_captureRoomContext()
        phase3_removeMeetingBar(reason: reason, options: options)
        await phase4_sendMessage(reason: reason, options: options)
        await phase5_disconnectRoom(context: contextSnapshot)
        phase6_syncCallKit(reason: reason, options: options)
        await phase7_releaseResources(context: contextSnapshot, options: options)
        phase8_transitionToIdle()
        phase9_showToastIfNeeded(reason: reason, options: options, wasConnected: wasConnected)

        Logger.info("[HangupCoordinator] terminate completed reason=\(reason)")
    }

    // MARK: - Phase 1

    private func phase1_transitionState(reason: HangupReason) {
        Logger.info("[HangupCoordinator] phase1 transitionState \(reason)")
        deps?.transitionToDisconnecting()
    }

    // MARK: - Phase 2

    private func phase2_captureRoomContext() -> RoomContext? {
        Logger.info("[HangupCoordinator] phase2 captureRoomContext")
        return deps?.roomContext
    }

    // MARK: - Phase 3

    private func phase3_removeMeetingBar(reason: HangupReason, options: TerminationOptions) {
        Logger.info("[HangupCoordinator] phase3 removeMeetingBar \(reason)")
        guard let deps else { return }

        switch reason {
        case .localHangup:
            guard let roomId = options.roomId else { return }
            let shouldRemove = deps.currentCall.callType == .private || options.forceEndGroupMeeting
            if shouldRemove {
                deps.handleMeetingBar(roomId: roomId, action: .remove, transaction: nil)
            }

        case .localCancel, .localReject, .remoteReject, .remoteCancel:
            if deps.currentCall.callType == .private, let roomId = deps.currentCall.roomId {
                deps.handleMeetingBar(roomId: roomId, action: .remove, transaction: nil)
            }

        case .remoteHangup:
            if let roomId = options.roomId, DTParamsUtils.validateString(roomId).boolValue {
                deps.handleMeetingBar(roomId: roomId, action: .remove, transaction: nil)
            }

        case .meetingEnded:
            if let roomId = options.roomId {
                deps.handleMeetingBar(roomId: roomId, action: .remove, transaction: nil)
            }

        case .connectError:
            if let roomId = deps.currentCall.roomId {
                deps.handleMeetingBar(roomId: roomId, action: .remove, transaction: nil)
            }

        case .startCallFailed, .callError, .appWillTerminate:
            break
        }
    }

    // MARK: - Phase 4

    private func phase4_sendMessage(reason: HangupReason, options: TerminationOptions) async {
        Logger.info("[HangupCoordinator] phase4 sendMessage \(reason)")
        guard let deps else { return }

        switch reason {
        case .localHangup:
            if deps.currentCall.callType == .private {
                await deps.sendCallMessage(.hangup, forceEndGroupMeeting: false)
            } else if options.forceEndGroupMeeting {
                await deps.sendCallMessage(.hangup, forceEndGroupMeeting: true)
            }

        case .localCancel:
            if deps.currentCall.callType == .private {
                await deps.sendCallMessage(.cancel, forceEndGroupMeeting: false)
            }

        case .localReject:
            await deps.sendCallMessage(.reject, forceEndGroupMeeting: false)

        case .remoteHangup, .remoteReject, .remoteCancel,
             .meetingEnded, .startCallFailed, .connectError,
             .callError, .appWillTerminate:
            break
        }
    }

    // MARK: - Phase 5

    private func phase5_disconnectRoom(context: RoomContext?) async {
        Logger.info("[HangupCoordinator] phase5 disconnectRoom")
        guard let context else { return }
        await context.disconnect()
    }

    // MARK: - Phase 6

    private func phase6_syncCallKit(reason: HangupReason, options: TerminationOptions) {
        Logger.info("[HangupCoordinator] phase6 syncCallKit \(reason)")

        if let explicit = options.needSyncCallKit {
            deps?.syncCallKitState(needSyncCallKit: explicit)
            return
        }

        let needSync: Bool
        switch reason {
        case .localHangup:       needSync = options.fromCallKit
        case .localCancel:       needSync = false
        case .localReject:       needSync = true
        case .remoteHangup:      needSync = true
        case .remoteReject:      needSync = false
        case .remoteCancel:      needSync = true
        case .meetingEnded:      needSync = true
        case .startCallFailed:   needSync = true
        case .connectError:      needSync = true
        case .callError:         needSync = true
        case .appWillTerminate:  needSync = true
        }

        deps?.syncCallKitState(needSyncCallKit: needSync)
    }

    // MARK: - Phase 7

    private func phase7_releaseResources(context: RoomContext?, options: TerminationOptions) async {
        Logger.info("[HangupCoordinator] phase7 releaseResources")
        await deps?.performResourceCleanup(
            roomContextToClean: context,
            roomIdToClean: options.roomId
        )
    }

    // MARK: - Phase 8

    private func phase8_transitionToIdle() {
        Logger.info("[HangupCoordinator] phase8 transitionToIdle")
        deps?.forceTransitionToIdle()
    }

    // MARK: - Phase 9

    private func phase9_showToastIfNeeded(reason: HangupReason, options: TerminationOptions, wasConnected: Bool) {
        Logger.info("[HangupCoordinator] phase9 showToast \(reason)")

        switch reason {
        case .remoteHangup:
            if wasConnected {
                deps?.showErrorToastIfNeeded(Localized("GROUP_MEETING_OTHER_END_CALL"))
            }

        case .startCallFailed:
            deps?.showErrorToastIfNeeded(Localized("ROOM_CONNECT_FAILED"))

        case .localHangup, .connectError:
            if options.showErrorToast {
                deps?.showErrorToastIfNeeded(Localized("CALL_LIVEKIT_ERROR_TOAST"))
            }

        case .localCancel, .localReject, .remoteReject, .remoteCancel,
             .meetingEnded, .callError, .appWillTerminate:
            break
        }

        deps?.onTerminationCompleted()
    }
}
