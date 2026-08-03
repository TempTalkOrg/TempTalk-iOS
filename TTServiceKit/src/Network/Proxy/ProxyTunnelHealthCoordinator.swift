//
//  ProxyTunnelHealthCoordinator.swift
//  TTServiceKit
//
//  Outcome-based WSS health watchdog (self-heal tier 2). Tier 1 (ProxyManager/LocalTunnelProxy)
//  reacts to the loopback listener dying; it misses the cases where the listener is alive but
//  traffic doesn't flow, or the tunnel wedges mid-session in the foreground. This watchdog watches
//  the RESULT instead: whenever the proxy is on, the device has a network route, and WSS stays
//  non-open past a grace window, it rebuilds the tunnel regardless of the internal cause.
//
//  The actual rebuild is delegated to ProxyManager.recoverTunnelIfEnabled (30s cooldown + background
//  rebuild) — this watchdog is just an extra trigger source, so tier 1 and tier 2 can both fire
//  and the cooldown safely de-dupes them.
//
//  All state (timer + counters) is managed on the main thread for simplicity; socketState is safe
//  to read cross-thread but everything is hopped to main so the state machine stays single-threaded.
//

import Foundation

@objc public final class ProxyTunnelHealthCoordinator: NSObject {

    @objc public static let shared = ProxyTunnelHealthCoordinator()

    // 30s lets the socket's own ~5s reconnect recover naturally before we intervene (avoids false
    // rebuilds); it also sits at/above recoverTunnelIfEnabled's 30s cooldown, so the two align.
    private static let unhealthyThreshold: TimeInterval = 30
    private static let maxConsecutiveRecoveries = 3

    private var started = false
    private var pendingCheck: DispatchWorkItem?
    private var consecutiveRecoveries = 0
    private let reachabilityManager = SSKReachabilityManagerImpl()

    private override init() { super.init() }

    /// Idempotent: safe to call from any app-ready / activation hook; only the first call registers.
    @objc public func start() {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.started else { return }
            self.started = true
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.webSocketStateDidChange),
                name: OWSWebSocket.webSocketStateDidChange,
                object: nil
            )
            Logger.info("[Proxy][self-heal] watchdog started")
            self.evaluate()
        }
    }

    @objc private func webSocketStateDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.evaluate()
        }
    }

    // MARK: State machine (main thread only)

    private func evaluate() {
        let state = SSKEnvironment.shared.socketManagerRef.socketState()
        if state == .open {
            // Healthy: drop any pending check and clear the attempt streak.
            cancelPending()
            consecutiveRecoveries = 0
            return
        }
        // Non-open: only watch while the proxy is on AND there is a real route (never rebuild on a
        // genuine no-network state — that would thrash the tunnel for nothing).
        guard ProxyManager.shared.isEnabled, reachabilityManager.isReachable else {
            cancelPending()
            return
        }
        // Gave up after maxConsecutiveRecoveries — stand down until a .open resets the streak.
        guard consecutiveRecoveries < Self.maxConsecutiveRecoveries else { return }
        guard pendingCheck == nil else { return } // already armed
        armCheck()
    }

    private func armCheck() {
        Logger.info("[Proxy][self-heal] watchdog: WSS not open, arming \(Int(Self.unhealthyThreshold))s check")
        let work = DispatchWorkItem { [weak self] in
            self?.fireCheck()
        }
        pendingCheck = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.unhealthyThreshold, execute: work)
    }

    private func fireCheck() {
        pendingCheck = nil
        // Re-confirm the unhealthy condition still holds after the grace window.
        let state = SSKEnvironment.shared.socketManagerRef.socketState()
        guard state != .open, ProxyManager.shared.isEnabled, reachabilityManager.isReachable else {
            consecutiveRecoveries = 0
            return
        }
        guard consecutiveRecoveries < Self.maxConsecutiveRecoveries else {
            Logger.warn("[Proxy][self-heal] watchdog: giving up after \(Self.maxConsecutiveRecoveries) attempts, awaiting next open/foreground")
            return
        }
        // Only charge an attempt when a rebuild actually fired. If recoverTunnelIfEnabled was
        // swallowed by its 30s cooldown, another trigger (tier-1 / foreground) just rebuilt, so keep
        // watching without burning our limited budget — re-arm and re-evaluate after the window.
        let didRebuild = ProxyManager.shared.recoverTunnelIfEnabled(reason: "watchdog: WSS unhealthy")
        if didRebuild {
            consecutiveRecoveries += 1
            Logger.info("[Proxy][self-heal] watchdog: WSS unhealthy ≥\(Int(Self.unhealthyThreshold))s, rebuilding (attempt \(consecutiveRecoveries))")
        } else {
            Logger.info("[Proxy][self-heal] watchdog: WSS unhealthy but rebuild deferred (cooldown), still watching")
        }
        armCheck() // observe whether the rebuild restores the socket
    }

    private func cancelPending() {
        pendingCheck?.cancel()
        pendingCheck = nil
    }
}
