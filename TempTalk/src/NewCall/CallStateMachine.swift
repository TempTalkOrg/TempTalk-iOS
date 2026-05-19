import Foundation
import Combine
import TTServiceKit

// MARK: - State

enum CallLifecycleState: String, Equatable, CustomStringConvertible {
    case idle
    case connecting
    case connected
    case disconnecting

    var description: String { rawValue }
}

// MARK: - Bridge (CallLifecycleState <-> MeetingLifecycleState)

extension CallLifecycleState {
    var legacyValue: DTMeetingManager.MeetingLifecycleState {
        switch self {
        case .idle:           return .idle
        case .connecting:     return .connecting
        case .connected:      return .connected
        case .disconnecting:  return .disconnecting
        }
    }

    init(legacy: DTMeetingManager.MeetingLifecycleState) {
        switch legacy {
        case .idle:           self = .idle
        case .connecting:     self = .connecting
        case .connected:      self = .connected
        case .disconnecting:  self = .disconnecting
        }
    }
}

// MARK: - Event

enum CallLifecycleEvent: String, CustomStringConvertible {
    case startConnecting    // idle → connecting
    case didConnect         // connecting → connected
    case startDisconnecting // connecting | connected → disconnecting
    case didDisconnect      // disconnecting → idle

    var description: String { rawValue }
}

// MARK: - Transition

struct StateTransition: Equatable {
    let from: CallLifecycleState
    let to: CallLifecycleState
    let forced: Bool
    let reason: String?
}

// MARK: - CallStateMachine

final class CallStateMachine {

    // Transition matrix: each state maps to the set of states it may legally move to.
    // `.connecting → .idle` is reserved for forceReset only — never reachable via dispatch(_:).
    private static let legalTransitions: [CallLifecycleState: Set<CallLifecycleState>] = [
        .idle:          [.connecting],
        .connecting:    [.connected, .disconnecting, .idle],
        .connected:     [.disconnecting],
        .disconnecting: [.idle]
    ]

    private let lock = NSRecursiveLock()
    private var _state: CallLifecycleState = .idle
    private let subject = PassthroughSubject<StateTransition, Never>()

    var statePublisher: AnyPublisher<StateTransition, Never> {
        subject.eraseToAnyPublisher()
    }

    var state: CallLifecycleState {
        lock.lock()
        defer { lock.unlock() }
        return _state
    }

    // MARK: - Event-driven dispatch

    /// Dispatch a lifecycle event. Returns true when the transition is legal and applied.
    @discardableResult
    func dispatch(_ event: CallLifecycleEvent) -> Bool {
        let transition: StateTransition? = lock.withLock {
            guard let target = Self.target(for: event, from: _state) else {
                Logger.error("[CallStateMachine] Illegal event \(event) in state \(_state)")
                return nil
            }
            let t = StateTransition(from: _state, to: target, forced: false, reason: nil)
            _state = target
            Logger.info("[CallStateMachine] \(t.from) -> \(t.to) via \(event)")
            return t
        }
        if let transition {
            subject.send(transition)
            return true
        }
        return false
    }

    // MARK: - Legacy bridge (for DTMeetingManager.tryTransition)

    /// Bridge for the old `tryTransition(from:to:)` API.
    /// Converts the (from, to) pair into an event, validates the current state matches `from`,
    /// then dispatches the event.
    @discardableResult
    func dispatchLegacy(
        from expected: DTMeetingManager.MeetingLifecycleState,
        to new: DTMeetingManager.MeetingLifecycleState
    ) -> Bool {
        let expectedState = CallLifecycleState(legacy: expected)
        let newState = CallLifecycleState(legacy: new)

        let transition: StateTransition? = lock.withLock {
            guard _state == expectedState else {
                Logger.error("[CallStateMachine] Legacy transition failed: expected \(expectedState), actual \(_state)")
                return nil
            }
            guard Self.isLegal(from: expectedState, to: newState) else {
                Logger.error("[CallStateMachine] Illegal legacy transition \(expectedState) -> \(newState)")
                return nil
            }
            let t = StateTransition(from: _state, to: newState, forced: false, reason: nil)
            _state = newState
            Logger.info("[CallStateMachine] \(t.from) -> \(t.to) (legacy)")
            return t
        }
        if let transition {
            subject.send(transition)
            return true
        }
        return false
    }

    // MARK: - Force reset

    /// Force the state back to `.idle` regardless of current state. Logs the reason.
    func forceReset(reason: String) {
        let transition: StateTransition = lock.withLock {
            let old = _state
            _state = .idle
            Logger.info("[CallStateMachine] \(old) -> idle (forced: \(reason))")
            return StateTransition(from: old, to: .idle, forced: true, reason: reason)
        }
        subject.send(transition)
    }

    // MARK: - Helpers

    private static func target(for event: CallLifecycleEvent, from state: CallLifecycleState) -> CallLifecycleState? {
        switch (state, event) {
        case (.idle, .startConnecting):         return .connecting
        case (.connecting, .didConnect):        return .connected
        case (.connecting, .startDisconnecting): return .disconnecting
        case (.connected, .startDisconnecting): return .disconnecting
        case (.disconnecting, .didDisconnect):  return .idle
        default:                                return nil
        }
    }

    private static func isLegal(from: CallLifecycleState, to: CallLifecycleState) -> Bool {
        legalTransitions[from]?.contains(to) == true
    }
}
