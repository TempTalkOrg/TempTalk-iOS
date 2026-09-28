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

    /// CallKit answer fulfillment is a prerequisite for iOS to activate the call audio session.
    /// Waiting for media readiness here would deadlock microphone publication behind the held
    /// `CXAnswerCallAction`, so the room-connected transition is the release point.
    var shouldFulfillPendingCallKitAnswer: Bool {
        to == .connected
    }
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

// MARK: - Call type state machine

enum CallTypeResolutionSource: Equatable {
    case legacy
    case roomMetadata(CallType)
    case localInstantOverride
    case instantLatched
}

extension CallTypeResolutionSource: CustomStringConvertible {
    /// Logs the wire value (`1on1`) rather than the Swift case name (`private`), so diagnostics
    /// match the terminology used by the server and the other clients.
    var description: String {
        switch self {
        case .legacy:
            return "legacy"
        case let .roomMetadata(callType):
            return "roomMetadata(\(callType.rawValue))"
        case .localInstantOverride:
            return "localInstantOverride"
        case .instantLatched:
            return "instantLatched"
        }
    }
}

struct CallTypeResolutionState: Equatable {
    let source: CallTypeResolutionSource
    let effectiveType: CallType
}

struct CallTypeTransition: Equatable {
    let from: CallTypeResolutionState
    let to: CallTypeResolutionState
}

/// Keeps the server-provided room call type and the legacy local inference in parallel.
///
/// The server value is only consulted for calls that started as 1v1: "this became instant while I
/// was not looking" is the one type change a client cannot detect on its own, because a second
/// device of the same peer takes its own participant slot. Group and instant calls have no such
/// blind spot and stay on the legacy inference.
///
/// Instant is terminal — the type is only ever corrected downwards — and the legacy inference,
/// itself monotonic, takes over whenever metadata is absent, unusable or not applicable.
final class CallTypeStateMachine {
    private(set) var authoritativeCallType: CallType?
    private(set) var state: CallTypeResolutionState

    private let initialLegacyType: CallType
    private var legacyType: CallType
    /// Set as soon as any resolution yields instant; from then on instant is the answer.
    private var hasLatchedInstant = false
    private let subject = PassthroughSubject<CallTypeTransition, Never>()

    var statePublisher: AnyPublisher<CallTypeTransition, Never> {
        subject.eraseToAnyPublisher()
    }

    init(initialCallType: CallType) {
        initialLegacyType = initialCallType
        legacyType = initialCallType
        state = CallTypeResolutionState(source: .legacy, effectiveType: initialCallType)
    }

    /// The source call type still owns connection/message side effects even when the
    /// effective UI type is locally corrected to instant.
    var connectionFlowType: CallType {
        initialLegacyType
    }

    var usesOneToOneConnectionFlow: Bool {
        connectionFlowType == .private
    }

    /// Stores the latest metadata value (including nil) and resolves the effective type.
    /// A nil value deliberately returns control to the preserved legacy inference.
    func ingest(
        metadataCallType: CallType?,
        participantCount: Int,
        isSelfInGroup: Bool
    ) -> CallTypeTransition? {
        authoritativeCallType = metadataCallType
        return resolve(participantCount: participantCount, isSelfInGroup: isSelfInGroup)
    }

    /// Records a deliberate local 1on1/group -> instant conversion.
    ///
    /// Latching here means a stale 1on1 metadata value arriving while the server update is
    /// in flight can no longer undo the upgrade. Keeping `legacyType` in sync mirrors it
    /// into the fallback used when metadata is absent or unparsable.
    func forceInstantForLocalUpgrade() -> CallTypeTransition? {
        hasLatchedInstant = true
        legacyType = .instant
        return transition(
            to: CallTypeResolutionState(
                source: .localInstantOverride,
                effectiveType: .instant
            )
        )
    }

    /// Re-evaluates participant/group corrections without changing the latest metadata value.
    func reevaluate(
        participantCount: Int,
        isSelfInGroup: Bool
    ) -> CallTypeTransition? {
        resolve(participantCount: participantCount, isSelfInGroup: isSelfInGroup)
    }

    private func resolve(
        participantCount: Int,
        isSelfInGroup: Bool
    ) -> CallTypeTransition? {
        // Snapshot before updateLegacyType, which may latch on its own: the latch only decides
        // *this* resolution if it was already set on entry. Otherwise a downgrade happening now
        // would report `instantLatched` and hide where the instant actually came from.
        let wasLatched = hasLatchedInstant
        updateLegacyType(participantCount: participantCount, isSelfInGroup: isSelfInGroup)

        let nextState: CallTypeResolutionState
        if wasLatched {
            // Terminal: neither a shrinking participant count nor a stale 1on1/group
            // metadata value may promote the call back.
            nextState = CallTypeResolutionState(
                source: .instantLatched,
                effectiveType: .instant
            )
        } else if let authoritativeCallType,
                  let effectiveType = resolveAuthoritativeType(
                      authoritativeCallType,
                      participantCount: participantCount
                  ) {
            // Instant reached through the authoritative value — whether the server said so
            // outright or the local correction did — is final.
            if effectiveType == .instant {
                hasLatchedInstant = true
            }
            nextState = CallTypeResolutionState(
                source: .roomMetadata(authoritativeCallType),
                effectiveType: effectiveType
            )
        } else {
            nextState = CallTypeResolutionState(source: .legacy, effectiveType: legacyType)
        }

        return transition(to: nextState)
    }

    private func transition(to nextState: CallTypeResolutionState) -> CallTypeTransition? {
        let previousState = state
        state = nextState

        // Source-only changes do not affect UI or interaction semantics.
        guard previousState.effectiveType != nextState.effectiveType else {
            return nil
        }
        let transition = CallTypeTransition(from: previousState, to: nextState)
        subject.send(transition)
        return transition
    }

    /// A legacy downgrade also latches: it means a third party really did join (or we left
    /// the group), which is exactly the irreversible condition. An initial type that merely
    /// happens to be instant does not latch, so late metadata can still correct it to group.
    ///
    /// `isSelfInGroup` reads as "not a *certain* outsider" (see `DTMeetingManager.groupMembership`):
    /// an undecidable verdict arrives as true, so only a real roster missing us downgrades the call.
    private func updateLegacyType(participantCount: Int, isSelfInGroup: Bool) {
        switch legacyType {
        case .private where participantCount > 2:
            legacyType = .instant
            hasLatchedInstant = true
        case .group where !isSelfInGroup:
            legacyType = .instant
            hasLatchedInstant = true
        default:
            break
        }
    }

    /// Answers exactly one question: has this 1v1 call turned into an instant call? Group- and
    /// instant-origin calls resolve locally, so nil hands the decision back to the legacy inference.
    private func resolveAuthoritativeType(
        _ callType: CallType,
        participantCount: Int
    ) -> CallType? {
        guard initialLegacyType == .private else {
            return nil
        }

        switch callType {
        case .private:
            return participantCount <= 2 ? .private : .instant
        case .instant:
            return .instant
        case .group:
            // A room this device joined as a 1v1 is never really a group room: unusable value.
            return nil
        }
    }
}
