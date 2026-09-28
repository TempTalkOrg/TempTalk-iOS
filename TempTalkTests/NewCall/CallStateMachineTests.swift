import XCTest
import Combine
import LiveKit
@testable import Yelling

final class CallStateMachineTests: XCTestCase {

    private var sut: CallStateMachine!
    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        sut = CallStateMachine()
        cancellables = []
    }

    override func tearDown() {
        cancellables = nil
        sut = nil
        super.tearDown()
    }

    // MARK: - 1. Initial state

    func test_initialStateIsIdle() {
        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: - 2. Legal: idle -> connecting

    func test_legalTransition_idleToConnecting() {
        let result = sut.dispatch(.startConnecting)

        XCTAssertTrue(result)
        XCTAssertEqual(sut.state, .connecting)
    }

    // MARK: - 3. Legal: connecting -> connected

    func test_legalTransition_connectingToConnected() {
        sut.dispatch(.startConnecting)

        let result = sut.dispatch(.didConnect)

        XCTAssertTrue(result)
        XCTAssertEqual(sut.state, .connected)
    }

    func test_connectedTransitionRequiresImmediateCallKitAnswerFulfill() {
        var connectedTransition: StateTransition?
        sut.statePublisher
            .sink { transition in
                if transition.to == .connected {
                    connectedTransition = transition
                }
            }
            .store(in: &cancellables)

        sut.dispatch(.startConnecting)
        sut.dispatch(.didConnect)

        XCTAssertEqual(connectedTransition?.shouldFulfillPendingCallKitAnswer, true)
    }

    // MARK: - 4. Legal: connecting -> disconnecting

    func test_legalTransition_connectingToDisconnecting() {
        sut.dispatch(.startConnecting)

        let result = sut.dispatch(.startDisconnecting)

        XCTAssertTrue(result)
        XCTAssertEqual(sut.state, .disconnecting)
    }

    // MARK: - 5. Legal: connected -> disconnecting

    func test_legalTransition_connectedToDisconnecting() {
        sut.dispatch(.startConnecting)
        sut.dispatch(.didConnect)

        let result = sut.dispatch(.startDisconnecting)

        XCTAssertTrue(result)
        XCTAssertEqual(sut.state, .disconnecting)
    }

    // MARK: - 6. Legal: disconnecting -> idle

    func test_legalTransition_disconnectingToIdle() {
        sut.dispatch(.startConnecting)
        sut.dispatch(.didConnect)
        sut.dispatch(.startDisconnecting)

        let result = sut.dispatch(.didDisconnect)

        XCTAssertTrue(result)
        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: - 7. Illegal: idle -> connected

    func test_illegalTransition_idleToConnected() {
        let result = sut.dispatch(.didConnect)

        XCTAssertFalse(result)
        XCTAssertEqual(sut.state, .idle, "State must remain idle after illegal transition")
    }

    // MARK: - 8. Illegal: connected -> connecting

    func test_illegalTransition_connectedToConnecting() {
        sut.dispatch(.startConnecting)
        sut.dispatch(.didConnect)

        let result = sut.dispatch(.startConnecting)

        XCTAssertFalse(result)
        XCTAssertEqual(sut.state, .connected, "State must remain connected after illegal transition")
    }

    // MARK: - 9. Force reset from any active state

    func test_forceReset_fromAnyState() {
        let activeStates: [(String, [CallLifecycleEvent])] = [
            ("connecting", [.startConnecting]),
            ("connected", [.startConnecting, .didConnect]),
            ("disconnecting", [.startConnecting, .didConnect, .startDisconnecting])
        ]

        for (label, events) in activeStates {
            let machine = CallStateMachine()
            var receivedTransition: StateTransition?

            machine.statePublisher
                .sink { receivedTransition = $0 }
                .store(in: &cancellables)

            for event in events {
                machine.dispatch(event)
            }

            let reason = "test reset from \(label)"
            machine.forceReset(reason: reason)

            XCTAssertEqual(machine.state, .idle, "forceReset from \(label) should return to idle")
            XCTAssertEqual(receivedTransition?.to, .idle)
            XCTAssertTrue(receivedTransition?.forced == true, "forceReset transition must be marked forced")
            XCTAssertEqual(receivedTransition?.reason, reason)

            cancellables.removeAll()
        }
    }

    // MARK: - 10. Publisher emits on legal transition

    func test_publisher_emitsOnLegalTransition() {
        var received = [StateTransition]()

        sut.statePublisher
            .sink { received.append($0) }
            .store(in: &cancellables)

        sut.dispatch(.startConnecting)
        sut.dispatch(.didConnect)

        XCTAssertEqual(received.count, 2)

        XCTAssertEqual(received[0].from, .idle)
        XCTAssertEqual(received[0].to, .connecting)
        XCTAssertFalse(received[0].forced)
        XCTAssertNil(received[0].reason)

        XCTAssertEqual(received[1].from, .connecting)
        XCTAssertEqual(received[1].to, .connected)
        XCTAssertFalse(received[1].forced)
    }

    // MARK: - 11. Publisher does NOT emit on illegal transition

    func test_publisher_doesNotEmitOnIllegalTransition() {
        var emitCount = 0

        sut.statePublisher
            .sink { _ in emitCount += 1 }
            .store(in: &cancellables)

        sut.dispatch(.didConnect) // illegal from idle
        sut.dispatch(.startDisconnecting) // illegal from idle
        sut.dispatch(.didDisconnect) // illegal from idle

        XCTAssertEqual(emitCount, 0, "No events should be emitted for illegal transitions")
    }

    // MARK: - 12. Concurrency safety

    func test_concurrency_multipleThreadsDispatch() {
        let iterations = 1000

        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            switch i % 4 {
            case 0: sut.dispatch(.startConnecting)
            case 1: sut.dispatch(.didConnect)
            case 2: sut.dispatch(.startDisconnecting)
            case 3: sut.dispatch(.didDisconnect)
            default: break
            }
        }

        let finalState = sut.state
        let validStates: Set<CallLifecycleState> = [.idle, .connecting, .connected, .disconnecting]
        XCTAssertTrue(validStates.contains(finalState),
                      "Final state \(finalState) must be a valid CallLifecycleState")
    }
}

