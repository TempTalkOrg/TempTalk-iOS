//
//  DTTrustedClock.swift
//  TTServiceKit
//
//  Trusted server-axis clock. See design-common.md.
//

import Foundation
import SignalCoreKit

@objc(DTTrustedClockSource)
public enum DTTrustedClockSource: Int {
    case baseResponse   // DTBaseAPI envelope serverTimestamp — the sole correction path
    case healthCheck    // ensureAnchored ping (also lands via the baseResponse hook)
    case manual         // tests
}

/// L1 uses a monotonic anchor, L2 uses persisted offset/high-water, and L3 uses wall time.
@objc(DTTrustedClock)
public final class DTTrustedClock: NSObject {

    // MARK: - Singleton

    @objc public static let shared = DTTrustedClock()

    private override init() {
        self.store = DTTrustedClockStore()
        super.init()
        loadPersisted()
    }

    // MARK: - Anchor snapshot

    private struct Anchor {
        let serverMs: UInt64             // serverNow captured at 对表
        let continuousMsAtAnchor: UInt64 // mach_continuous_time → ms at the same instant
    }

    // MARK: - State (guarded by `lock`)

    private let lock = UnfairLock()
    private var anchor: Anchor?
    private var offsetMs: Int64 = 0            // serverNow − wallNow (L2)
    private var lastKnownServerMs: UInt64 = 0  // monotone high-water (L2 clamp)
    private var hasPersistedOffset: Bool = false
    private var persistenceGeneration: UInt64 = 0
    private let store: DTTrustedClockStore

    private let persistQueue = DispatchQueue(label: "org.dt.trustedclock.persist")
    private static let anchorPingQueue = DispatchQueue(label: "org.dt.trustedclock.ping")

    private let clientStampLock = UnfairLock()
    private var lastClientStampMs: UInt64 = 0

    /// >24h anchor jump threshold (spec §4 guard ②): accept, but WARN.
    private static let maxPlausibleDeviationMs: Int64 = 24 * 3600 * 1000

    // MARK: - Test seams (internal; the public @objc surface stays clean)

    internal static var continuousMsProvider: () -> UInt64 = { DTTrustedClock.defaultContinuousMs() }
    internal static var wallMsProvider: () -> UInt64 = { NSDate.ows_millisecondTimeStamp() }

    // MARK: - Spec §3 contract (instance)

    /// Trusted current time in epoch milliseconds.
    @objc public func nowMs() -> UInt64 {
        return lock.withLock { resolveLocked().now }
    }

    private func resolveLocked() -> (tier: String, now: UInt64) {
        if let a = anchor {                                           // L1
            return ("L1", a.serverMs &+ (Self.continuousMsProvider() &- a.continuousMsAtAnchor))
        }
        let wall = Self.wallMsProvider()
        if hasPersistedOffset {                                       // L2
            let candidate = Int64(bitPattern: wall) &+ offsetMs
            let l2 = candidate > 0 ? UInt64(candidate) : 0
            return ("L2", max(l2, lastKnownServerMs))                 // never flows backward
        }
        return ("L3", wall)                                           // L3
    }

    private static func sourceName(_ source: DTTrustedClockSource) -> String {
        switch source {
        case .baseResponse: return "baseResponse"
        case .healthCheck:  return "healthCheck"
        case .manual:       return "manual"
        }
    }

    /// Rebuild the anchor from a server timestamp (epoch ms). `serverTime <= 0` ignored (§4 ①).
    @objc public func update(serverTimeMs serverMs: UInt64, source: DTTrustedClockSource) {
        guard serverMs > 0 else { return }                            // §4 guard ①

        let cont = Self.continuousMsProvider()
        let wall = Self.wallMsProvider()

        // Keep I/O and logging outside the lock.
        let result = lock.withLock { () -> UpdateResult in
            let wasFirstAnchor = (anchor == nil)
            var deviationMs: Int64? = nil
            if let a = anchor {
                let currentNow = a.serverMs &+ (cont &- a.continuousMsAtAnchor)
                let dev = abs(Int64(serverMs) - Int64(currentNow))
                if dev > Self.maxPlausibleDeviationMs { deviationMs = dev }   // §4 guard ②
            }
            // BaseResponse time is authoritative.
            anchor = Anchor(serverMs: serverMs, continuousMsAtAnchor: cont)   // rebuild L1
            let newOffset = Int64(serverMs) - Int64(wall)
            let offsetChanged = abs(newOffset - offsetMs) > 1000       // write only when |Δ| > 1s
            let newHighWater = max(lastKnownServerMs, serverMs)
            let highWaterMoved = newHighWater != lastKnownServerMs
            offsetMs = newOffset
            lastKnownServerMs = newHighWater
            hasPersistedOffset = true
            persistenceGeneration &+= 1
            let tier = resolveLocked().tier   // "L1" now that the anchor is set; captured for the log
            return UpdateResult(offsetChanged: offsetChanged,
                                highWaterMoved: highWaterMoved,
                                newOffset: newOffset,
                                newHighWater: newHighWater,
                                persistenceGeneration: persistenceGeneration,
                                deviationMs: deviationMs,
                                wasFirstAnchor: wasFirstAnchor,
                                tier: tier)
        }

        if let dev = result.deviationMs {                             // log AFTER unlock (§4 ②)
            Logger.warn("[TrustedClock] anchor jump devMs=\(dev) source=\(source.rawValue) — accepting server time")
        }
        if result.wasFirstAnchor || result.offsetChanged {           // gate unchanged (first-anchor OR |Δoffset|>1s)
            let deltaFromWall = offsetFromLocalMs()   // now() − wall; locks internally, so OUTSIDE the update lock
            Logger.info("[TrustedClock] anchored source=\(Self.sourceName(source)) tier=\(result.tier) newOffsetMs=\(result.newOffset) deltaFromWallMs=\(deltaFromWall) firstAnchor=\(result.wasFirstAnchor)")
        }
        if result.offsetChanged || result.highWaterMoved {            // persist OUTSIDE the lock
            persistQueue.async { [weak self] in
                self?.store.save(offsetMs: result.newOffset,
                                 lastKnownServerMs: result.newHighWater,
                                 generation: result.persistenceGeneration)
            }
        }
    }

