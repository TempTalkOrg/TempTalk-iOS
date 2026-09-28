//
//  CallNetworkQualityTracker.swift
//  TempTalk
//

import Foundation
import LiveKit

enum CallNetworkQualityLog {
    static let tag = "[newcall][network-quality]"

    static func debug(_ message: @autoclosure () -> String) {
        Logger.debug("\(tag) \(message())")
    }

    static func info(_ message: @autoclosure () -> String) {
        Logger.info("\(tag) \(message())")
    }

    static func warn(_ message: @autoclosure () -> String) {
        Logger.warn("\(tag) \(message())")
    }
}

enum CallNetworkQualityLevel: Equatable {
    case normal
    case poor

    init(connectionQuality: ConnectionQuality) {
        switch connectionQuality {
        case .poor, .lost:
            self = .poor
        case .unknown, .good, .excellent:
            self = .normal
        }
    }
}

struct CallNetworkQualitySample: Equatable {
    let participantKey: String
    let participantIdentity: String?
    let isLocal: Bool
    let level: CallNetworkQualityLevel
}

struct CallNetworkQualitySnapshot: Equatable {
    static let empty = CallNetworkQualitySnapshot(
        isLocalPoor: false,
        poorRemoteParticipantKeys: []
    )

    let isLocalPoor: Bool
    let poorRemoteParticipantKeys: Set<String>
}

protocol CallNetworkQualityScheduledTask: AnyObject {
    func cancel()
}

private final class CallNetworkQualityWorkItem: CallNetworkQualityScheduledTask {
    private var workItem: DispatchWorkItem?

    init(delay: TimeInterval, action: @escaping @MainActor () -> Void) {
        let workItem = DispatchWorkItem {
            Task { @MainActor in
                action()
            }
        }
        self.workItem = workItem
        // DispatchTime is monotonic, so wall-clock changes cannot shorten or extend hysteresis.
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func cancel() {
        workItem?.cancel()
        workItem = nil
    }

    deinit {
        workItem?.cancel()
    }
}

/// Converts noisy SDK quality samples into the stable state consumed by call UI.
/// Each participant owns an independent 3s degradation / 5s recovery timer.
@MainActor
final class CallNetworkQualityTracker {
    typealias Scheduler = (
        _ delay: TimeInterval,
        _ action: @escaping @MainActor () -> Void
    ) -> CallNetworkQualityScheduledTask

    private struct Entry {
        let isLocal: Bool
        let participantIdentity: String?
        var publishedLevel: CallNetworkQualityLevel
        var latestLevel: CallNetworkQualityLevel
        var generation: UInt
        var scheduledTask: CallNetworkQualityScheduledTask?
        var awaitsTransferredLifetimeClaim: Bool
    }

    private let poorDelay: TimeInterval
    private let recoveryDelay: TimeInterval
    private let scheduler: Scheduler
    private var entries: [String: Entry] = [:]
    /// Never reset between participant lifetimes. A cancelled timer may already have enqueued its
    /// MainActor task, so reusing an entry-local generation after a SID is reused is unsafe.
    private var nextGeneration: UInt = 0

    private(set) var isSuppressed = true
    private(set) var snapshot: CallNetworkQualitySnapshot = .empty
    var onSnapshotChange: ((CallNetworkQualitySnapshot) -> Void)?

    init(
        poorDelay: TimeInterval = 3,
        recoveryDelay: TimeInterval = 5,
        scheduler: @escaping Scheduler = { delay, action in
            CallNetworkQualityWorkItem(delay: delay, action: action)
        }
    ) {
        self.poorDelay = poorDelay
        self.recoveryDelay = recoveryDelay
        self.scheduler = scheduler
    }

    static func shouldSuppress(
        roomConnectionState: ConnectionState,
        mediaSendConnectionState: MediaSendConnectionState,
        isExplicitlyReconnecting: Bool
    ) -> Bool {
        isExplicitlyReconnecting
            || roomConnectionState != .connected
            || mediaSendConnectionState.isRoomRecovering
    }

    func setSuppressed(_ suppressed: Bool, reseedingWith samples: [CallNetworkQualitySample] = []) {
        guard suppressed != isSuppressed else {
            CallNetworkQualityLog.debug(
                "event=suppression_ignored reason=unchanged suppressed=\(suppressed) reseedCount=\(samples.count)"
            )
            return
        }

        let previousSuppressed = isSuppressed
        let clearedEntryCount = entries.count
        let cancelledTimerCount = entries.values.filter { $0.scheduledTask != nil }.count
        cancelAndRemoveAllEntries()
        isSuppressed = suppressed
        publishSnapshotIfNeeded()
        CallNetworkQualityLog.info(
            "event=suppression_changed from=\(previousSuppressed) to=\(suppressed) "
                + "clearedEntries=\(clearedEntryCount) cancelledTimers=\(cancelledTimerCount) "
                + "reseedCount=\(suppressed ? 0 : samples.count)"
        )

        guard !suppressed else { return }
        for sample in samples {
            ingest(sample)
        }
    }

