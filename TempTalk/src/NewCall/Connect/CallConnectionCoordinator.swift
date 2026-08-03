//
//  CallConnectionCoordinator.swift
//  Difft
//
//  Created by Henry on 2026/5/7.
//  Copyright © 2026 Difft. All rights reserved.
//

import Foundation
import LiveKit
import TTServiceKit

// MARK: - Local CA certificate

/// 端上自签根 CA：复用 HTTP pinning 用的 DifftCyberTrustRoot.cer，DER→PEM 后给 LiveKit ConnectOptions 用。
enum LocalCACertificate {
    private static let bundleResourceName = "DifftCyberTrustRoot"
    private static let bundleResourceExt = "cer"

    static let pem: String? = loadPemFromBundle()

    private static func loadPemFromBundle() -> String? {
        guard let url = bundleURL() else {
            Logger.error("[LocalCACertificate] missing \(bundleResourceName).\(bundleResourceExt) in bundle")
            return nil
        }
        do {
            let der = try Data(contentsOf: url)
            let base64 = der.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
            return "-----BEGIN CERTIFICATE-----\n\(base64)\n-----END CERTIFICATE-----\n"
        } catch {
            Logger.error("[LocalCACertificate] read failed: \(error.localizedDescription)")
            return nil
        }
    }

    private static func bundleURL() -> URL? {
        if let url = Bundle.main.url(forResource: bundleResourceName, withExtension: bundleResourceExt) {
            return url
        }
        for bundle in Bundle.allBundles + Bundle.allFrameworks {
            if let url = bundle.url(forResource: bundleResourceName, withExtension: bundleResourceExt) {
                return url
            }
        }
        return nil
    }
}

// MARK: - TURN-TLS SPKI pin verifier (a22)

/// Pins the self-hosted proxy's coturn leaf certificate on the outer TURN-TLS hop, using the same
/// SPKI fingerprint (share-link `f`) as the signaling tunnel. Media itself stays DTLS-SRTP e2e;
/// this only hardens the transport-camouflage TLS. Replaces the fork's `insecureSkipVerify` (a22
/// exposes the native `SSLCertificateVerifier` hook + `IceServer.tlsCertPolicy = .secure`).
struct ProxyTurnTlsVerifier: SSLCertificateVerifier {
    let expectedPin: String

    func verify(certificate: Data) -> Bool {
        guard let digest = ProxyOuterTLS.spkiSha256Base64(fromDERCertificate: certificate) else {
            Logger.error("[newcall][proxy] TURN-TLS: cannot derive SPKI from leaf cert")
            return false
        }
        let match = (digest == expectedPin)
        if !match {
            Logger.error("[newcall][proxy] TURN-TLS SPKI pin mismatch")
        }
        return match
    }
}

// MARK: - Proxy routing error

enum ProxyRoutingError: Error {
    /// In-call IP protection is on but the proxy tunnel isn't running. We abort the attempt
    /// instead of falling back to a direct connection that would leak the real IP.
    case tunnelUnavailable
}

// MARK: - ConnectOptions adapter

