//
//  CallServiceUrlManager.swift
//  Difft
//
//  Created by Henry on 2026/5/7.
//  Copyright © 2026 Difft. All rights reserved.
//

import Foundation
import UIKit
import TTServiceKit

// MARK: - Disk state

public struct CallServiceUrlDiskState: Codable, Equatable {
    public let serviceUrls: ServiceUrls
    public let expiresAtMillis: Int64       // server 时间 + ttl
    public let lastFetchedAtMillis: Int64   // local clock，刷新节流用

    public init(serviceUrls: ServiceUrls,
                expiresAtMillis: Int64,
                lastFetchedAtMillis: Int64) {
        self.serviceUrls = serviceUrls
        self.expiresAtMillis = expiresAtMillis
        self.lastFetchedAtMillis = lastFetchedAtMillis
    }

    public var isExpired: Bool {
        Int64(Date().timeIntervalSince1970 * 1000) >= expiresAtMillis
    }
}

// MARK: - Disk cache

private enum CallServiceUrlDiskCache {
    static let service = "im.chative.call"

    /// Legacy env-agnostic key. Kept only so we can purge it once — never read/written.
    private static let legacyKey = "service-urls-v2"

    /// Env-scoped cache key. Call-service URLs are per-environment (prod vs test): reusing
    /// the other environment's cached URLs sends a valid token to the wrong server and
    /// yields `[401] JWT签名无效`. Scoping by the current service host keeps them separate.
    static var key: String {
        let host = TSConstants.mainServiceHost
        let sanitized = host.replacingOccurrences(of: "[^A-Za-z0-9._-]", with: "_", options: .regularExpression)
        return "service-urls-v2-\(sanitized)"
    }

    private static var storage: SSKKeychainStorage { SSKDefaultKeychainStorage.shared }

    /// Remove the pre-env-scoping cache entry so a stale cross-environment copy can't linger.
    static func purgeLegacy() {
        try? storage.remove(service: service, key: legacyKey)
    }

    static func load() -> CallServiceUrlDiskState? {
        let data: Data?
        do {
            data = try storage.optionalData(forService: service, key: key)
        } catch {
            Logger.error("[CallServiceUrlDiskCache] read failed: \(error.localizedDescription)")
            return nil
        }
        guard let data else { return nil }
        do {
            return try JSONDecoder().decode(CallServiceUrlDiskState.self, from: data)
        } catch {
            // 历史脏数据，清掉避免每次启动都报错
            Logger.error("[CallServiceUrlDiskCache] decode failed: \(error.localizedDescription); clearing")
            try? storage.remove(service: service, key: key)
            return nil
        }
    }

    static func save(_ state: CallServiceUrlDiskState) {
        do {
            let data = try JSONEncoder().encode(state)
            try storage.set(data: data, service: service, key: key)
        } catch {
            Logger.error("[CallServiceUrlDiskCache] save failed: \(error.localizedDescription)")
        }
    }

    static func clear() {
        try? storage.remove(service: service, key: key)
    }
}

// MARK: - Hardcoded fallback

/// 三层缓存的最后一道：内存/磁盘都空时使用。
/// 当前为空；后端节点 IP 敲定后把真实主备填进来，`config_version=0` 保证远端配置一定覆盖。
private enum DefaultGlobalConfigReader {
    static let fallback: ServiceUrls? = nil

    static func load() -> ServiceUrls? { fallback }
}

// MARK: - Manager

