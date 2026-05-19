import XCTest
@testable import Yelling

// MARK: - Mock

@MainActor
final class MockHangupCoordinatorDependencies: HangupCoordinatorDependencies {

    enum Invocation: Equatable {
        case transitionToDisconnecting
        case forceTransitionToIdle
        case sendCallMessage(DTCallMessageType, Bool)
        case syncCallKit(Bool)
        case handleMeetingBar(String, MeetingBarAction)
        case performResourceCleanup
        case showErrorToast(String)
        case onTerminationCompleted
    }

    var invocations: [Invocation] = []

    var currentCall: DTLiveKitCallModel = DTLiveKitCallModel()
    var roomContext: RoomContext?
    var hasEverConnectedToRoom: Bool = false

    private var _lifecycleState: DTMeetingManager.MeetingLifecycleState = .connecting
    var lifecycleState: DTMeetingManager.MeetingLifecycleState { _lifecycleState }

    func setLifecycleState(_ state: DTMeetingManager.MeetingLifecycleState) {
        _lifecycleState = state
    }

    func transitionToDisconnecting() {
        invocations.append(.transitionToDisconnecting)
        _lifecycleState = .disconnecting
    }

    func forceTransitionToIdle() {
        invocations.append(.forceTransitionToIdle)
        _lifecycleState = .idle
    }

    func sendCallMessage(_ type: DTCallMessageType, forceEndGroupMeeting: Bool) async {
        invocations.append(.sendCallMessage(type, forceEndGroupMeeting))
    }

    func syncCallKitState(needSyncCallKit: Bool) {
        invocations.append(.syncCallKit(needSyncCallKit))
    }

    func handleMeetingBar(roomId: String, action: MeetingBarAction, transaction: SDSAnyWriteTransaction?) {
        invocations.append(.handleMeetingBar(roomId, action))
    }

    func performResourceCleanup(roomContextToClean: RoomContext?, roomIdToClean: String?) async {
        invocations.append(.performResourceCleanup)
    }

    func showErrorToastIfNeeded(_ message: String) {
        invocations.append(.showErrorToast(message))
    }

    func onTerminationCompleted() {
        invocations.append(.onTerminationCompleted)
    }
}

// MARK: - Tests

@MainActor
final class HangupCoordinatorTests: XCTestCase {

    private var sut: HangupCoordinator!
    private var mock: MockHangupCoordinatorDependencies!

    override func setUp() {
        super.setUp()
        mock = MockHangupCoordinatorDependencies()
        sut = HangupCoordinator(dependencies: mock)
    }

    override func tearDown() {
        sut = nil
        mock = nil
        super.tearDown()
    }

    // MARK: - 1. Initial state

    func test_initialStateIsNotTerminating() async {
        mock.setLifecycleState(.idle)
        // Coordinator should skip when idle + no roomContext
        await sut.terminate(reason: .localHangup)
        XCTAssertTrue(mock.invocations.isEmpty, "Should skip when already idle")
    }

    // MARK: - 2. Full sequence for localHangup

    func test_terminateLocalHangup_fullSequence() async {
        mock.setLifecycleState(.connected)
        mock.currentCall.callType = .private
        mock.currentCall.roomId = "room-1"

        await sut.terminate(
            reason: .localHangup,
            options: TerminationOptions(roomId: "room-1")
        )

        XCTAssertTrue(mock.invocations.contains(.transitionToDisconnecting))
        XCTAssertTrue(mock.invocations.contains(.sendCallMessage(.hangup, false)))
        XCTAssertTrue(mock.invocations.contains(.handleMeetingBar("room-1", .remove)))
        XCTAssertTrue(mock.invocations.contains(.syncCallKit(false)))
        XCTAssertTrue(mock.invocations.contains(.performResourceCleanup))
        XCTAssertTrue(mock.invocations.contains(.forceTransitionToIdle))
        XCTAssertTrue(mock.invocations.contains(.onTerminationCompleted))

        let transitionIdx = mock.invocations.firstIndex(of: .transitionToDisconnecting)!
        let idleIdx = mock.invocations.firstIndex(of: .forceTransitionToIdle)!
        XCTAssertTrue(transitionIdx < idleIdx, "Phase ordering: phase1 before phase8")
    }

