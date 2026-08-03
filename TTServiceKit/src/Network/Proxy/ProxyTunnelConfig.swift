//
//  ProxyTunnelConfig.swift
//  TTServiceKit
//
//  Maps the `proxy` space of the server GlobalConfig — the runtime-delivered
//  tunnel whitelist that replaces the hardcoded `ProxyConfig.tunnelHostSuffixes`.
//
//  Wire shape (sibling of `call`, `meeting`, … at the GlobalConfig top level):
//  {
//    "proxy": {
//      "tunnelDomains": {
//        "chat": ["chat.test.chative.im"],
//        "call": ["test.ablivekit.org"]
//      }
//    }
//  }
//
//  Categories ("chat" / "call" / …) are kept for diagnostics but the routing
//  decision only needs the flattened union, so unknown future categories are
//  folded in automatically rather than requiring a code change.
//

import Foundation
import SignalCoreKit

public struct ProxyTunnelConfig: Equatable {

    /// Per-category domain lists exactly as delivered, normalized (lowercased,
    /// trimmed, empties dropped). Preserved mainly for logging / debugging.
    public let domainsByCategory: [String: [String]]

    /// Flattened, de-duplicated union of every category's domains. This is what
    /// the routing layer consults to decide tunnel vs direct.
    public let allDomains: Set<String>

    public var isEmpty: Bool { allDomains.isEmpty }

    /// - Parameter proxySpace: the `proxy` object from GlobalConfig, i.e. the value
    ///   returned for spaceName `"proxy"` (`{ "tunnelDomains": { … } }`). `nil` /
    ///   malformed input yields an empty config.
    public init(from proxySpace: [String: Any]?) {
        guard let tunnelDomains = proxySpace?["tunnelDomains"] as? [String: Any] else {
            self.domainsByCategory = [:]
            self.allDomains = []
            return
        }

        var byCategory: [String: [String]] = [:]
        var union: Set<String> = []
        for (category, value) in tunnelDomains {
            guard let rawList = value as? [String] else { continue }
            let cleaned = rawList
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            guard !cleaned.isEmpty else { continue }
            byCategory[category] = cleaned
            union.formUnion(cleaned)
        }
        self.domainsByCategory = byCategory
        self.allDomains = union
    }
}

// MARK: - Local (cached / bundled) GlobalConfig access

public extension ProxyTunnelConfig {

    /// Reads the `proxy` space from the locally cached-or-bundled GlobalConfig.
    /// `fetchConfigFromLocal` invokes its completion synchronously (see
    /// `DTServerConfigManager`), mirroring `DTEmojiConfig.serverEmojiConfig()`.
    static func fromLocalConfig() -> ProxyTunnelConfig {
        var proxySpace: [String: Any]?
        DTServerConfigManager.shared().fetchConfigFromLocal(withSpaceName: "proxy") { config, error in
            guard error == nil, let dict = config as? [String: Any] else { return }
            proxySpace = dict
        }
        return ProxyTunnelConfig(from: proxySpace)
    }

    static func fromLocalConfig(transaction: SDSAnyReadTransaction) -> ProxyTunnelConfig {
        var proxySpace: [String: Any]?
        DTServerConfigManager.shared().fetchConfigFromLocal(withSpaceName: "proxy", transaction: transaction) { config, error in
            guard error == nil, let dict = config as? [String: Any] else { return }
            proxySpace = dict
        }
        return ProxyTunnelConfig(from: proxySpace)
    }
}

// MARK: - Diagnostics: what the local (minimal) config exposes today

public extension ProxyTunnelConfig {

    /// Reads one space of the locally cached-or-bundled GlobalConfig synchronously.
    private static func localSpace(_ name: String) -> Any? {
        var result: Any?
        DTServerConfigManager.shared().fetchConfigFromLocal(withSpaceName: name) { config, error in
            guard error == nil else { return }
            result = config
        }
        return result
    }

    private static func host(of urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let host = URLComponents(string: trimmed)?.host, !host.isEmpty { return host.lowercased() }
        // Bare "host[:port]/path" without scheme.
        let noScheme = trimmed.replacingOccurrences(of: "wss://", with: "")
            .replacingOccurrences(of: "https://", with: "")
        let hostPart = noScheme.split(separator: "/").first.map(String.init) ?? noScheme
        let host = hostPart.split(separator: ":").first.map(String.init) ?? hostPart
        return host.isEmpty ? nil : host.lowercased()
    }

    /// The IM domain to tunnel: the first chat host in the local config.
    /// `domains[label~="chat"]` first, falling back to `hosts[servTo=="chat"]`.
    static func firstIMDomain() -> String? {
        let domains = (localSpace("domains") as? [[String: Any]]) ?? []
        if let chat = domains.first(where: { ($0["label"] as? String ?? "").lowercased().hasPrefix("chat") }),
           let domain = (chat["domain"] as? String)?.lowercased(), !domain.isEmpty {
            return domain
        }
        let hosts = (localSpace("hosts") as? [[String: Any]]) ?? []
        if let chatHost = hosts.first(where: { ($0["servTo"] as? String) == "chat" }),
           let name = (chatHost["name"] as? String)?.lowercased(), !name.isEmpty {
            return name
        }
        return nil
    }