public actor CallServiceUrlManager {

    public static let shared = CallServiceUrlManager()

    private enum Throttle {
        static let foregroundMinIntervalMs: Int64 = 20 * 60 * 1000
        static let postFailureMinIntervalMs: Int64 = 30 * 1000
        static let periodicIntervalNanos: UInt64 = 20 * 60 * 1_000_000_000
    }

    public enum FetchError: Error { case timeout, noCache }

    private var inMemory: CallServiceUrlDiskState?
    private var inflight: Task<ServiceUrls, Error>?
    private var periodicTask: Task<Void, Never>?

    private init() {
        // Drop any pre-env-scoping cache so a prod copy can't be reused on test (or vice versa).
        CallServiceUrlDiskCache.purgeLegacy()
        if let disk = CallServiceUrlDiskCache.load() {
            inMemory = disk
            Logger.info("[CallServiceUrlManager] loaded disk cache, version=\(disk.serviceUrls.configVersion) expired=\(disk.isExpired)")
        }
    }

    /// Calls route through the proxy (proxy on AND in-call IP protection on). In that case the call
    /// path uses the fixed `proxy.tunnelDomains.call` list and never consumes these server-fetched
    /// service URLs — so all background fetching/refresh is suppressed, mirroring how chat stops its
    /// speed-test under proxy. When off, original refresh behaviour is unchanged.
    private static var callsRouteThroughProxy: Bool {
        // Both switches on: proxy enabled AND in-call IP protection on.
        ProxyManager.shared.isEnabled && ProxyManager.shared.protectCallIPEnabled
    }

    // 7 种刷新时机入口

    public func bootstrapIfNeeded() async {
        guard !Self.callsRouteThroughProxy else {
            Logger.info("[CallServiceUrlManager] bootstrap skipped: calls route through proxy")
            return
        }
        guard Self.isNetworkReachable() else {
            Logger.info("[CallServiceUrlManager] bootstrap skipped: network unreachable")
            return
        }
        Logger.info("[CallServiceUrlManager] bootstrap fetching")
        _ = try? await fetchAndCache(timeout: nil)
    }

    public func onAppForegrounded() async {
        guard !Self.callsRouteThroughProxy else {
            Logger.info("[CallServiceUrlManager] foreground skipped: calls route through proxy")
            return
        }
        guard !throttle(minIntervalMs: Throttle.foregroundMinIntervalMs) else {
            Logger.info("[CallServiceUrlManager] foreground skipped by throttle")
            return
        }
        Logger.info("[CallServiceUrlManager] foreground refreshing")
        _ = try? await fetchAndCache(timeout: nil)
    }

    public func onNetworkRecovered() async {
        guard !Self.callsRouteThroughProxy else {
            Logger.info("[CallServiceUrlManager] network recovered skipped: calls route through proxy")
            return
        }
        Logger.info("[CallServiceUrlManager] network recovered → refresh")
        _ = try? await fetchAndCache(timeout: nil)
    }

    public func ensureServiceUrlsForCall(timeout: TimeInterval = 15) async throws -> ServiceUrls {
        // Calls route through the proxy → connection uses the fixed tunnelDomains.call list, not
        // these URLs. Don't fetch; return cache if present (caller ignores the result).
        if Self.callsRouteThroughProxy {
            if let cached = inMemory?.serviceUrls { return cached }
            throw FetchError.noCache
        }
        if let cached = inMemory, !cached.isExpired {
            return cached.serviceUrls
        }
        do {
            return try await fetchAndCache(timeout: timeout)
        } catch {
            Logger.error("[CallServiceUrlManager] ensure fetch failed: \(error.localizedDescription); expired cache rejected, falling back to assets")
            if let assets = DefaultGlobalConfigReader.load() {
                Logger.info("[CallServiceUrlManager] ensure: assets fallback v=\(assets.configVersion)")
                return assets
            }
            throw FetchError.noCache
        }
    }

    public func refreshAfterConnectionFailure() async {
        guard !Self.callsRouteThroughProxy else {
            Logger.info("[CallServiceUrlManager] post-failure refresh skipped: calls route through proxy")
            return
        }
        guard !throttle(minIntervalMs: Throttle.postFailureMinIntervalMs) else {
            Logger.info("[CallServiceUrlManager] post-failure refresh skipped by throttle")
            return
        }
        Logger.info("[CallServiceUrlManager] post-failure refreshing")
        _ = try? await fetchAndCache(timeout: nil)
    }

    @discardableResult
    public func forceRefresh() async throws -> ServiceUrls {
        // Calls route through the proxy → these URLs aren't used; don't fetch.
        if Self.callsRouteThroughProxy {
            if let cached = inMemory?.serviceUrls { return cached }
            throw FetchError.noCache
        }
        Logger.info("[CallServiceUrlManager] force refresh")
        return try await fetchAndCache(timeout: nil)
    }

    public func bestEffortServiceUrls() -> ServiceUrls? {
        if let mem = inMemory?.serviceUrls { return mem }
        if let disk = CallServiceUrlDiskCache.load()?.serviceUrls { return disk }
        return DefaultGlobalConfigReader.load()
    }

    public func clearCache() {
        inMemory = nil
        CallServiceUrlDiskCache.clear()
        Logger.info("[CallServiceUrlManager] cache cleared")
    }

    // 定时轮询

    public func startPeriodicRefresh() {
        guard periodicTask == nil else { return }
        Logger.info("[CallServiceUrlManager] periodic refresh started")
        periodicTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Throttle.periodicIntervalNanos)
                guard !Task.isCancelled else { return }
                await self?.onAppForegrounded()
            }
        }
    }

    public func stopPeriodicRefresh() {
        periodicTask?.cancel()
        periodicTask = nil
        Logger.info("[CallServiceUrlManager] periodic refresh stopped")
    }

    // MARK: Internal

    private func fetchAndCache(timeout: TimeInterval?) async throws -> ServiceUrls {
        if let task = inflight {
            return try await task.value
        }
        let task = Task<ServiceUrls, Error> { [weak self] in
            guard let self else { throw FetchError.noCache }
            defer { Task { await self.clearInflight() } }
            let remote: ServiceUrls
            if let timeout {
                remote = try await Self.withTimeout(timeout) { try await Self.callApi() }
            } else {
                remote = try await Self.callApi()
            }
            await self.applyFetchResult(remote)
            return remote
        }
        inflight = task
        return try await task.value
    }

    private func clearInflight() { inflight = nil }

    private func applyFetchResult(_ remote: ServiceUrls) {
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
        let serverSec = remote.serverTimestampSeconds ?? Date().timeIntervalSince1970
        let expiresAtMillis = Int64((serverSec + Double(remote.ttl)) * 1000)

        let merged: CallServiceUrlDiskState
        // local >= remote 保留本地，仅刷新过期时间
        if let local = inMemory, local.serviceUrls.configVersion >= remote.configVersion {
            merged = CallServiceUrlDiskState(
                serviceUrls: local.serviceUrls,
                expiresAtMillis: expiresAtMillis,
                lastFetchedAtMillis: nowMillis
            )
            Logger.info("[CallServiceUrlManager] keep local v=\(local.serviceUrls.configVersion) (remote v=\(remote.configVersion)), refreshed expires only")
        } else {
            merged = CallServiceUrlDiskState(
                serviceUrls: remote,
                expiresAtMillis: expiresAtMillis,
                lastFetchedAtMillis: nowMillis
            )
            Logger.info("[CallServiceUrlManager] applied remote v=\(remote.configVersion) ttl=\(remote.ttl)")
        }
        inMemory = merged
        CallServiceUrlDiskCache.save(merged)
    }

    private func throttle(minIntervalMs: Int64) -> Bool {
        guard let last = inMemory?.lastFetchedAtMillis else { return false }
        let nowMillis = Int64(Date().timeIntervalSince1970 * 1000)
        return (nowMillis - last) < minIntervalMs
    }

    private static func callApi() async throws -> ServiceUrls {
        try await withCheckedThrowingContinuation { continuation in
            let api = CallServiceUrlV2Api()
            api.fetchServiceUrls { config in
                continuation.resume(returning: config)
            } failure: { error in
                continuation.resume(throwing: error)
            }
        }
    }

    private static func withTimeout<T: Sendable>(_ seconds: TimeInterval,
                                                 _ op: @Sendable @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await op() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw FetchError.timeout
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw FetchError.timeout }
            return first
        }
    }

    private static func isNetworkReachable() -> Bool {
        Reachability.forInternetConnection()?.isReachable() ?? true
    }
}

