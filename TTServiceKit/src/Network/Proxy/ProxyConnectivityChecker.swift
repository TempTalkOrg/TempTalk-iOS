//
//  ProxyConnectivityChecker.swift
//  TTServiceKit
//
//  Settings-page reachability probe: does the proxy endpoint accept an outer TLS handshake
//  whose cert matches the share-link SPKI pin? Mirrors Android's ProxyConnectivityChecker.
//  Uses the same outer-TLS parameters as the live tunnel (ProxyOuterTLS), so a green result
//  means the real tunnel will also succeed.
//

import Foundation
import Network

@available(iOS 13.0, *)
public final class ProxyConnectivityChecker {

    public enum CheckResult: Equatable {
        case ok
        case cannotConnect   // TCP unreachable / refused
        case pinMismatch     // connected, but the outer cert failed the SPKI pin
        case timeout
    }

    private static let queue = DispatchQueue(label: "org.difft.proxy.checker")

    /// Probe `config`'s endpoint. `completion` is always called once, on the main queue.
    public static func check(_ config: ProxyConfig,
                             timeout: TimeInterval = 8,
                             completion: @escaping (CheckResult) -> Void) {
        guard let port = NWEndpoint.Port(rawValue: UInt16(config.port)) else {
            DispatchQueue.main.async { completion(.cannotConnect) }
            return
        }
        let endpoint = NWEndpoint.hostPort(host: .init(config.host), port: port)

        var finished = false
        var conn: NWConnection?
        let finish: (CheckResult) -> Void = { result in
            queue.async {
                guard !finished else { return }
                finished = true
                conn?.cancel()
                Logger.info("[Proxy] stage1 result=\(result)")
                DispatchQueue.main.async { completion(result) }
            }
        }

        // A rejected verify block makes NWConnection retry/wait instead of surfacing .failed(.tls),
        // so report the pin mismatch straight from the verify callback — otherwise a bad pin would
        // only ever be classified as a timeout.
        let params = ProxyOuterTLS.parameters(for: config, on: queue) { match in
            if !match { finish(.pinMismatch) }
        }
        conn = NWConnection(to: endpoint, using: params)

        conn?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                finish(.ok)
            case .failed(let error):
                // A TLS-layer failure means we reached the box but the cert didn't match the
                // pin; anything else is a transport-level reachability failure.
                if case .tls = error {
                    finish(.pinMismatch)
                } else {
                    finish(.cannotConnect)
                }
            default:
                break
            }
        }

        queue.asyncAfter(deadline: .now() + timeout) { finish(.timeout) }
        conn?.start(queue: queue)
    }
}
