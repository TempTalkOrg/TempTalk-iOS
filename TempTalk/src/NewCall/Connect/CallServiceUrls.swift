//
//  CallServiceUrls.swift
//  Difft
//
//  Created by Henry on 2026/5/7.
//  Copyright © 2026 Difft. All rights reserved.
//

import Foundation

// MARK: - Server response models

public struct ServiceUrls: Codable, Equatable {
    public let configVersion: Int
    public let primary: UrlInfo?
    public let fallback: [UrlInfo]
    public let ttl: Int
    public let serverTimestamp: TimeInterval?

    public enum ServerTimestampUnit { case seconds, milliseconds }

    public var serverTimestampUnit: ServerTimestampUnit {
        guard let ts = serverTimestamp else { return .milliseconds }
        return ts >= 1_000_000_000_000 ? .milliseconds : .seconds
    }

    public var serverTimestampSeconds: TimeInterval? {
        guard let ts = serverTimestamp else { return nil }
        switch serverTimestampUnit {
        case .milliseconds: return ts / 1000.0
        case .seconds: return ts
        }
    }

    public init(configVersion: Int,
                primary: UrlInfo?,
                fallback: [UrlInfo],
                ttl: Int,
                serverTimestamp: TimeInterval?) {
        self.configVersion = configVersion
        self.primary = primary
        self.fallback = fallback
        self.ttl = ttl
        self.serverTimestamp = serverTimestamp
    }

    enum CodingKeys: String, CodingKey {
        case configVersion = "config_version"
        case primary
        case fallback
        case ttl
        case serverTimestamp = "server_time"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        configVersion = try container.decode(Int.self, forKey: .configVersion)
        primary = try container.decodeIfPresent(UrlInfo.self, forKey: .primary)
        fallback = try container.decodeIfPresent([UrlInfo].self, forKey: .fallback) ?? []
        ttl = try container.decode(Int.self, forKey: .ttl)
        serverTimestamp = try container.decodeIfPresent(TimeInterval.self, forKey: .serverTimestamp)
    }
}

public struct UrlInfo: Codable, Equatable {
    public let addrs: [String]
    public let domain: String
    public let region: String?

    public init(addrs: [String], domain: String, region: String?) {
        self.addrs = addrs
        self.domain = domain
        self.region = region
    }
}

// MARK: - Connection attempt

public struct ConnectionAttempt: Equatable {
    public enum NodeType: String, Equatable { case primary, fallback }

    public let serverHost: String
    public let connectUrl: String
    public let useQuic: Bool
    public let nodeType: NodeType
    public let region: String?

    public init(serverHost: String,
                connectUrl: String,
                useQuic: Bool,
                nodeType: NodeType,
                region: String?) {
        self.serverHost = serverHost
        self.connectUrl = connectUrl
        self.useQuic = useQuic
        self.nodeType = nodeType
        self.region = region
    }
}

// MARK: - Connection planner

enum MeetingConnectionPlanner {

    /// Under proxy, `proxyCallDomains` (`proxy.tunnelDomains.call`, else tier-2 derived) fully
    /// determines the signaling targets — one attempt per listed domain, rotated on failure. The
    /// server-returned `serviceUrls` are IGNORED under proxy: their nodes may carry origins not in
    /// the tunnel whitelist, which would connect directly and leak the real IP.
    ///
    /// Signaling channel per attempt: QUIC-over-proxy (`https://domain`) when the share link has `q`,
    /// else WSS (`wss://domain`) which `withConnectionAttempt` routes through the loopback CONNECT
    /// tunnel. WSS-over-proxy needs iOS 17+ (older iOS ignores connectionProxyDictionary); such calls
    /// are blocked upstream in `proxyCallBlockReason`, so a WSS attempt here never connects directly.
    /// Off-proxy: original primary+fallback (IP + WSS) expansion.
    static func buildAttempts(serviceUrls: ServiceUrls?,
                              quicEnabled: Bool,
                              proxyActive: Bool = false,
                              proxyCallDomains: [String] = []) -> [ConnectionAttempt] {
        if proxyActive {
            let attempts = proxyCallDomains.compactMap { raw -> ConnectionAttempt? in
                let domain = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !domain.isEmpty else { return nil }
                return ConnectionAttempt(serverHost: domain,
                                         connectUrl: quicEnabled ? "https://\(domain)" : "wss://\(domain)",
                                         useQuic: quicEnabled,
                                         nodeType: .primary,
                                         region: nil)
            }
            return dedupe(attempts)
        }

        guard let serviceUrls else { return [] }

        var attempts: [ConnectionAttempt] = []
        if let primary = serviceUrls.primary {
            attempts.append(contentsOf: buildAttemptsForNode(primary, type: .primary, quicEnabled: quicEnabled))
        }
        for node in serviceUrls.fallback {
            attempts.append(contentsOf: buildAttemptsForNode(node, type: .fallback, quicEnabled: quicEnabled))
        }
        return dedupe(attempts)
    }

