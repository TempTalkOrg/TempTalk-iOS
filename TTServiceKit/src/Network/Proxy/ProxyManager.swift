//
//  ProxyManager.swift
//  TTServiceKit
//
//  Runtime controller for the self-hosted proxy (TLS-in-TLS). Persists the user's
//  share link + on/off switch, starts/stops the in-process LocalTunnelProxy to match,
//  and exposes the loopback endpoint + active config to the URL / call paths.
//
//  Persistence uses a JSON file in the shared app-group container (not NSUserDefaults, not the
//  DB), readable at launch before the database is ready so the proxy can come up before the first
//  network request. The file is encrypted at rest (AES-256-GCM) with a per-install key in the
//  keychain: the share link can carry a TURN secret + proxy IP, so it is treated as sensitive.
//

import Foundation
import CryptoKit

/// Result of the most recent settings-page reachability probe, persisted so the entry row
/// (Security & Privacy) can show On / Off / Unavailable across launches.
@objc public enum ProxyProbeStatus: Int {
    case unknown      // never probed (or address just changed) — treat as On when enabled
    case available    // proxy reachable / connected through proxy
    case unavailable  // unreachable / verify failed / business link failed
}

/// The proxy routing decision for a single URLSession / IM socket build — one atomic snapshot from
/// `ProxyManager.urlSessionRouting()`.
///  • `.viaProxy(dict)`  — tunnel running: route through the loopback CONNECT proxy.
///  • `.failClosed(dict)` — proxy intended but tunnel down: route through a dead proxy so the
///     request FAILS instead of connecting direct and leaking the real IP.
///  • `.direct`          — proxy off: a normal direct connection (no proxy dict).
public enum ProxyRouting {
    case viaProxy([AnyHashable: Any])
    case failClosed([AnyHashable: Any])
    case direct
}

@objc
public final class ProxyManager: NSObject {

    @objc public static let shared = ProxyManager()

    /// Posted on the main thread whenever the proxy on/off/address changes. Long-lived network
    /// layers that froze the proxy dict at build time observe this to refresh — currently the REST
    /// session pool, which otherwise keeps routing to the old loopback port until its 5-min TTL.
    @objc public static let proxyConfigurationDidChangeNotificationName = "ProxyConfigurationDidChange"

    private static let keyShareLink = "proxy.shareLink"
    private static let keyEnabled = "proxy.enabled"
    private static let keyLastProbe = "proxy.lastProbe"
    private static let keyProtectCallIP = "proxy.protectCallIP"

    // Plaintext on/off marker (NOT the encrypted config): a single byte in the app-group container
    // written with NSFileProtectionNone, so the NSE / Share extension can read the user's proxy
    // intent even before first unlock — when the encrypted config's keychain key is unavailable —
    // and fail closed instead of leaking the real IP. Only the main app writes it.
    private static let enabledMarkerFileName = "proxy.enabled.marker"

    // At-rest encryption: a 256-bit key kept in the keychain (AfterFirstUnlockThisDeviceOnly, shared
    // across app/NSE/ShareExt via the same keychain-access-group as the GRDB key).
    private static let keychainService = "TTProxyConfigKey"
    private static let keychainKey = "master"
    private static let keyByteCount = 32

    // Self-heal debounce: ignore repeat rebuild requests within this window to avoid rebuild storms.
    private static let recoveryCooldown: TimeInterval = 30

    private let lock = NSLock()
    private let storeLock = NSLock()
    private let keyLock = NSLock()

    private var runningProxy: LocalTunnelProxy?
    private var startedPort: UInt16 = 0
    private var _activeConfig: ProxyConfig?
    private var cachedKey: SymmetricKey?

    // Timestamp of the last self-heal rebuild, guarded by `lock` (debounce — see recoveryCooldown).
    private var lastRecoveryAt: Date?

    // Bumped on every applyConfiguration entry. A run only installs its proxy if the generation is
    // still current at install time, so the LATEST call always wins regardless of which start()
    // finishes first — an earlier, slower start can't overwrite a newer config.
    private var configGeneration: UInt64 = 0

    private override init() {
        super.init()
    }