extension ConnectOptions {
    func withConnectionAttempt(_ attempt: ConnectionAttempt,
                               quicCidTag: String,
                               quicDeviceType: Int = 1,
                               caCertPem: String? = LocalCACertificate.pem) throws -> ConnectOptions {
        // Self-hosted proxy: media relays through the operator's coturn (RELAY-only ICE, outer
        // TURN-TLS SPKI-pinned). Signaling hides the IP via QUIC-over-proxy (MASQUE, share-link `q`)
        // or WSS over the app's loopback CONNECT tunnel (iOS 17+). All fields nil/unchanged
        // off-proxy, so this is a no-op when inactive.
        // proxyRelayServers is non-nil only when relaying media through the proxy's TURN; that case
        // forces .relay policy.
        var proxyRelayServers: [IceServer]?
        var turnVerifier: (any SSLCertificateVerifier)?
        var quicProxyHost: String?
        var quicProxyPort = 0
        var quicProxySni: String?
        var quicProxySpkiPin: String?
        var webSocketProxyHost: String?
        var webSocketProxyPort = 0

        // Calls route through the proxy only when BOTH switches are on: proxy enabled AND in-call IP
        // protection on. Either off → skip this block → all fields keep their direct-connection
        // defaults (no TURN relay, no signaling proxy), i.e. a normal direct call.
        if ProxyManager.shared.isEnabled, ProxyManager.shared.protectCallIPEnabled {
            // One atomic snapshot for config + loopback: they are set/cleared together under the
            // manager's lock, so this can't hand back a config without its loopback. If the tunnel
            // isn't up, fail closed — the user asked to protect their call IP, so aborting is
            // correct; falling back to a direct connection would leak the real IP.
            guard let routing = ProxyManager.shared.callProxyRouting() else {
                Logger.error("[newcall][proxy] call IP protection on but tunnel unavailable -> aborting attempt to avoid IP leak")
                throw ProxyRoutingError.tunnelUnavailable
            }
            let cfg = routing.config
            // Media: turns:443 stealth, .secure + SPKI-pin verifier (DTLS-SRTP stays e2e).
            if cfg.turnEnabled(), let cred = cfg.turnCredentials() {
                // Dual media path: always offer turns:443 (TLS, DPI-camouflaged); if
                // the share link declares `tu`, also offer a plaintext turn:<host>:<tu> (UDP) candidate
                // so clients that can't clear the self-signed turns:443 handshake still relay media.
                // Both ride the same TURN-REST credential; ICE picks whichever connects. The .secure
                // cert policy and SPKI verifier only apply to the TLS (turns:) URL — the plaintext
                // turn: URL has no TLS handshake, so it is unaffected.
                var turnUrls = ["turns:\(cfg.host):\(cfg.port)?transport=tcp"]
                if let tu = cfg.turnUdpPort {
                    turnUrls.append("turn:\(cfg.host):\(tu)?transport=udp")
                }
                proxyRelayServers = [IceServer(
                    urls: turnUrls,
                    username: cred.username,
                    credential: cred.password,
                    tlsCertPolicy: .secure
                )]
                turnVerifier = ProxyTurnTlsVerifier(expectedPin: cfg.fingerprintBase64)
                Logger.info("[newcall][proxy] media relay enabled (RELAY-only ICE, turns:443\(cfg.turnUdpPort != nil ? "+turn:udp" : ""), SPKI-pinned)")
            } else {
                Logger.error("[newcall][proxy] proxy active but TURN not configured -> media NOT relayed")
            }
            // WSS signaling (and the SDK's QUIC→WS fallback) tunnels through the app's loopback
            // CONNECT proxy, from the same atomic snapshot as the config above. Honored only on
            // iOS 17+; without `q`, older iOS is blocked upstream in proxyCallBlockReason, so a WSS
            // attempt never goes direct and leaks.
            webSocketProxyHost = routing.loopbackHost
            webSocketProxyPort = routing.loopbackPort
            // QUIC signaling hides the IP via MASQUE. attempt.useQuic is true only when the share
            // link declared `q` (gated in connectToRoomWithFailover).
            if attempt.useQuic {
                quicProxyHost = cfg.host
                quicProxyPort = cfg.port
                quicProxySni = cfg.outerSni()
                quicProxySpkiPin = cfg.fingerprintBase64
                Logger.info("[newcall][proxy] signaling via QUIC MASQUE proxy")
            } else {
                Logger.info("[newcall][proxy] signaling via WSS over loopback tunnel")
            }
        }

        return ConnectOptions(
            autoSubscribe: autoSubscribe,
            reconnectAttempts: reconnectAttempts,
            reconnectAttemptDelay: reconnectAttemptDelay,
            reconnectMaxDelay: reconnectMaxDelay,
            socketConnectTimeoutInterval: socketConnectTimeoutInterval,
            primaryTransportConnectTimeout: primaryTransportConnectTimeout,
            publisherTransportConnectTimeout: publisherTransportConnectTimeout,
            iceServers: proxyRelayServers ?? iceServers,
            // .relay suppresses host/srflx candidates so the real IP never enters media.
            iceTransportPolicy: proxyRelayServers == nil ? iceTransportPolicy : .relay,
            isDscpEnabled: isDscpEnabled,
            enableMicrophone: enableMicrophone,
            protocolVersion: protocolVersion,
            ttCallRequest: ttCallRequest,
            userAgent: userAgent,
            transportKind: attempt.useQuic ? .quic : .websocket,
            quicDeviceType: quicDeviceType,
            quicCidTag: quicCidTag,
            caCertPem: caCertPem,
            serverHost: attempt.serverHost,
            quicProxyHost: quicProxyHost,
            quicProxyPort: quicProxyPort,
            quicProxySni: quicProxySni,
            quicProxySpkiPin: quicProxySpkiPin,
            webSocketProxyHost: webSocketProxyHost,
            webSocketProxyPort: webSocketProxyPort,
            sslCertificateVerifier: turnVerifier
        )
    }
}

// MARK: - Reporter

public protocol CallConnectionReporting: AnyObject {
    func reportAttemptFailed(attempt: ConnectionAttempt, error: Error)
    func reportChannelDowngrade(success: ConnectionAttempt, toFallback: Bool, toWss: Bool)
}