    func ingest(_ sample: CallNetworkQualitySample) {
        let role = sample.isLocal ? "local" : "remote"
        guard !isSuppressed else {
            CallNetworkQualityLog.debug(
                "event=sample_ignored reason=suppressed sid=\(sample.participantKey) role=\(role) level=\(sample.level)"
            )
            return
        }

        let existingEntry = entries[sample.participantKey]
        var entry = existingEntry ?? Entry(
            isLocal: sample.isLocal,
            participantIdentity: sample.participantIdentity,
            publishedLevel: .normal,
            latestLevel: .normal,
            generation: 0,
            scheduledTask: nil,
            awaitsTransferredLifetimeClaim: false
        )
        if existingEntry == nil {
            CallNetworkQualityLog.debug(
                "event=participant_tracking_started sid=\(sample.participantKey) role=\(role)"
            )
        }

        // A SID collision must not let a remote sample overwrite local state (or vice versa).
        guard entry.isLocal == sample.isLocal else {
            CallNetworkQualityLog.warn(
                "event=participant_role_changed sid=\(sample.participantKey) "
                    + "from=\(entry.isLocal ? "local" : "remote") to=\(role) action=rebuild"
            )
            entry.scheduledTask?.cancel()
            entries.removeValue(forKey: sample.participantKey)
            publishSnapshotIfNeeded()
            ingest(sample)
            return
        }

        if sample.level == entry.publishedLevel {
            let previousLatestLevel = entry.latestLevel
            let cancelledPendingTransition = entry.scheduledTask != nil
            entry.scheduledTask?.cancel()
            entry.scheduledTask = nil
            entry.latestLevel = sample.level
            entry.generation = makeGeneration()
            entries[sample.participantKey] = entry
            if cancelledPendingTransition {
                CallNetworkQualityLog.info(
                    "event=hysteresis_cancelled sid=\(sample.participantKey) role=\(role) "
                        + "pendingLevel=\(previousLatestLevel) reason=returned_to_published "
                        + "published=\(entry.publishedLevel)"
                )
            } else {
                CallNetworkQualityLog.debug(
                    "event=sample_ignored reason=matches_published sid=\(sample.participantKey) "
                        + "role=\(role) level=\(sample.level)"
                )
            }
            return
        }

        guard sample.level != entry.latestLevel || entry.scheduledTask == nil else {
            CallNetworkQualityLog.debug(
                "event=sample_ignored reason=same_mapped_level sid=\(sample.participantKey) "
                    + "role=\(role) level=\(sample.level) timer=kept"
            )
            return
        }

        entry.scheduledTask?.cancel()
        entry.latestLevel = sample.level
        entry.generation = makeGeneration()
        let generation = entry.generation
        let delay = sample.level == .poor ? poorDelay : recoveryDelay
        entry.scheduledTask = scheduler(delay) { [weak self] in
            self?.commit(
                participantKey: sample.participantKey,
                level: sample.level,
                generation: generation
            )
        }
        entries[sample.participantKey] = entry
        CallNetworkQualityLog.info(
            "event=hysteresis_scheduled sid=\(sample.participantKey) role=\(role) "
                + "from=\(entry.publishedLevel) to=\(sample.level) delay=\(delay)s generation=\(generation)"
        )
    }

    func removeParticipant(withKey participantKey: String) {
        guard let entry = entries.removeValue(forKey: participantKey) else {
            CallNetworkQualityLog.debug(
                "event=participant_remove_ignored reason=not_tracked sid=\(participantKey)"
            )
            return
        }
        let hadPendingTimer = entry.scheduledTask != nil
        entry.scheduledTask?.cancel()
        CallNetworkQualityLog.info(
            "event=participant_tracking_ended sid=\(participantKey) "
                + "role=\(entry.isLocal ? "local" : "remote") published=\(entry.publishedLevel) "
                + "latest=\(entry.latestLevel) cancelledTimer=\(hadPendingTimer)"
        )
        publishSnapshotIfNeeded()
    }

    /// A quality callback can reconcile a replacement SID before participantDidConnect reaches
    /// RoomContext. Keep the transferred state until that same identity claims its new lifetime.
    func claimTransferredLifetime(
        withKey participantKey: String,
        participantIdentity: String?
    ) -> Bool {
        guard var entry = entries[participantKey],
              !entry.isLocal,
              entry.awaitsTransferredLifetimeClaim,
              entry.participantIdentity == participantIdentity else {
            return false
        }
        entry.awaitsTransferredLifetimeClaim = false
        entries[participantKey] = entry
        return true
    }