    private static func buildAttemptsForNode(_ node: UrlInfo,
                                             type: ConnectionAttempt.NodeType,
                                             quicEnabled: Bool) -> [ConnectionAttempt] {
        let domain = node.domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !domain.isEmpty else { return [] }

        var result: [ConnectionAttempt] = []
        if quicEnabled {
            for ip in node.addrs {
                let trimmed = ip.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                result.append(ConnectionAttempt(
                    serverHost: domain,
                    connectUrl: "https://\(trimmed)",
                    useQuic: true,
                    nodeType: type,
                    region: node.region
                ))
            }
        }
        result.append(ConnectionAttempt(
            serverHost: domain,
            connectUrl: "wss://\(domain)",
            useQuic: false,
            nodeType: type,
            region: node.region
        ))
        return result
    }

    private static func dedupe(_ attempts: [ConnectionAttempt]) -> [ConnectionAttempt] {
        var seen = Set<String>()
        return attempts.filter { seen.insert($0.connectUrl).inserted }
    }
}

// MARK: - Connection backoff

enum ConnectionBackoff {
    static let maxDelayMs: Int = 30_000
    static let maxFailures: Int = 20

    static func delayMs(forFailureCount n: Int) -> Int {
        switch n {
        case ..<2: return 0
        case 2: return 500
        case 3: return 1_000
        case 4: return 2_000
        case 5: return 5_000
        default:
            let multiplier = 1 << min(n - 5, 16)
            return min(5_000 * multiplier, maxDelayMs)
        }
    }

    static func reachedMaxFailures(_ n: Int) -> Bool { n > maxFailures }
}

// MARK: - Log masking

enum LogMask {
    /// `1.2.3.4` → `1.***.***.4`
    static func ip(_ raw: String) -> String {
        let parts = raw.split(separator: ".")
        guard parts.count == 4 else { return "***" }
        return "\(parts[0]).***.***.\(parts[3])"
    }

    /// `abcdefg.example.org` → `abc***.example.org`
    static func domain(_ raw: String) -> String {
        let parts = raw.split(separator: ".", maxSplits: 1)
        guard parts.count == 2 else { return "***" }
        let sub = parts[0]
        let prefix = sub.prefix(3)
        return "\(prefix)***.\(parts[1])"
    }

    /// `https://1.2.3.4` → `https://1.***.***.4`
    /// `wss://abcdefg.example.org` → `wss://abc***.example.org`
    static func url(_ raw: String) -> String {
        guard let range = raw.range(of: "://") else { return "***" }
        let scheme = raw[raw.startIndex..<range.upperBound]
        let host = String(raw[range.upperBound...])
        if host.first?.isNumber == true {
            return "\(scheme)\(ip(host))"
        }
        return "\(scheme)\(domain(host))"
    }

    static func attempt(_ a: ConnectionAttempt) -> String {
        "\(a.nodeType.rawValue)/\(a.useQuic ? "quic" : "wss") \(url(a.connectUrl))"
    }
}