public final class CallStatisticsLogManager: CallConnectionReporting {

    public static let shared = CallStatisticsLogManager()
    private let logTag = "[newcall][stats]"
    private init() {}

    public func reportAttemptFailed(attempt: ConnectionAttempt, error: Error) {
        let nsError = error as NSError
        Logger.info("\(logTag) connect_attempt_failed \(LogMask.attempt(attempt)) region=\(attempt.region ?? "nil") errDomain=\(nsError.domain) errCode=\(nsError.code) errMsg=\(error.localizedDescription)")
    }

    public func reportChannelDowngrade(success: ConnectionAttempt, toFallback: Bool, toWss: Bool) {
        Logger.info("\(logTag) channel_downgraded \(LogMask.attempt(success)) region=\(success.region ?? "nil") toFallback=\(toFallback) toWss=\(toWss)")
    }
}

// MARK: - Coordinator

/// 入会建链 3 阶段 failover：cache → forceRefresh → assets。
@MainActor
public final class CallConnectionCoordinator {

    private let logTag = "[newcall][coordinator]"

    /// 失败重试期间为 true，外部 RoomEventDispatcher 应屏蔽 Disconnected/FailedToConnect。
    public private(set) var isRetryUrlConnecting: Bool = false

    public init() {}

    public enum CoordinatorError: Error {
        case maxFailuresExceeded
        case allPhasesExhausted
    }

    enum ErrorCategory: String { case transient, fatal }

    @discardableResult
    public func connectToRoomWithFailover(
        connectAttempt: @MainActor @Sendable (ConnectionAttempt) async throws -> Void,
        reporter: CallConnectionReporting? = nil
    ) async throws -> ConnectionAttempt {

        isRetryUrlConnecting = true
        defer { isRetryUrlConnecting = false }

        var failureCount = 0
        // Under proxy, signaling hides the IP via QUIC-over-proxy (MASQUE) when the share link has
        // `q`, otherwise via WSS over the loopback CONNECT tunnel (iOS 17+; older iOS without `q` is
        // blocked in proxyCallBlockReason, never falling back to a leaking direct WSS). Off-proxy:
        // gray-release flag. Calls route through the proxy only when BOTH switches are on: proxy
        // enabled AND in-call IP protection on. Either off → direct call (gray-release flag below).
        let proxyActive = ProxyManager.shared.isEnabled && ProxyManager.shared.protectCallIPEnabled
        let proxyConfig = proxyActive ? ProxyManager.shared.activeConfig : nil
        let quicEnabled = proxyActive ? (proxyConfig?.quicEnabled ?? false)
                                      : GrayReleaseManager.shared.isQuicEnabled
        if proxyActive {
            Logger.info("\(logTag) call routing: VIA PROXY (signaling=\(quicEnabled ? "QUIC-over-proxy" : "WSS-over-tunnel"))")
        } else if ProxyManager.shared.isEnabled {
            Logger.info("\(logTag) call routing: DIRECT (proxy on, in-call IP protection off)")
        } else {
            Logger.info("\(logTag) call routing: DIRECT (proxy off)")
        }

        // Under proxy, call signaling targets come straight from proxy.tunnelDomains.call (server
        // config, else tier-2 derived) — not the server-returned node list — so we never dial an
        // origin outside the tunnel whitelist. Multiple domains rotate on failure.
        let proxyCallDomains = proxyActive ? ProxyTunnelConfig.tunnelDomains("call") : []

        Logger.info("\(logTag) phase 0 start (quic=\(quicEnabled))")
        let cached = await CallServiceUrlManager.shared.bestEffortServiceUrls()
        let attempts0 = MeetingConnectionPlanner.buildAttempts(serviceUrls: cached, quicEnabled: quicEnabled, proxyActive: proxyActive, proxyCallDomains: proxyCallDomains)
        if let success = try await tryAttempts(attempts0, failureCount: &failureCount, proxyActive: proxyActive, connectAttempt: connectAttempt, reporter: reporter) {
            reportDowngradeIfNeeded(success: success, reporter: reporter)
            return success
        }

        Logger.info("\(logTag) phase 1 start (delay 2000ms)")
        try await Task.sleep(nanoseconds: 2_000_000_000)
        // Under proxy the node is pinned to the whitelist, so re-fetching the URL list is pointless —
        // reuse the cached URLs (periodic refresh still updates them in the background).
        let refreshed: ServiceUrls? = proxyActive
            ? await CallServiceUrlManager.shared.bestEffortServiceUrls()
            : (try? await CallServiceUrlManager.shared.forceRefresh())
        let attempts1 = MeetingConnectionPlanner.buildAttempts(serviceUrls: refreshed, quicEnabled: quicEnabled, proxyActive: proxyActive, proxyCallDomains: proxyCallDomains)
        if let success = try await tryAttempts(attempts1, failureCount: &failureCount, proxyActive: proxyActive, connectAttempt: connectAttempt, reporter: reporter) {
            reportDowngradeIfNeeded(success: success, reporter: reporter)
            return success
        }

        Logger.info("\(logTag) phase 2 start (delay 5000ms)")
        try await Task.sleep(nanoseconds: 5_000_000_000)
        let assets = await CallServiceUrlManager.shared.bestEffortServiceUrls()
        let attempts2 = MeetingConnectionPlanner.buildAttempts(serviceUrls: assets, quicEnabled: quicEnabled, proxyActive: proxyActive, proxyCallDomains: proxyCallDomains)
        if let success = try await tryAttempts(attempts2, failureCount: &failureCount, proxyActive: proxyActive, connectAttempt: connectAttempt, reporter: reporter) {
            reportDowngradeIfNeeded(success: success, reporter: reporter)
            return success
        }

        Logger.error("\(logTag) all phases exhausted, throwing timeout (failureCount=\(failureCount))")
        throw CoordinatorError.allPhasesExhausted
    }