    // MARK: Persistence (app-group container file)
    //
    // Config lives in a JSON file in the shared app-group container — NOT NSUserDefaults.
    // NSUserDefaults proved unreliable here: cfprefsd serves a stale cached value across launches
    // (the on-disk plist updates, yet `UserDefaults.string(forKey:)` keeps returning the old value),
    // so a changed address silently reverted on restart. The file is the single source of truth,
    // read fresh on each access so the main app, NSE, and Share extension always agree.

    private static func configFileURL() -> URL? {
        guard let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: TSConstants.applicationGroup) else {
            return nil
        }
        return dir.appendingPathComponent("Library/Preferences/proxy.config.json")
    }

    private static func enabledMarkerURL() -> URL? {
        guard let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: TSConstants.applicationGroup) else {
            return nil
        }
        return dir.appendingPathComponent("Library/Preferences/\(enabledMarkerFileName)")
    }

    /// Mirror the on/off intent to the plaintext marker. `.noFileProtection` keeps it readable while
    /// the device is locked (before first unlock), which the encrypted config is not. Main app only.
    private func writeEnabledMarker(_ on: Bool) {
        guard let url = Self.enabledMarkerURL() else { return }
        do {
            if on {
                try Data([0x31]).write(to: url, options: [.atomic, .noFileProtection]) // "1"
            } else if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            Logger.error("[Proxy] failed to write enabled marker: \(error)")
        }
    }

    private func loadStore() -> [String: Any] {
        guard let url = Self.configFileURL(),
              let data = try? Data(contentsOf: url), !data.isEmpty else {
            return [:]
        }
        guard let key = proxyConfigKey() else {
            // Keychain unavailable (e.g. NSE launched before first unlock): treat as no config
            // (proxy off) rather than crash. A later unlocked read recovers it.
            return [:]
        }
        // Preferred path: AES-GCM ciphertext.
        if let plaintext = try? Self.decryptStore(data, key: key),
           let dict = (try? JSONSerialization.jsonObject(with: plaintext)) as? [String: Any] {
            return dict
        }
        // Lazy migration: an older build wrote plaintext JSON. Read it, then re-persist encrypted.
        // (Ciphertext never parses as JSON and plaintext never authenticates as GCM, so the two
        // paths can't be confused.)
        if let dict = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            Logger.info("[Proxy] migrating plaintext config to encrypted-at-rest")
            writeStore(dict, key: key)
            return dict
        }
        return [:]
    }

    /// Atomic read-modify-write of the config file: the whole load → mutate → write runs under
    /// `storeLock`, so concurrent writers can't lose each other's updates.
    private func mutateStore(_ mutate: (inout [String: Any]) -> Void) {
        storeLock.lock(); defer { storeLock.unlock() }
        var dict = loadStore()
        mutate(&dict)
        guard let key = proxyConfigKey() else {
            Logger.error("[Proxy] cannot persist config: encryption key unavailable")
            return
        }
        writeStore(dict, key: key)
    }

    /// Encrypt + atomically write the store. Best-effort: logs and returns on any failure.
    private func writeStore(_ dict: [String: Any], key: SymmetricKey) {
        guard let url = Self.configFileURL(),
              let json = try? JSONSerialization.data(withJSONObject: dict),
              let sealed = try? AES.GCM.seal(json, using: key).combined else {
            Logger.error("[Proxy] failed to encrypt/serialize proxy config")
            return
        }
        do {
            try sealed.write(to: url, options: .atomic)
        } catch {
            Logger.error("[Proxy] failed to write proxy config: \(error)")
        }
    }

    private static func decryptStore(_ data: Data, key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: key)
    }

    /// The AES-256-GCM key for `proxy.config.json`, fetched from the keychain (generated once on
    /// first use). Returns nil only when the keychain is genuinely unavailable (e.g. before first
    /// unlock) — callers then treat the config as empty. Crucially, a *transient* read failure
    /// never triggers regeneration, which would orphan the existing ciphertext.
    private func proxyConfigKey() -> SymmetricKey? {
        keyLock.lock(); defer { keyLock.unlock() }
        if let cachedKey { return cachedKey }

        let store = CurrentAppContext().keychainStorage()
        do {
            if let data = try store.optionalData(forService: Self.keychainService, key: Self.keychainKey) {
                guard data.count == Self.keyByteCount else {
                    // Wrong length — don't silently regenerate (would orphan existing ciphertext).
                    Logger.error("[Proxy] config key has unexpected length \(data.count)")
                    return nil
                }
                let key = SymmetricKey(data: data)
                cachedKey = key
                return key
            }
            // Missing (first run): generate + persist a fresh key.
            let fresh = SymmetricKey(size: .bits256)
            let raw = fresh.withUnsafeBytes { Data($0) }
            try store.set(data: raw, service: Self.keychainService, key: Self.keychainKey)
            cachedKey = fresh
            return fresh
        } catch {
            // Transient (keychain locked, etc.): do NOT generate a replacement key.
            Logger.warn("[Proxy] config key unavailable: \(error)")
            return nil
        }
    }

    /// Set/remove keys atomically. A nil value removes its key.
    private func setStoreValues(_ updates: [String: Any?]) {
        mutateStore { dict in
            for (key, value) in updates {
                if let value = value { dict[key] = value } else { dict.removeValue(forKey: key) }
            }
        }
    }

    // MARK: Persisted state

    /// The saved share link, regardless of the on/off switch (kept when disabled).
    public var savedShareLink: String? {
        let link = loadStore()[Self.keyShareLink] as? String
        return (link?.isEmpty == false) ? link : nil
    }

    /// The user's on/off intent (may be true even if the saved link is unparsable).
    public var isEnabledByUser: Bool {
        (loadStore()[Self.keyEnabled] as? Bool) ?? false
    }

    /// Effective state: enabled by the user AND the saved link parses.
    @objc public var isEnabled: Bool {
        // Gated to iOS 17+. The IM WSS routes through the proxy via URLSession's
        // `connectionProxyDictionary`, which `URLSessionWebSocketTask` only honors on iOS 17+; on
        // earlier versions it would connect DIRECT and leak the real client IP. So the feature is
        // hidden below 17 — the proxy is always considered off there, and nothing routes through it
        // (chat, calls, probes).
        guard #available(iOS 17, *) else { return false }
        guard isEnabledByUser, let link = savedShareLink, ProxyConfig.parse(link) != nil else {
            return false
        }
        return true
    }

    /// The user's proxy intent, read from the plaintext marker so it is available everywhere —
    /// including the NSE / Share extension before first unlock, when the encrypted config can't be
    /// decrypted. This is the source of truth for "should first-party traffic be forced through the
    /// proxy (or fail closed)". iOS 17+ only (the feature is gated there).
    @objc public var isProxyIntended: Bool {
        guard #available(iOS 17, *) else { return false }
        guard let url = Self.enabledMarkerURL(),
              let data = try? Data(contentsOf: url), data.first == 0x31 else {
            return false
        }
        return true
    }

    /// One atomic snapshot of how a URLSession / IM socket must route right now — the tunnel state
    /// is read once under the lock so the three cases can't disagree across separate reads. Reading
    /// `startedPort` twice (as `connectionProxyDictionary()` + a fail-closed check would) races a
    /// start/teardown transition and can leave a session with NO proxy dict → direct → leak. This
    /// mirrors `callProxyRouting()`, which snapshots config+loopback together for the same reason.
    public func urlSessionRouting() -> ProxyRouting {
        let intended = isProxyIntended
        // Gate the live tunnel on current intent, not just a non-zero port. A Share/NSE extension
        // starts its own tunnel once at launch and never re-applies; if the user later turns the
        // proxy off in the main app, the extension's port stays non-zero. Without this gate it would
        // keep routing through the stale tunnel against the user's current intent, so honor `intended`.
        guard intended else { return .direct }
        lock.lock(); defer { lock.unlock() }
        if startedPort != 0 {
            // kCFNetworkProxies* constants are macOS-only; the string keys work on iOS.
            return .viaProxy([
                "HTTPSEnable": 1,
                "HTTPSProxy": "127.0.0.1",
                "HTTPSPort": Int(startedPort)
            ])
        }
        return .failClosed(Self.failClosedProxyDict)
    }

    /// A connectionProxyDictionary pointing at a dead loopback port (used by `.failClosed`).
    /// URLSession fails the request (the proxy is unreachable) rather than connecting DIRECT, so the
    /// real IP never leaks. Nothing listens on loopback port 9 (discard); the live tunnel always
    /// binds a dynamic port, never this one.
    private static let failClosedProxyDict: [AnyHashable: Any] = [
        "HTTPSEnable": 1,
        "HTTPSProxy": "127.0.0.1",
        "HTTPSPort": 9
    ]

    /// While the proxy is enabled, the chat hosts everything pins to — the whitelisted IM domains
    /// from `proxy.tunnelDomains.chat` (else the tier-2 derived primary). Under proxy we suppress
    /// speed-test and dial only these (others would go direct and leak the real IP); failover
    /// rotates within this list. Empty when the proxy is disabled — original multi-domain logic applies.
    @objc public func tunnelChatDomains() -> [String] {
        guard isEnabled else { return [] }
        return ProxyTunnelConfig.tunnelDomains("chat")
    }

    /// Whether a service's REST URL must pin to the chat tunnel domains under proxy. True iff at
    /// least one of the service's candidate domains is in the chat tunnel whitelist — i.e. it rides
    /// the chat pool (chat / call / fileSharing / speech2text / grayCheck). CDN or other services
    /// (avatar, or any future single- or multi-CDN service) share no domain with the whitelist, so
    /// they are NOT pinned and resolve normally (the connection layer then routes them direct).
    /// Keyed on the same whitelist as `shouldTunnel`, so "what goes through the proxy" has one
    /// definition. The caller passes a `tunnelChatDomains()` snapshot so the gate and the URL build
    /// share one read (a mid-call cache invalidation can't make them disagree). False when disabled.
    func routesThroughChatTunnel(matchedDomains: [DTServerDomainEntity], tunnelDomains: [String]) -> Bool {
        guard isEnabled, !tunnelDomains.isEmpty else { return false }
        let tunnel = Set(tunnelDomains.map { $0.lowercased() })
        return matchedDomains.contains {
            tunnel.contains($0.domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        }
    }

    /// In-call IP protection (default off). Independent of `isEnabled`: gates ONLY whether calls
    /// route through the proxy; chat is unaffected. Persisted in the app-group suite.
    @objc public var protectCallIPEnabled: Bool {
        get { (loadStore()[Self.keyProtectCallIP] as? Bool) ?? false }
        set {
            setStoreValues([Self.keyProtectCallIP: newValue])
            Logger.info("[Proxy] in-call IP protection -> \(newValue ? "on" : "off")")
        }
    }

    /// The most recent probe verdict, reset to `.unknown` whenever the saved address changes.
    /// Read by the entry row to distinguish On vs Unavailable.
    @objc public var lastProbeStatus: ProxyProbeStatus {
        ProxyProbeStatus(rawValue: (loadStore()[Self.keyLastProbe] as? Int) ?? 0) ?? .unknown
    }

    /// Record the latest settings-page probe outcome. Persisted for the entry row.
    public func recordProbeResult(available: Bool) {
        setStoreValues([Self.keyLastProbe: (available ? ProxyProbeStatus.available : .unavailable).rawValue])
        Logger.info("[Proxy] probe verdict: \(available ? "available" : "unavailable")")
    }

    /// Parsed config of the running proxy, or nil when inactive. Read by the call paths
    /// (LiveKit signaling/media) to decide tunneling + TURN relay.
    public var activeConfig: ProxyConfig? {
        lock.lock(); defer { lock.unlock() }
        return _activeConfig
    }

    // MARK: Lifecycle

    /// Start/stop the local proxy to match persisted state. Call at app launch and after
    /// any save/toggle. Idempotent: tears down the running proxy first.
    @objc public func applyConfiguration() {
        // Mirror the on/off intent to the plaintext marker FIRST — before tearing down the running
        // tunnel — so there is no window where the listener port is already zero yet the marker still
        // reads "off": in that window `urlSessionRouting()` would return `.direct` and concurrent
        // HTTPS/WSS traffic could leak the real IP. Writing the marker up front keeps routing at
        // `.failClosed` across the whole teardown → restart window. Only the main app can read the
        // true intent (the extension's encrypted config may be undecryptable), so only it writes.
        if CurrentAppContext().isMainApp {
            let intended: Bool = {
                guard #available(iOS 17, *) else { return false }
                return isEnabledByUser
            }()
            writeEnabledMarker(intended)
        }

        // Tear down any running proxy and read the desired config under the lock.
        lock.lock()
        configGeneration &+= 1
        let myGeneration = configGeneration
        stopLocked()
        let target: ProxyConfig? = {
            // Gated to iOS 17+ (see `isEnabled`): never start the loopback tunnel below 17, so a
            // persisted enabled config (e.g. after a downgrade or backup restore) stays inert and
            // every routing accessor keeps returning nil / direct.
            guard #available(iOS 17, *) else { return nil }
            guard isEnabledByUser, let link = savedShareLink else { return nil }
            return ProxyConfig.parse(link)
        }()
        lock.unlock()

        guard let cfg = target else {
            Logger.info("[Proxy] inactive (disabled or no valid share link)")
            return
        }
        guard #available(iOS 13.0, *) else { return }

        // start() blocks on the listener semaphore (up to ~2s). Run it WITHOUT holding the lock so
        // readers (activeConfig / connectionProxyDictionary / callProxyRouting) and any concurrent
        // toggle aren't stalled for that window — only re-acquire to write the result.
        let proxy = LocalTunnelProxy(config: cfg)
        // Runtime loopback death → rebuild through the authoritative path (new port + socket cycle).
        proxy.onListenerFailed = { [weak self] in
            self?.recoverTunnelIfEnabled(reason: "loopback listener down")
        }
        let port: UInt16
        do {
            port = try proxy.start()
        } catch {
            Logger.error("[Proxy] failed to start: \(error)")
            proxy.stop()   // release the half-started listener (mirrors the stale-generation discard)
            return
        }

        lock.lock()
        // A newer applyConfiguration bumped the generation while we were starting; ours is stale —
        // discard it. Keying on the generation (not `runningProxy != nil`) makes the LATEST call win
        // regardless of start-time ordering: an earlier, slower start can no longer overwrite a
        // newer config just because it finished last.
        if myGeneration != configGeneration {
            lock.unlock()
            proxy.stop()
            Logger.info("[Proxy] discarded stale proxy (superseded during start)")
            return
        }
        runningProxy = proxy
        startedPort = port
        _activeConfig = cfg
        lock.unlock()
        Logger.info("[Proxy] active on 127.0.0.1:\(port)")
    }

    private func stopLocked() {
        if startedPort != 0 {
            Logger.info("[Proxy] stopped")
        }
        runningProxy?.stop()
        runningProxy = nil
        startedPort = 0
        _activeConfig = nil
    }

    /// Self-heal entry: rebuild the wedged loopback tunnel (foreground resume, or a runtime listener
    /// death). No-op when the proxy is off. Debounced (30s) to prevent rebuild storms. Runs the
    /// rebuild on a background queue because applyConfiguration → start() blocks up to ~2s on the
    /// listener semaphore, which must never sit on the caller's / main thread.
    ///
    /// Returns whether a rebuild was actually dispatched: `false` when skipped (disabled or within
    /// cooldown). The tier-2 watchdog relies on this so a cooldown-swallowed call — one another
    /// trigger's rebuild is already covering — does NOT consume its limited attempt budget.
    @discardableResult
    @objc(recoverTunnelIfEnabled:) public func recoverTunnelIfEnabled(reason: String) -> Bool {
        guard isEnabled else {
            Logger.info("[Proxy][self-heal] skipped: proxy disabled")
            return false
        }

        lock.lock()
        let now = Date()
        if let last = lastRecoveryAt, now.timeIntervalSince(last) < Self.recoveryCooldown {
            let left = Int(Self.recoveryCooldown - now.timeIntervalSince(last))
            lock.unlock()
            Logger.info("[Proxy][self-heal] skipped: within cooldown (\(left)s left)")
            return false
        }
        lastRecoveryAt = now
        lock.unlock()

        Logger.info("[Proxy][self-heal] rebuilding tunnel (\(reason))")
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            self.applyConfiguration()
            self.reconnectMainSocket()
        }
        return true
    }

    // MARK: User actions (called from the settings UI)

    /// Persist the share link + switch, then re-apply. Pass a plain `ytp://` link (encrypted
    /// links must be decoded to plain before saving so restarts don't re-prompt for a passphrase).
    public func save(shareLink: String?, enabled: Bool, completion: (() -> Void)? = nil) {
        mutateStore { dict in
            // A new address invalidates the prior probe verdict (probe runs after save).
            // Compare against the on-disk value inside the lock so a concurrent write can't make the
            // read-modify-write lose an update.
            let oldLink = (dict[Self.keyShareLink] as? String).flatMap { $0.isEmpty ? nil : $0 }
            if shareLink != oldLink {
                dict[Self.keyLastProbe] = ProxyProbeStatus.unknown.rawValue
            }
            if let shareLink { dict[Self.keyShareLink] = shareLink } else { dict.removeValue(forKey: Self.keyShareLink) }
            dict[Self.keyEnabled] = enabled
        }
        applyConfigurationOffMainThread(completion: completion)
    }

    public func setEnabled(_ enabled: Bool, completion: (() -> Void)? = nil) {
        setStoreValues([Self.keyEnabled: enabled])
        applyConfigurationOffMainThread(completion: completion)
    }

    /// Re-apply config + reconnect off the caller thread. `applyConfiguration` → `start()` blocks on
    /// the listener semaphore, so running it inline would freeze a settings toggle on the main thread.
    /// The persisted store is already updated synchronously by the caller, so the switch/address the
    /// UI reads is correct immediately; `completion` runs on the main thread once the tunnel is up
    /// (the settings probe waits for it). The fail-closed marker is written first inside
    /// `applyConfiguration`, so no real IP can leak during the async gap.
    private func applyConfigurationOffMainThread(completion: (() -> Void)?) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.applyConfiguration()
            self?.reconnectMainSocket()
            guard let completion else { return }
            DispatchQueue.main.async(execute: completion)
        }
    }

    public func clear() {
        setStoreValues([
            Self.keyShareLink: nil,
            Self.keyEnabled: nil,
            Self.keyLastProbe: nil
        ])
        applyConfiguration()
        reconnectMainSocket()
    }

    /// Re-apply the current proxy routing to the long-lived connections that froze it at build
    /// time, so a proxy on/off/address change takes effect immediately without an app restart.
    /// Only invoked on user-initiated changes — the launch-time applyConfiguration needs no reset
    /// since the first socket/session already reads the current state.
    private func reconnectMainSocket() {
        Logger.info("[Proxy] applying routing to live sessions (WSS cycle + REST pool + download)")
        DispatchQueue.main.async {
            // IM WSS: cycle so the rebuilt socket reads the current connectionProxyDictionary
            // (the main-service WSS must disconnect and reconnect).
            SSKEnvironment.shared.socketManagerRef.cycleSocket()
            // REST session pool: discard its pooled sessions (they froze the proxy dict at build
            // time) so REST recovers immediately instead of waiting out its 5-min TTL.
            NotificationCenter.default.post(
                name: Notification.Name(Self.proxyConfigurationDidChangeNotificationName),
                object: nil
            )
        }
        // Attachment downloads: DTFileDownloader's URLSession also froze the proxy dict and,
        // unlike the REST session pool, never expires — rebuild it so it stops routing to the
        // now-stopped local proxy port (otherwise only an app restart recovers downloads).
        DTFileDownloader.default().refreshDownloadSession()
    }

    // MARK: Accessors for the URL / call paths

    /// connectionProxyDictionary for a URLSessionConfiguration, or nil if the proxy isn't running.
    @objc public func connectionProxyDictionary() -> [AnyHashable: Any]? {
        lock.lock(); defer { lock.unlock() }
        guard startedPort != 0 else { return nil }
        // kCFNetworkProxies* constants are macOS-only; the string keys work on iOS.
        return [
            "HTTPSEnable": 1,
            "HTTPSProxy": "127.0.0.1",
            "HTTPSPort": Int(startedPort)
        ]
    }

    /// Atomic routing snapshot for a call: the active config together with the loopback endpoint,
    /// read under a single lock. `_activeConfig` and `startedPort` are always set/cleared together,
    /// so this can never return a config without its loopback — closing the read race where the
    /// call path could wire media through the proxy while WSS signaling silently went direct.
    /// nil when the proxy isn't running.
    public func callProxyRouting() -> (config: ProxyConfig, loopbackHost: String, loopbackPort: Int)? {
        lock.lock(); defer { lock.unlock() }
        guard startedPort != 0, let cfg = _activeConfig else { return nil }
        return (cfg, "127.0.0.1", Int(startedPort))
    }
}
