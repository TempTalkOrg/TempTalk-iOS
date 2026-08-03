//
//  ProxyE2eProbe.swift
//  TTServiceKit
//
//  Stage-2 (end-to-end) proxy probe: after stage 1 proves the outer hop, this sends a
//  plain HTTPS GET to a real TempTalk self-cert origin THROUGH the running tunnel, to
//  prove relay routing + origin reachability. Contract is shared across clients.
//
//  Contract (must stay identical across clients):
//  - Target host: a `certType=self` chat origin (in the tunnel whitelist, self-signed CA,
//    readable pre-login). Derived from TSConstants chat/root service URLs.
//  - Request: GET https://<self-host>/ (absolute URL), inner chative-CA trust, no auth token,
//    no business interceptors, 8s timeout, routed through the loopback proxy.
//  - Verdict: ANY HTTP response (incl. 4xx/5xx) = OK (transport + routing proven). Only a
//    network/TLS/timeout failure = FAILED. Hosts tried in order; first success wins.
//

import Foundation

@available(iOS 13.0, *)
public final class ProxyE2eProbe {

    public enum ProbeResult: Equatable {
        case ok
        case failed
    }

    private static let timeout: TimeInterval = 8

    /// Probe end-to-end reachability through the currently running proxy. `completion` is
    /// always called once on the main queue. Requires the proxy to be active (a live
    /// `connectionProxyDictionary`); otherwise reports `.failed`.
    public static func probe(completion: @escaping (ProbeResult) -> Void) {
        let hosts = selfCertHosts()
        guard !hosts.isEmpty else {
            Logger.warn("[Proxy] e2e no self-cert host available -> FAILED")
            DispatchQueue.main.async { completion(.failed) }
            return
        }
        guard ProxyManager.shared.connectionProxyDictionary() != nil else {
            Logger.warn("[Proxy] e2e proxy not running -> FAILED")
            DispatchQueue.main.async { completion(.failed) }
            return
        }
        attempt(hosts: hosts, index: 0, completion: completion)
    }

    private static func attempt(hosts: [String], index: Int,
                                completion: @escaping (ProbeResult) -> Void) {
        guard index < hosts.count else {
            Logger.warn("[Proxy] e2e all hosts failed -> FAILED")
            DispatchQueue.main.async { completion(.failed) }
            return
        }
        let host = hosts[index]
        let session = makeSession()
        // Any HTTP response (incl. 4xx/5xx) proves transport+routing — don't treat as error.
        session.require2xxOr3xx = false
        session.failOnError = false
        session.shouldHandleRemoteDeprecation = false

        session.dataTaskPromise("https://\(host)/", method: .get, ignoreAppExpiry: true)
            .done(on: DispatchQueue.main) { _ in
                Logger.info("[Proxy] e2e OK")
                completion(.ok)
            }
            .catch(on: DispatchQueue.global()) { _ in
                Logger.warn("[Proxy] e2e host failed — trying next")
                attempt(hosts: hosts, index: index + 1, completion: completion)
            }
    }

    private static func makeSession() -> OWSURLSession {
        let config = OWSURLSession.defaultConfigurationWithoutCaching
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout
        // Route through the in-process tunnel exactly like normal traffic — from one atomic
        // snapshot. If the tunnel dropped since probe() checked (each host rebuilds this session),
        // fail closed via a dead proxy so the probe GET errors out instead of hitting the self-cert
        // chat host DIRECT and leaking the real IP.
        switch ProxyManager.shared.urlSessionRouting() {
        case .viaProxy(let dict), .failClosed(let dict):
            config.connectionProxyDictionary = dict
        case .direct:
            break
        }
        // signalServiceSecurityPolicy = chative-CA pinning (self host is self-signed).
        return OWSURLSession(
            serviceType: .mainSignalService,
            securityPolicy: OWSURLSession.signalServiceSecurityPolicy,
            configuration: config
        )
    }

    /// Ordered, de-duplicated list of `certType=self` chat origins to probe. Derived from the
    /// live chat/root service URLs (always self-cert, always in the tunnel whitelist, readable
    /// pre-login). NEVER use an authority host (srv.* / CDN) — it routes direct = false positive.
    private static func selfCertHosts() -> [String] {
        var hosts: [String] = []
        for urlString in [TSConstants.mainServiceURL, TSConstants.rootServiceURL] {
            if let host = URL(string: urlString)?.host, !hosts.contains(host) {
                hosts.append(host)
            }
        }
        return hosts
    }
}