    // MARK: - 3. localCancel sends cancel message

    func test_terminateLocalCancel_sendsCancelMessage() async {
        mock.setLifecycleState(.connecting)
        mock.currentCall.callType = .private
        mock.currentCall.roomId = "room-2"

        await sut.terminate(reason: .localCancel)

        XCTAssertTrue(mock.invocations.contains(.sendCallMessage(.cancel, false)))
        XCTAssertFalse(mock.invocations.contains(.sendCallMessage(.hangup, false)))
    }

    // MARK: - 4. localReject sends reject message

    func test_terminateLocalReject_sendsRejectMessage() async {
        mock.setLifecycleState(.connecting)

        await sut.terminate(reason: .localReject)

        XCTAssertTrue(mock.invocations.contains(.sendCallMessage(.reject, false)))
    }

    // MARK: - 5. remoteHangup does not send message

    func test_terminateRemoteHangup_doesNotSendMessage() async {
        mock.setLifecycleState(.connected)

        await sut.terminate(reason: .remoteHangup, options: TerminationOptions(roomId: "room-3"))

        let sendInvocations = mock.invocations.filter {
            if case .sendCallMessage = $0 { return true }
            return false
        }
        XCTAssertTrue(sendInvocations.isEmpty, "remoteHangup should not send any message")
    }

    // MARK: - 6. remoteHangup shows toast when wasInMeeting

    func test_terminateRemoteHangup_showsToastWhenWasInMeeting() async {
        mock.setLifecycleState(.connected)
        mock.hasEverConnectedToRoom = true

        await sut.terminate(reason: .remoteHangup, options: TerminationOptions(roomId: "room-4"))

        let toastInvocations = mock.invocations.filter {
            if case .showErrorToast = $0 { return true }
            return false
        }
        XCTAssertFalse(toastInvocations.isEmpty, "remoteHangup with wasConnected should show toast")
        XCTAssertTrue(mock.invocations.contains(.onTerminationCompleted))
    }

    // MARK: - 7. startCallFailed skips disconnect (no roomContext)

    func test_terminateStartCallFailed_skipsDisconnect() async {
        mock.setLifecycleState(.connecting)
        mock.roomContext = nil

        await sut.terminate(reason: .startCallFailed)

        XCTAssertTrue(mock.invocations.contains(.transitionToDisconnecting))
        XCTAssertTrue(mock.invocations.contains(.performResourceCleanup))
        XCTAssertTrue(mock.invocations.contains(.forceTransitionToIdle))
    }

    // MARK: - 8. appWillTerminate minimal phase set

    func test_terminateAppTerminate_minimalPhaseSet() async {
        mock.setLifecycleState(.connected)

        await sut.terminate(reason: .appWillTerminate)

        XCTAssertTrue(mock.invocations.contains(.transitionToDisconnecting))
        XCTAssertTrue(mock.invocations.contains(.performResourceCleanup))
        XCTAssertTrue(mock.invocations.contains(.forceTransitionToIdle))

        let meetingBarInvocations = mock.invocations.filter {
            if case .handleMeetingBar = $0 { return true }
            return false
        }
        XCTAssertTrue(meetingBarInvocations.isEmpty, "appWillTerminate should not touch meetingBar")

        let sendInvocations = mock.invocations.filter {
            if case .sendCallMessage = $0 { return true }
            return false
        }
        XCTAssertTrue(sendInvocations.isEmpty, "appWillTerminate should not send messages")
    }

    // MARK: - 9. Idempotent: concurrent (gate 1)