final class CallDurationGateTimeoutTests: XCTestCase {

    func test_trackSubscribedStartsOnlyAfterGateIsArmed() {
        XCTAssertFalse(
            DTMeetingManager.shouldStartCallDurationTimer(
                isGateArmed: false,
                isMicTrackSubscribed: true,
                didStartTimer: false
            )
        )
        XCTAssertTrue(
            DTMeetingManager.shouldStartCallDurationTimer(
                isGateArmed: true,
                isMicTrackSubscribed: true,
                didStartTimer: false
            )
        )
    }

    func test_trackSubscribedDoesNotRestartTimer() {
        XCTAssertFalse(
            DTMeetingManager.shouldStartCallDurationTimer(
                isGateArmed: true,
                isMicTrackSubscribed: true,
                didStartTimer: true
            )
        )
    }

    func test_staleTimerIsRejectedAfterGateRearmed() {
        let staleTimer = Timer(timeInterval: 5, repeats: false) { _ in }
        let activeTimer = Timer(timeInterval: 5, repeats: false) { _ in }

        XCTAssertFalse(
            DTMeetingManager.shouldHandleCallDurationGateTimeout(
                firedTimer: staleTimer,
                activeTimer: activeTimer,
                isGateArmed: true,
                isInMeeting: true
            )
        )
    }

    func test_currentTimerRequiresArmedGateAndLiveMeeting() {
        let timer = Timer(timeInterval: 5, repeats: false) { _ in }

        XCTAssertTrue(
            DTMeetingManager.shouldHandleCallDurationGateTimeout(
                firedTimer: timer,
                activeTimer: timer,
                isGateArmed: true,
                isInMeeting: true
            )
        )
        XCTAssertFalse(
            DTMeetingManager.shouldHandleCallDurationGateTimeout(
                firedTimer: timer,
                activeTimer: timer,
                isGateArmed: false,
                isInMeeting: true
            )
        )
        XCTAssertFalse(
            DTMeetingManager.shouldHandleCallDurationGateTimeout(
                firedTimer: timer,
                activeTimer: timer,
                isGateArmed: true,
                isInMeeting: false
            )
        )
    }
}

final class MediaSendStatusPresentationTests: XCTestCase {

    func test_mediaConnectingIsNormalAfterRoomIsConnected() {
        XCTAssertEqual(resolve(room: .connected, media: .idle), .none)
        XCTAssertEqual(resolve(room: .connected, media: .connecting), .none)
        XCTAssertEqual(resolve(room: .connected, media: .connected), .none)
    }