// MARK: - Lifecycle hook

@MainActor
public final class CallServiceUrlLifecycleHook {

    public static let shared = CallServiceUrlLifecycleHook()

    private var installed: Bool = false
    private let reachability = Reachability.forInternetConnection()
    private var lastReachable: Bool = true

    private init() {}

    public func install() {
        guard !installed else { return }
        installed = true

        Task { await CallServiceUrlManager.shared.bootstrapIfNeeded() }

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(handleDidBecomeActive),
                       name: UIApplication.didBecomeActiveNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleDidEnterBackground),
                       name: UIApplication.didEnterBackgroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(handleReachabilityChanged),
                       name: .reachabilityChanged, object: reachability)
        reachability?.startNotifier()
        lastReachable = reachability?.isReachable() ?? true

        if UIApplication.shared.applicationState == .active {
            Task { await CallServiceUrlManager.shared.startPeriodicRefresh() }
        }
        Logger.info("[CallServiceUrlLifecycleHook] installed")
    }

    @objc private func handleDidBecomeActive() {
        Logger.info("[CallServiceUrlLifecycleHook] didBecomeActive")
        Task {
            await CallServiceUrlManager.shared.onAppForegrounded()
            await CallServiceUrlManager.shared.startPeriodicRefresh()
        }
    }

    @objc private func handleDidEnterBackground() {
        Logger.info("[CallServiceUrlLifecycleHook] didEnterBackground")
        Task { await CallServiceUrlManager.shared.stopPeriodicRefresh() }
    }

    @objc private func handleReachabilityChanged() {
        let nowReachable = reachability?.isReachable() ?? false
        defer { lastReachable = nowReachable }
        guard !lastReachable && nowReachable else { return }
        Logger.info("[CallServiceUrlLifecycleHook] reachability not→yes")
        Task { await CallServiceUrlManager.shared.onNetworkRecovered() }
    }
}
