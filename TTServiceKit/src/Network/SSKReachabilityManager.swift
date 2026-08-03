//
// Copyright 2018 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//
// Ported from Signal-iOS @ ad9893d (SignalServiceKit/Network/ReachabilityManager.swift)
// Adapted:
//   - Implementation wraps the existing `Reachability` 3.7.7 CocoaPod (Tony Million)
//     instead of Signal-iOS's `SCNetworkReachability` direct usage. This keeps the
//     implementation tiny and reuses the pod the rest of the app already depends on.
//   - Network interface enum (`NetworkInterface`/`NetworkInterfaceSet`) and the
//     `OWSURLSession` background reachability probe are not ported — they are not
//     needed by the Job framework and would drag in significant additional surface.
//

import Foundation
import Reachability

public enum ReachabilityType {
    case any
    case wifi
    case cellular
}

// MARK: -

/// Namespace for reachability-related notifications and constants.
public enum SSKReachability {
    /// Posted on the main queue when the device's network reachability state changes.
    /// Observers should call ``SSKReachabilityManager/isReachable`` to read the new state.
    public static let owsReachabilityDidChange = Notification.Name("owsReachabilityDidChange")
}

// MARK: -

/// Protocol describing read-only access to the device's network reachability state.
///
/// The Job framework consumes this through the ``DB``-style L2 abstraction so it can be
/// substituted with a mock in tests.
public protocol SSKReachabilityManager: AnyObject {
    var isReachable: Bool { get }
    func isReachable(via reachabilityType: ReachabilityType) -> Bool
}

// MARK: -

/// Default production implementation backed by the `Reachability` CocoaPod.
public final class SSKReachabilityManagerImpl: NSObject, SSKReachabilityManager {

    private let reachability: Reachability

    @objc
    public override init() {
        guard let reachability = Reachability.forInternetConnection() else {
            owsFail("Failed to create Reachability for internet connection.")
        }
        self.reachability = reachability
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reachabilityDidChange),
            name: .reachabilityChanged,
            object: nil
        )

        // `startNotifier` may return false when the underlying SCNetworkReachability
        // setup fails. In that case `isReachable` will return its default state and
        // we will simply never receive change notifications — non-fatal.
        if !reachability.startNotifier() {
            Logger.error("Reachability notifier failed to start.")
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        reachability.stopNotifier()
    }

    public var isReachable: Bool {
        return reachability.isReachable()
    }

    public func isReachable(via reachabilityType: ReachabilityType) -> Bool {
        switch reachabilityType {
        case .any:
            return reachability.isReachable()
        case .wifi:
            return reachability.isReachableViaWiFi()
        case .cellular:
            return reachability.isReachableViaWWAN()
        }
    }

    // MARK: - Notification re-broadcast

    /// `Reachability` posts `kReachabilityChangedNotification` from arbitrary threads.
    /// We forward it to the main queue under our own name so observers can rely on
    /// thread + naming consistency (matching Signal-iOS conventions).
    @objc
    private func reachabilityDidChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: SSKReachability.owsReachabilityDidChange,
                object: self
            )
        }
    }
}
