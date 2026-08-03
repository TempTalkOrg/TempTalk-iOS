//
//  DTLastSuccessfulHostManager.swift
//  TTServiceKit
//
//  Manages persistence and retrieval of last successful host for faster reconnection
//

import Foundation
import SignalCoreKit

/// Persists the host used by the most recent successful network round-trip,
/// so that the next launch can prefer it before the speed-test result is in.
///
/// Write policy: each service type is only written **once per app session**.
/// This avoids thrashing UserDefaults on every successful request while still
/// capturing the first known-good host early in the session.
@objc
public class DTLastSuccessfulHostManager: NSObject {

    // MARK: - Singleton

    @objc
    public static let shared = DTLastSuccessfulHostManager()

    private override init() {
        super.init()
    }

    // MARK: - Constants

    private let lastSuccessfulMainHostKey = "DTLastSuccessfulMainHost"

    // MARK: - State

    private let unfairLock = UnfairLock()
    private var hasWrittenMainHostThisSession = false
    /// Hosts that have been marked invalid during this session.
    /// Prevents a late-arriving success callback from persisting a host
    /// that was already invalidated by a concurrent failure callback.
    private var invalidatedHostsThisSession = Set<String>()

    // MARK: - Public API

    /// Save the last successful host. Only writes once per app session per
    /// service type — subsequent calls are no-ops until `clearLastSuccessfulHost`
    /// resets the flag. Refuses to save hosts that have been marked invalid
    /// during this session. Thread-safe.
    @objc
    public func saveLastSuccessfulHost(_ host: String, serverType: DTServToType) {
        guard !host.isEmpty else { return }
        // Under proxy the chat host is pinned; don't persist a host so disabling proxy later
        // restores the normal speed-test selection rather than a stuck pinned host.
        if serverType == .chat, ProxyManager.shared.isEnabled { return }

        let shouldSave: Bool = unfairLock.withLock {
            switch serverType {
            case .chat:
                guard !hasWrittenMainHostThisSession,
                      !invalidatedHostsThisSession.contains(host) else { return false }
                hasWrittenMainHostThisSession = true
                return true
            @unknown default:
                return false
            }
        }

        guard shouldSave else { return }

        let key: String
        switch serverType {
        case .chat:
            key = lastSuccessfulMainHostKey
        @unknown default:
            return
        }

        CurrentAppContext().appUserDefaults().set(host, forKey: key)

        Logger.info("[DomainSwitch] Saved \(serverTypeString(serverType)) host: \(host)")
    }

    /// Retrieve the persisted host, if any. Thread-safe.
    @objc
    public func getLastSuccessfulHost(serverType: DTServToType) -> String? {
        let key: String
        switch serverType {
        case .chat:
            key = lastSuccessfulMainHostKey
        @unknown default:
            return nil
        }

        let host = CurrentAppContext().appUserDefaults().string(forKey: key)

        if let host = host {
            Logger.debug("[DomainSwitch] Retrieved \(serverTypeString(serverType)) host: \(host)")
        }

        return host
    }

    /// Record a host as invalidated, clear it from persistence, and re-allow
    /// saving so the next *different* good host can be captured.
    /// The invalidated host is remembered for the remainder of the session to
    /// prevent a late-arriving success callback from re-persisting it.
    @objc
    public func markHostInvalidated(_ host: String, serverType: DTServToType) {
        unfairLock.withLock {
            switch serverType {
            case .chat:
                invalidatedHostsThisSession.insert(host)
                hasWrittenMainHostThisSession = false
            @unknown default:
                break
            }
        }

        let key: String
        switch serverType {
        case .chat:
            key = lastSuccessfulMainHostKey
        @unknown default:
            return
        }

        CurrentAppContext().appUserDefaults().removeObject(forKey: key)

        Logger.info("[DomainSwitch] Marked \(serverTypeString(serverType)) host invalidated: \(host)")
    }

    /// Restore persisted host(s) onto TSConstants. Must be called before any
    /// network operation that reads `TSConstants.mainServiceHost`.
    @objc
    public func restoreHostsToTSConstants() {
        if let lastMainHost = getLastSuccessfulHost(serverType: .chat) {
            TSConstants.mainServiceHost = lastMainHost
            Logger.info("[DomainSwitch] Restored main host to TSConstants: \(lastMainHost)")
        }
    }

    private func serverTypeString(_ serverType: DTServToType) -> String {
        switch serverType {
        case .chat:
            return "main"
        @unknown default:
            return "unknown"
        }
    }
}