    func test_recoveringAndFailedShareMediaRecoveryPresentation() {
        XCTAssertEqual(resolve(room: .connected, media: .recovering), .mediaRecovering)
        XCTAssertEqual(resolve(room: .connected, media: .failed), .mediaRecovering)
    }

    func test_roomRecoveryTakesPriorityOverMediaRecovery() {
        XCTAssertEqual(resolve(room: .connecting, media: .recovering), .roomRecovering)
        XCTAssertEqual(resolve(room: .reconnecting, media: .failed), .roomRecovering)
        XCTAssertEqual(resolve(room: .connected, media: .roomRecovering), .roomRecovering)
    }

    func test_terminalRoomStatesSuppressRecoveryPresentation() {
        for roomState in [ConnectionState.disconnected, .disconnecting] {
            XCTAssertEqual(resolve(room: roomState, media: .roomRecovering), .none)
            XCTAssertEqual(resolve(room: roomState, media: .recovering), .none)
            XCTAssertEqual(resolve(room: roomState, media: .failed), .none)
        }
    }

    private func resolve(
        room: ConnectionState,
        media: MediaSendConnectionState
    ) -> MediaSendStatusPresentation {
        MediaSendStatusPresentation.resolve(
            roomConnectionState: room,
            mediaSendConnectionState: media
        )
    }
}

final class InCallVoiceMemoAudioOwnershipTests: XCTestCase {

    func test_finishPreservesRecordingWhenLiveKitOwnsPublicationThroughout() {
        var sut = InCallVoiceMemoAudioOwnership()
        sut.begin(hasMicrophonePublication: true)

        let action = sut.finish(hasCurrentMicrophonePublication: true)

        XCTAssertEqual(action, .preserveRecording)
    }

    func test_finishStopsRecordingWhenNoPublicationExistedAtStart() {
        var sut = InCallVoiceMemoAudioOwnership()
        sut.begin(hasMicrophonePublication: false)

        let action = sut.finish(hasCurrentMicrophonePublication: true)

        XCTAssertEqual(action, .stopRecording)
    }

    func test_finishStopsRecordingWhenPublicationDisappeared() {
        var sut = InCallVoiceMemoAudioOwnership()
        sut.begin(hasMicrophonePublication: true)

        let action = sut.finish(hasCurrentMicrophonePublication: false)

        XCTAssertEqual(action, .stopRecording)
    }

    func test_finishResetsOwnershipState() {
        var sut = InCallVoiceMemoAudioOwnership()
        sut.begin(hasMicrophonePublication: true)
        _ = sut.finish(hasCurrentMicrophonePublication: true)

        let nextAction = sut.finish(hasCurrentMicrophonePublication: true)

        XCTAssertEqual(nextAction, .stopRecording)
    }
}

final class CallKitMuteActionClassificationTests: XCTestCase {
    func test_withoutPendingAppAction_classifiesNativeAction() {
        XCTAssertEqual(
            DTClassifyCallKitMuteAction(false, false, false, false, false),
            .nativeAction
        )
    }

    func test_exactUUID_classifiesAppCallback() {
        XCTAssertEqual(
            DTClassifyCallKitMuteAction(true, false, true, false, false),
            .appCallback
        )
        XCTAssertEqual(
            DTClassifyCallKitMuteAction(true, true, true, false, false),
            .appCallback
        )
    }

    func test_unsupersededDifferentUUIDWithSameTarget_classifiesSystemEcho() {
        XCTAssertEqual(
            DTClassifyCallKitMuteAction(true, false, false, false, false),
            .sameTargetSystemEcho
        )
        XCTAssertEqual(
            DTClassifyCallKitMuteAction(true, false, false, true, true),
            .sameTargetSystemEcho
        )
    }

    func test_supersededDifferentUUIDWithOriginalTarget_isForwarded() {
        XCTAssertEqual(
            DTClassifyCallKitMuteAction(true, true, false, false, false),
            .oppositeAction
        )
        XCTAssertEqual(
            DTClassifyCallKitMuteAction(true, true, false, true, true),
            .oppositeAction
        )
    }

    func test_differentUUIDWithOppositeTarget_classifiesOppositeAction() {
        XCTAssertEqual(
            DTClassifyCallKitMuteAction(true, false, false, true, false),
            .oppositeAction
        )
        XCTAssertEqual(
            DTClassifyCallKitMuteAction(true, true, false, false, true),
            .oppositeAction
        )
    }
}
