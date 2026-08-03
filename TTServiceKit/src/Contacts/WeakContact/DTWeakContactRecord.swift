//
//  DTWeakContactRecord.swift
//  TTServiceKit
//
//  Weak contact (pending-removal) cache record. Mirrors one entry of the
//  server's pending-removal set. The client is a read-only consumer; the
//  server is the single source of truth for state and expiry.
//

import Foundation

/// One pending-removal contact, mirroring the server set. The countdown anchors on the
/// server clock (`serverNowAtRecord`) via the device monotonic clock, immune to wall-clock changes.
struct DTWeakContactRecord: Codable, Equatable {
    let uid: String
    /// 0 = deleted by friend, 1 = account deactivated. Client does not depend on it.
    let reason: Int
    /// Snapshot display name at change time.
    let name: String?
    /// Snapshot avatar JSON string at change time.
    let avatar: String?
    /// Unfriend time (ms). Unused by the countdown (which targets `expireAt`); kept for future use.
    let deleteTime: Int64?
    /// Absolute expiry time (ms) from server.
    let expireAt: Int64
    /// Server time (ms) at the moment this record was written (countdown anchor).
    let serverNowAtRecord: Int64
    /// Device monotonic clock (seconds) at the moment this record was written.
    let uptimeAtRecord: Double

    static let millisPerDay: Int64 = 86_400_000

    /// Milliseconds left to removal, from the server anchor + device monotonic clock.
    private var remainingMs: Int64 {
        let nowUptime = ProcessInfo.processInfo.systemUptime
        // Monotonic clock resets on reboot; a negative delta falls back to 0 (reconcile re-anchors soon).
        let elapsedMs: Int64 = nowUptime >= uptimeAtRecord
            ? Int64((nowUptime - uptimeAtRecord) * 1000)
            : 0
        let estServerNow = serverNowAtRecord + elapsedMs
        return expireAt - estServerNow
    }

    /// Days left to removal, rounded up. Reaches 0 once inside the final day (use `isRemovingToday`).
    var daysLeft: Int {
        let days = Int((Double(remainingMs) / Double(Self.millisPerDay)).rounded(.up))
        return max(0, days)
    }

    /// True within the final day before removal (≤ 24h left, incl. already past due):
    /// the list shows "Removed today" instead of a day countdown.
    var isRemovingToday: Bool {
        return remainingMs <= Self.millisPerDay
    }
}