    @objc public func isAnchored() -> Bool { lock.withLock { anchor != nil } }

    @objc public func offsetFromLocalMs() -> Int64 {
        Int64(bitPattern: nowMs()) - Int64(bitPattern: Self.wallMsProvider())
    }

    /// Best-effort anchor request; never gates deletion.
    @objc public func ensureAnchored() {
        guard !isAnchored() else { return }
        guard TSAccountManager.sharedInstance().isRegistered() else { return }
        Logger.info("[TrustedClock] ensureAnchored fired (anchored=false)")
        Self.anchorPingQueue.async { [weak self] in
            guard self != nil else { return }
            let api = DTHealthCheckAPI()
            api.sendRequest(success: { _ in }, failure: { _ in })
        }
    }

    // MARK: - ObjC-friendly class shims (call sites read `[DTTrustedClock now]`)

    @objc public static func now() -> UInt64 { shared.nowMs() }
    @objc public static func ensureAnchored() { shared.ensureAnchored() }
    @objc public static func isAnchored() -> Bool { shared.isAnchored() }

    /// Client-generated message timestamp on the trusted axis, unique within the current process.
    @objc public static func clientStampMs() -> UInt64 {
        return shared.nextClientStampMs()
    }

    private func nextClientStampMs() -> UInt64 {
        // Follow whatever tier resolveLocked() picks — L2 keeps a cold-started process (share
        // extension, NSE) on the server axis instead of dropping straight back to wall time.
        let base = nowMs()
        return clientStampLock.withLock {
            let stamp = base > lastClientStampMs ? base : (lastClientStampMs &+ 1)
            lastClientStampMs = stamp
            return stamp
        }
    }

    // MARK: - Persistence load

    private func loadPersisted() {
        let loaded = store.load()               // UserDefaults read happens off the lock
        lock.withLock {
            offsetMs = loaded.offsetMs
            lastKnownServerMs = loaded.lastKnownServerMs
            hasPersistedOffset = loaded.present
        }
    }

    // MARK: - Time sources

    private static let timebase: mach_timebase_info_data_t = {
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        return tb
    }()

    /// Sleep-inclusive monotonic time in milliseconds.
    private static func defaultContinuousMs() -> UInt64 {
        let raw = mach_continuous_time()
        let numer = UInt64(timebase.numer)
        let denom = UInt64(timebase.denom)
        let ns = raw / denom * numer + (raw % denom) * numer / denom
        return ns / 1_000_000
    }

    private struct UpdateResult {
        let offsetChanged: Bool
        let highWaterMoved: Bool
        let newOffset: Int64
        let newHighWater: UInt64
        let persistenceGeneration: UInt64
        let deviationMs: Int64?
        let wasFirstAnchor: Bool
        let tier: String
    }
}

// MARK: - L2 persistence

/// Persists the L2 offset and high-water before the database is available.
final class DTTrustedClockStore {
    private let defaults = CurrentAppContext().appUserDefaults()
    private let kOffset = "DTTrustedClock.offsetMs"
    private let kLastKnown = "DTTrustedClock.lastKnownServerMs"
    private var lastAppliedGeneration: UInt64 = 0

    func load() -> (offsetMs: Int64, lastKnownServerMs: UInt64, present: Bool) {
        guard defaults.object(forKey: kLastKnown) != nil else { return (0, 0, false) }
        return (Int64(defaults.integer(forKey: kOffset)),
                UInt64(bitPattern: Int64(defaults.integer(forKey: kLastKnown))),
                true)
    }

    func save(offsetMs: Int64, lastKnownServerMs: UInt64, generation: UInt64) {
        guard generation > lastAppliedGeneration else { return }
        lastAppliedGeneration = generation
        if defaults.object(forKey: kLastKnown) != nil {
            let storedHighWater = UInt64(bitPattern: Int64(defaults.integer(forKey: kLastKnown)))
            guard lastKnownServerMs >= storedHighWater else { return }
        }
        defaults.set(offsetMs, forKey: kOffset)
        defaults.set(Int64(bitPattern: lastKnownServerMs), forKey: kLastKnown)
    }
}