    private func tryAttempts(
        _ attempts: [ConnectionAttempt],
        failureCount: inout Int,
        proxyActive: Bool,
        connectAttempt: @MainActor @Sendable (ConnectionAttempt) async throws -> Void,
        reporter: CallConnectionReporting?
    ) async throws -> ConnectionAttempt? {

        guard !attempts.isEmpty else {
            Logger.info("\(logTag) no attempts to try")
            return nil
        }

        for attempt in attempts {
            if ConnectionBackoff.reachedMaxFailures(failureCount) {
                Logger.error("\(logTag) failure count \(failureCount) exceeded max \(ConnectionBackoff.maxFailures)")
                throw CoordinatorError.maxFailuresExceeded
            }
            if failureCount > 0 {
                let delayMs = ConnectionBackoff.delayMs(forFailureCount: failureCount)
                if delayMs > 0 {
                    try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                }
            }
            Logger.info("\(logTag) attempting \(LogMask.attempt(attempt)) failureCount=\(failureCount)")

            let attemptStart = Date()
            do {
                try await connectAttempt(attempt)
                let ms = Int(Date().timeIntervalSince(attemptStart) * 1000)
                Logger.info("\(logTag) attempt succeeded: \(LogMask.attempt(attempt)) in \(ms)ms")
                return attempt
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failureCount += 1
                let ms = Int(Date().timeIntervalSince(attemptStart) * 1000)
                let category = Self.classify(error: error)
                Logger.error("\(logTag) attempt failed \(LogMask.attempt(attempt)) in \(ms)ms (category=\(category)): \(error.localizedDescription)")
                reporter?.reportAttemptFailed(attempt: attempt, error: error)

                switch category {
                case .fatal:
                    throw error
                case .transient:
                    // Under proxy the node list is pinned to the whitelist; re-fetching on failure
                    // won't change it, so skip the refresh (periodic refresh still runs in background).
                    if !proxyActive {
                        Task { await CallServiceUrlManager.shared.refreshAfterConnectionFailure() }
                    }
                    continue
                }
            }
        }
        return nil
    }

    private func reportDowngradeIfNeeded(success: ConnectionAttempt, reporter: CallConnectionReporting?) {
        guard let reporter else { return }
        let downgradedToFallback = success.nodeType == .fallback
        let downgradedToWss = !success.useQuic && GrayReleaseManager.shared.isQuicEnabled
        if downgradedToFallback || downgradedToWss {
            reporter.reportChannelDowngrade(success: success,
                                            toFallback: downgradedToFallback,
                                            toWss: downgradedToWss)
        }
    }

    static func classify(error: Error) -> ErrorCategory {
        // Proxy tunnel unavailable is non-recoverable within a call attempt: don't burn the whole
        // retry budget (2s+5s phases + backoff) hitting the same fail-closed guard — abort now.
        if error is ProxyRoutingError { return .fatal }
        if let lkError = error as? LiveKitError {
            switch lkError.type {
            case .network, .timedOut, .serverPingTimedOut, .reconnectFailure, .validation, .unknown:
                return .transient
            default:
                return .fatal
            }
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain ||
            nsError.domain == NSPOSIXErrorDomain ||
            nsError.domain == kCFErrorDomainCFNetwork as String {
            return .transient
        }
        return .transient
    }
}