    /// The call/LiveKit domain to tunnel: host of the first cluster's `global_url`.
    static func firstCallDomain() -> String? {
        let call = (localSpace("call") as? [String: Any]) ?? [:]
        guard let clusters = (call["callServers"] as? [String: Any])?["clusters"] as? [[String: Any]],
              let cluster = clusters.first,
              let urlString = cluster["global_url"] as? String else {
            return nil
        }
        return host(of: urlString)
    }

    /// Tier-2 fallback when no `proxy` space is delivered: derive a single primary domain per
    /// category from the local (minimal) GlobalConfig — first IM domain (chat) / first call domain.
    private static func derivedByCategory() -> [String: [String]] {
        var result: [String: [String]] = [:]
        if let im = firstIMDomain() { result["chat"] = [im] }
        if let call = firstCallDomain() { result["call"] = [call] }
        return result
    }

    /// Per-category tunnel domains, two-tier:
    /// 1. server-delivered `proxy.tunnelDomains` (explicit, by category), else
    /// 2. derived from the regular config (first IM domain / first call domain).
    private static func resolveByCategory() -> [String: [String]] {
        var result: [String: [String]]
        let explicit = fromLocalConfig().domainsByCategory
        if !explicit.isEmpty {
            Logger.info("[Proxy] tunnel whitelist: server config (chat=\(explicit["chat"]?.count ?? 0) call=\(explicit["call"]?.count ?? 0))")
            result = explicit
        } else {
            result = derivedByCategory()
            if result.isEmpty {
                Logger.warn("[Proxy] tunnel whitelist: no server config and nothing derived — using TSConstants chat baseline")
            } else {
                Logger.info("[Proxy] tunnel whitelist: tier-2 derived (chat=\(result["chat"]?.count ?? 0) call=\(result["call"]?.count ?? 0))")
            }
        }
        // Fail-closed baseline: never leave `chat` empty. Before the local GlobalConfig is ready
        // (early launch), both tiers can resolve nothing — yet the chat host actually dialed comes
        // from TSConstants' built-in defaults. An empty whitelist would misclassify that official
        // host as "not whitelisted", so LocalTunnelProxy would dial it DIRECT and leak the real IP.
        // TSConstants chat origins are always available, so seed them as the last resort.
        if (result["chat"] ?? []).isEmpty {
            let baseline = baselineChatDomains()
            if !baseline.isEmpty {
                result["chat"] = baseline
                Logger.info("[Proxy] tunnel whitelist: chat baseline from TSConstants (\(baseline.count))")
            }
        }
        return result
    }

    /// Last-resort chat whitelist: the flavor's built-in primary chat host. `defaultMainHost` is a
    /// compile-time constant (always available, even before any GlobalConfig loads) and — crucially —
    /// is read WITHOUT the proxy-aware `TSConstants.mainServiceURL` getter, which routes back through
    /// `tunnelChatDomains()` → this very resolution and would recurse to a stack overflow. It is the
    /// origin the chat path itself falls back to, so it is exactly the host that must stay tunneled.
    private static func baselineChatDomains() -> [String] {
        let host = TSConstants.defaultMainHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return host.isEmpty ? [] : [host]
    }

    /// The ordered tunnel domains for one category ("chat" / "call"). Connection paths pin to
    /// these under proxy (server config first, else the tier-2 derived primary). Memoized.
    static func tunnelDomains(_ category: String) -> [String] {
        return cachedResolved()[category] ?? []
    }

    /// Flattened union of every category — the exact-match whitelist `shouldTunnel` consults.
    static func effectiveTunnelDomains() -> Set<String> {
        return Set(cachedResolved().values.flatMap { $0 })
    }

    /// Memoized `resolveByCategory()`. Consulted per CONNECT / per chat URL resolution, so the
    /// underlying DB read + JSON parse is cached and only recomputed after a GlobalConfig
    /// update (`kServerConfigUpdatedNotify`) invalidates it.
    private static func cachedResolved() -> [String: [String]] {
        _ = cacheBootstrap
        if let cached = cacheLock.withLock({ cachedByCategory }) { return cached }
        let resolved = resolveByCategory()
        cacheLock.withLock { cachedByCategory = resolved }
        return resolved
    }

    /// Drop the memoized whitelist; next access recomputes.
    static func invalidateCache() {
        cacheLock.withLock { cachedByCategory = nil }
    }

    // Registered exactly once (static-let lazy init) to clear the cache on config update.
    private static let cacheBootstrap: Void = {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(kServerConfigUpdatedNotify),
            object: nil, queue: nil
        ) { _ in
            ProxyTunnelConfig.invalidateCache()
        }
    }()

    private static let cacheLock = UnfairLock()
    private static var cachedByCategory: [String: [String]]?
}