    /// Reconciles tracker entries with the current Room roster. A reconnect may replace a
    /// participant SID while preserving its identity. Transfer an already-published poor state
    /// to that replacement so its banner or badge follows the normal 5s recovery path instead of
    /// disappearing for one frame. Entries without a replacement are removed.
    @discardableResult
    func retainParticipants(
        withKeys validParticipantKeys: Set<String>,
        replacementKeysByIdentity: [String: String],
        reason: String
    ) -> Set<String> {
        let staleKeys = Set(entries.keys).subtracting(validParticipantKeys)
        guard !staleKeys.isEmpty else { return [] }

        var cancelledTimerCount = 0
        var removedPoorKeys: [String] = []
        var transferredPoorKeys: [String] = []
        var transferredReplacementKeys = Set<String>()
        for key in staleKeys.sorted() {
            guard let entry = entries.removeValue(forKey: key) else { continue }
            if entry.scheduledTask != nil {
                cancelledTimerCount += 1
            }
            entry.scheduledTask?.cancel()

            if !entry.isLocal,
               entry.publishedLevel == .poor,
               let identity = entry.participantIdentity,
               let replacementKey = replacementKeysByIdentity[identity],
               entries[replacementKey] == nil,
               !transferredReplacementKeys.contains(replacementKey)
            {
                var replacementEntry = entry
                replacementEntry.latestLevel = .poor
                replacementEntry.generation = makeGeneration()
                replacementEntry.scheduledTask = nil
                replacementEntry.awaitsTransferredLifetimeClaim = true
                entries[replacementKey] = replacementEntry
                transferredReplacementKeys.insert(replacementKey)
                transferredPoorKeys.append("\(key)->\(replacementKey)")
            } else if entry.publishedLevel == .poor {
                removedPoorKeys.append(key)
            }
        }

        CallNetworkQualityLog.info(
            "event=participant_roster_reconciled reason=\"\(reason)\" "
                + "removedSIDs=\(staleKeys.sorted()) removedPoorSIDs=\(removedPoorKeys.sorted()) "
                + "transferredPoorSIDs=\(transferredPoorKeys.sorted()) "
                + "cancelledTimers=\(cancelledTimerCount)"
        )
        publishSnapshotIfNeeded()
        return transferredReplacementKeys
    }

    func reset(suppressed: Bool = true, reason: String = "reset") {
        let clearedEntryCount = entries.count
        let cancelledTimerCount = entries.values.filter { $0.scheduledTask != nil }.count
        cancelAndRemoveAllEntries()
        isSuppressed = suppressed
        publishSnapshotIfNeeded()
        CallNetworkQualityLog.info(
            "event=tracker_reset reason=\(reason) suppressed=\(suppressed) "
                + "clearedEntries=\(clearedEntryCount) cancelledTimers=\(cancelledTimerCount)"
        )
    }

    private func commit(
        participantKey: String,
        level: CallNetworkQualityLevel,
        generation: UInt
    ) {
        guard !isSuppressed else {
            CallNetworkQualityLog.debug(
                "event=timer_ignored reason=suppressed sid=\(participantKey) level=\(level) generation=\(generation)"
            )
            return
        }
        guard var entry = entries[participantKey] else {
            CallNetworkQualityLog.debug(
                "event=timer_ignored reason=participant_removed sid=\(participantKey) "
                    + "level=\(level) generation=\(generation)"
            )
            return
        }
        guard entry.generation == generation else {
            CallNetworkQualityLog.debug(
                "event=timer_ignored reason=stale_generation sid=\(participantKey) "
                    + "expected=\(entry.generation) actual=\(generation)"
            )
            return
        }
        guard entry.latestLevel == level else {
            CallNetworkQualityLog.debug(
                "event=timer_ignored reason=level_changed sid=\(participantKey) "
                    + "expected=\(entry.latestLevel) actual=\(level)"
            )
            return
        }

        entry.publishedLevel = level
        entry.scheduledTask = nil
        entries[participantKey] = entry
        CallNetworkQualityLog.info(
            "event=level_published sid=\(participantKey) role=\(entry.isLocal ? "local" : "remote") "
                + "level=\(level) generation=\(generation)"
        )
        publishSnapshotIfNeeded()
    }

    private func cancelAndRemoveAllEntries() {
        entries.values.forEach { $0.scheduledTask?.cancel() }
        entries.removeAll()
    }

    private func makeGeneration() -> UInt {
        nextGeneration &+= 1
        return nextGeneration
    }

    private func publishSnapshotIfNeeded() {
        let localIsPoor = entries.values.contains { $0.isLocal && $0.publishedLevel == .poor }
        let remoteKeys: Set<String>
        if localIsPoor {
            // A local network failure makes server-reported remote quality untrustworthy.
            remoteKeys = []
        } else {
            remoteKeys = Set(entries.compactMap { key, entry in
                !entry.isLocal && entry.publishedLevel == .poor ? key : nil
            })
        }

        let nextSnapshot = CallNetworkQualitySnapshot(
            isLocalPoor: localIsPoor,
            poorRemoteParticipantKeys: remoteKeys
        )
        guard nextSnapshot != snapshot else { return }
        snapshot = nextSnapshot
        onSnapshotChange?(nextSnapshot)
    }
}