    func test_terminate_idempotent_concurrent() async {
        mock.setLifecycleState(.connected)

        async let first: () = sut.terminate(reason: .localHangup, options: TerminationOptions(roomId: "r"))
        async let second: () = sut.terminate(reason: .localHangup, options: TerminationOptions(roomId: "r"))

        _ = await (first, second)

        let transitionCount = mock.invocations.filter { $0 == .transitionToDisconnecting }.count
        XCTAssertEqual(transitionCount, 1, "Only one terminate should execute")
    }

    // MARK: - 10. Idempotent: sequential (gate 2)

    func test_terminate_idempotent_sequential() async {
        mock.setLifecycleState(.connected)

        await sut.terminate(reason: .localHangup, options: TerminationOptions(roomId: "r"))
        // After first terminate, mock state is idle and roomContext is nil
        let countBefore = mock.invocations.count

        await sut.terminate(reason: .localHangup, options: TerminationOptions(roomId: "r"))

        XCTAssertEqual(mock.invocations.count, countBefore, "Second call should be no-op (gate 2)")
    }

    // MARK: - 11. MeetingBar: 1v1 localHangup removes bar

    func test_terminate_meetingBarRule_1v1_localHangup() async {
        mock.setLifecycleState(.connected)
        mock.currentCall.callType = .private

        await sut.terminate(
            reason: .localHangup,
            options: TerminationOptions(roomId: "room-5")
        )

        XCTAssertTrue(mock.invocations.contains(.handleMeetingBar("room-5", .remove)))
    }

    // MARK: - 12. MeetingBar: group localHangup without force keeps bar

    func test_terminate_meetingBarRule_group_localHangup_noForce() async {
        mock.setLifecycleState(.connected)
        mock.currentCall.callType = .group

        await sut.terminate(
            reason: .localHangup,
            options: TerminationOptions(roomId: "room-6", forceEndGroupMeeting: false)
        )

        let barInvocations = mock.invocations.filter {
            if case .handleMeetingBar = $0 { return true }
            return false
        }
        XCTAssertTrue(barInvocations.isEmpty, "Group hangup without force should NOT remove bar")
    }

    // MARK: - 13. MeetingBar: group localHangup with force removes bar

    func test_terminate_meetingBarRule_group_localHangup_force() async {
        mock.setLifecycleState(.connected)
        mock.currentCall.callType = .group

        await sut.terminate(
            reason: .localHangup,
            options: TerminationOptions(roomId: "room-7", forceEndGroupMeeting: true)
        )

        XCTAssertTrue(mock.invocations.contains(.handleMeetingBar("room-7", .remove)))
    }

    // MARK: - 14. MeetingBar: remoteHangup always removes bar

    func test_terminate_meetingBarRule_remoteHangup_always() async {
        mock.setLifecycleState(.connected)
        mock.currentCall.callType = .group

        await sut.terminate(
            reason: .remoteHangup,
            options: TerminationOptions(roomId: "room-8")
        )

        XCTAssertTrue(mock.invocations.contains(.handleMeetingBar("room-8", .remove)))
    }

    // MARK: - 15. Error toast with showErrorToast flag

    func test_terminate_errorToast_showsLivekitToast() async {
        mock.setLifecycleState(.connected)

        await sut.terminate(
            reason: .localHangup,
            options: TerminationOptions(roomId: "r", showErrorToast: true)
        )

        let toastInvocations = mock.invocations.filter {
            if case .showErrorToast = $0 { return true }
            return false
        }
        XCTAssertFalse(toastInvocations.isEmpty, "showErrorToast=true should show toast")
    }

    // MARK: - 16. State transitions to idle after terminate

    func test_terminate_stateTransition_idleAfter() async {
        mock.setLifecycleState(.connected)

        await sut.terminate(reason: .localHangup, options: TerminationOptions(roomId: "r"))

        XCTAssertEqual(mock.lifecycleState, .idle)
    }
}
