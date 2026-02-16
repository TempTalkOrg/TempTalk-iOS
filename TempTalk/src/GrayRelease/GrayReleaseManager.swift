//
//  GrayReleaseManager.swift
//  TempTalk
//
//  Created by Henry on 2026-01-12.
//

import Foundation
import UIKit
import TTServiceKit

/// Gray Release Manager
/// Manages gray release feature flags with GRDB caching and periodic updates
@objc
public class GrayReleaseManager: NSObject {

    // MARK: - Singleton

    @objc
    public static let shared = GrayReleaseManager()

    // MARK: - Constants

    private let refreshInterval: TimeInterval = 5 * 60 // 5 minutes
    private let keyValueStore = SDSKeyValueStore(collection: "GrayReleaseCollection")
    private let lastRefreshTimeKey = "lastRefreshTime"

    // MARK: - Properties

    private var lastRefreshTime: Date? {
        get {
            var date: Date?
            databaseStorage.read { transaction in
                date = self.keyValueStore.getDate(self.lastRefreshTimeKey, transaction: transaction)
            }
            return date
        }
        set {
            databaseStorage.asyncWrite { transaction in
                if let newValue = newValue {
                    self.keyValueStore.setDate(newValue, key: self.lastRefreshTimeKey, transaction: transaction)
                }
            }
        }
    }

    private var isRefreshing = false
    private let api = DTGrayReleaseAPI()
    private var refreshTimer: Timer?

    // MARK: - Initialization

    private override init() {
        super.init()
        setupAppLifecycleObservers()
    }

    // MARK: - Public Methods

    /// Check if a feature is enabled
    /// - Parameter source: Feature source key (e.g., "quic")
    /// - Returns: true if enabled, false otherwise (default: false)
    @objc
    public func isEnabled(_ source: String) -> Bool {
        var isEnabled = false
        databaseStorage.read { transaction in
            isEnabled = self.keyValueStore.getBool(source, transaction: transaction) ?? false
        }
        return isEnabled
    }

    /// Initialize gray release on app startup
    /// Loads cache and triggers background refresh
    @objc
    public func initialize() {
        Logger.info("GrayReleaseManager: Initializing")

        // Initial refresh for all configurations
        refreshInBackground(sources: nil)

        // Start periodic timer (every 5 minutes)
        startPeriodicRefresh()
    }

    /// Refresh all gray release configurations
    /// - Parameter completion: Optional completion callback
    @objc
    public func refreshAll(completion: ((Bool, Error?) -> Void)? = nil) {
        refresh(sources: nil, completion: completion)
    }

    /// Refresh specific gray release configurations
    /// - Parameters:
    ///   - sources: Array of source keys to refresh
    ///   - completion: Optional completion callback
    @objc
    public func refresh(sources: [String]?, completion: ((Bool, Error?) -> Void)? = nil) {
        guard !isRefreshing else {
            Logger.warn("GrayReleaseManager: Refresh already in progress")
            completion?(false, NSError(domain: "GrayReleaseManager",
                                      code: -1,
                                      userInfo: [NSLocalizedDescriptionKey: "Refresh already in progress"]))
            return
        }

        isRefreshing = true
        Logger.info("GrayReleaseManager: Starting refresh for sources: \(sources?.joined(separator: ", ") ?? "all")")

        api.fetchGrayConfig(sources: sources,
                           success: { [weak self] response in
            guard let self = self else { return }

            self.isRefreshing = false

            if response.isSuccess {
                Logger.info("GrayReleaseManager: Refresh succeeded with \(response.data.count) items")
                self.updateCache(with: response.data, isFullRefresh: sources == nil || sources?.isEmpty == true)
                self.lastRefreshTime = Date()
                completion?(true, nil)
            } else {
                Logger.error("GrayReleaseManager: Refresh failed with status: \(response.status), reason: \(response.reason)")
                let error = NSError(domain: "GrayReleaseManager",
                                  code: response.status,
                                  userInfo: [NSLocalizedDescriptionKey: response.reason])
                completion?(false, error)
            }
        },
                           failure: { [weak self] error in
            guard let self = self else { return }
            self.isRefreshing = false
            Logger.error("GrayReleaseManager: Refresh failed with error: \(error.localizedDescription)")
            completion?(false, error)
        })
    }

    /// Check if refresh is needed based on time interval
    @objc
    public func shouldRefresh() -> Bool {
        guard let lastRefresh = lastRefreshTime else {
            return true
        }
        let shouldRefresh = Date().timeIntervalSince(lastRefresh) >= refreshInterval
        Logger.info("GrayReleaseManager: Should refresh: \(shouldRefresh), last refresh: \(lastRefresh)")
        return shouldRefresh
    }

    // MARK: - Private Methods

    private func updateCache(with items: [GrayReleaseItem], isFullRefresh: Bool) {
        databaseStorage.asyncWrite { transaction in
            if isFullRefresh {
                // Full refresh: clear all existing gray release keys
                // Note: We can't easily clear all keys in a collection, so we just overwrite
                Logger.info("GrayReleaseManager: Full refresh - updating \(items.count) items")
            } else {
                Logger.info("GrayReleaseManager: Partial refresh - updating \(items.count) items")
            }

            // Update or add items
            for item in items {
                self.keyValueStore.setBool(item.isInGray, key: item.source, transaction: transaction)
                Logger.debug("GrayReleaseManager: Set \(item.source) = \(item.isInGray)")
            }
        }
    }

    private func refreshInBackground(sources: [String]?) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.refresh(sources: sources)
        }
    }

    // MARK: - App Lifecycle

    private func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    @objc
    private func handleAppDidBecomeActive() {
        Logger.info("GrayReleaseManager: App became active, triggering refresh")
        refreshInBackground(sources: nil)
    }

    // MARK: - Periodic Refresh

    /// Start periodic refresh timer (every 5 minutes)
    private func startPeriodicRefresh() {
        Logger.info("GrayReleaseManager: Starting periodic refresh timer")

        stopPeriodicRefresh()

        // Run on main thread to ensure timer works properly
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.refreshTimer = Timer.scheduledTimer(
                withTimeInterval: self.refreshInterval,
                repeats: true
            ) { [weak self] _ in
                Logger.info("GrayReleaseManager: Timer fired, triggering periodic refresh")
                self?.refreshInBackground(sources: nil)
            }

            // Ensure timer runs in common run loop modes
            if let timer = self.refreshTimer {
                RunLoop.main.add(timer, forMode: .common)
                Logger.info("GrayReleaseManager: Timer started. Next fire date: \(timer.fireDate)")
            }
        }
    }

    /// Stop periodic refresh timer
    private func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    deinit {
        stopPeriodicRefresh()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - QUIC Feature Extension

extension GrayReleaseManager {

    /// Check if QUIC transport is enabled
    @objc
    public var isQuicEnabled: Bool {
        return isEnabled("quic")
    }

    /// Refresh QUIC gray release status
    /// - Parameter completion: Optional completion callback
    @objc
    public func refreshQuicStatus(completion: ((Bool, Error?) -> Void)? = nil) {
        refresh(sources: ["quic"], completion: completion)
    }
}
