//
//  LocalTunnelProxy.swift
//  TTServiceKit
//
//  In-process loopback HTTP-CONNECT proxy. URLSession points its
//  `connectionProxyDictionary` at 127.0.0.1:<port>; this proxy reads the CONNECT
//  target host and either (a) tunnels through the self-hosted proxy with an outer
//  TLS hop (SPKI/cert pinning), or (b) connects directly (3rd-party CDN).
//
//  This is the iOS analog of Android's ProxyTunnelSocketFactory + ProxyTunnelDns.
//  Inner TLS (chative CA pinning) is unchanged — URLSession lays it on top of the
//  spliced byte stream exactly as if no proxy were present.
//

import Foundation
import Network
import Security
import CryptoKit

@available(iOS 13.0, *)
public final class LocalTunnelProxy {

    public private(set) var listenPort: UInt16 = 0

    /// Fired once when the loopback listener dies at runtime (after it was ready) and it was NOT our
    /// own stop(). The owner (ProxyManager) rebuilds via applyConfiguration — we deliberately do not
    /// self-restart here, since a new listener would bind a new port that startedPort / the proxy
    /// dictionary still wouldn't know about.
    public var onListenerFailed: (() -> Void)?

    private let config: ProxyConfig
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "org.difft.proxy.localtunnel", attributes: .concurrent)

    // Listener state is observed on `queue` (concurrent), so these flags are lock-guarded.
    private let stateLock = NSLock()
    private var listenerReady = false   // .ready seen at least once (startup vs runtime failure)
    private var isStopping = false      // stop() in progress — ignore the cancel it causes
    private var didReportFailure = false // onListenerFailed fired once, never again

    // Live client/upstream connections, so stop() can tear them ALL down on a rebuild. A wedged
    // upstream never signals completion, so its splice loop would otherwise keep both ends open
    // forever — exactly the state self-heal rebuilds through, so without this every rebuild would
    // strand a dead pair. Holding a strong ref here is what lets us cancel them; each connection
    // removes itself on its terminal state, so the map never grows unbounded.
    private let connLock = NSLock()
    private var liveConnections: [ObjectIdentifier: NWConnection] = [:]

    public init(config: ProxyConfig) {
        self.config = config
    }

    // MARK: Lifecycle

    /// Starts the loopback listener and returns the bound port once ready.
    public func start() throws -> UInt16 {
        let params = NWParameters.tcp
        params.requiredInterfaceType = .loopback   // 127.0.0.1 only — never exposed off-device
        params.allowLocalEndpointReuse = true

        let listener = try NWListener(using: params, on: .any)
        self.listener = listener

        let ready = DispatchSemaphore(value: 0)
        var startError: Error?

        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                self.listenPort = listener.port?.rawValue ?? 0
                self.markListenerReady()
                ready.signal()
            case .failed(let error):
                // Pre-ready .failed is a startup failure (feed the start() semaphore); a .failed
                // AFTER the listener was ready means the loopback wedged → self-heal via callback.
                if self.hasListenerBeenReady() {
                    self.handleRuntimeListenerDown("failed: \(error)")
                } else {
                    startError = error
                    ready.signal()
                }
            case .cancelled:
                // Ignored when it's our own stop(); otherwise treat as a runtime failure.
                self.handleRuntimeListenerDown("cancelled")
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] conn in
            self?.handleClient(conn)
        }
        listener.start(queue: queue)

        // Loopback listener readiness is effectively immediate (a local bind, no network); cap the
        // wait low so a pathological hang can't block the caller (NSE launch / app launch) for long.
        _ = ready.wait(timeout: .now() + 2)
        if let startError { throw startError }
        guard listenPort != 0 else {
            throw NSError(domain: "LocalTunnelProxy", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "listener did not become ready"])
        }
        Logger.info("[Proxy] local CONNECT proxy ready on 127.0.0.1:\(listenPort)")
        return listenPort
    }

    public func stop() {
        // Mark BEFORE cancel so the resulting .cancelled is recognized as our own and ignored.
        stateLock.lock()
        isStopping = true
        stateLock.unlock()
        listener?.cancel()
        listener = nil
        cancelAllConnections()
    }

    // MARK: Connection registry

    private func track(_ conn: NWConnection) {
        connLock.lock(); defer { connLock.unlock() }
        liveConnections[ObjectIdentifier(conn)] = conn
    }

    private func untrack(_ conn: NWConnection) {
        connLock.lock(); defer { connLock.unlock() }
        liveConnections.removeValue(forKey: ObjectIdentifier(conn))
    }

    private func cancelAllConnections() {
        connLock.lock()
        let conns = Array(liveConnections.values)
        liveConnections.removeAll()
        connLock.unlock()
        if !conns.isEmpty {
            Logger.info("[Proxy] tearing down \(conns.count) live connection(s)")
        }
        conns.forEach { $0.cancel() }
    }

    // MARK: Listener health

    private func markListenerReady() {
        stateLock.lock(); defer { stateLock.unlock() }
        listenerReady = true
    }

    private func hasListenerBeenReady() -> Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return listenerReady
    }

    /// Runtime death of the loopback listener. Reports at most once, and never for our own stop().
    /// Delegates the actual rebuild to ProxyManager (authoritative port + socket cycle) rather than
    /// re-listening here, which would strand the old port.
    private func handleRuntimeListenerDown(_ reason: String) {
        stateLock.lock()
        if isStopping || didReportFailure {
            stateLock.unlock()
            return
        }
        didReportFailure = true
        stateLock.unlock()
        Logger.warn("[Proxy] loopback listener down at runtime: \(reason)")
        onListenerFailed?()
    }

    /// connectionProxyDictionary to hand to URLSessionConfiguration. Routes HTTPS
    /// CONNECT through this loopback proxy. Inner TLS pinning stays untouched.
    public func proxyDictionary() -> [AnyHashable: Any] {
        // kCFNetworkProxies* constants are macOS-only; the string keys work on iOS.
        return [
            "HTTPSEnable": 1,
            "HTTPSProxy": "127.0.0.1",
            "HTTPSPort": Int(listenPort)
        ]
    }

    // MARK: Client side (URLSession -> us, plaintext over loopback)

    private func handleClient(_ client: NWConnection) {
        track(client)
        // Untrack on terminal state (weak client: while tracked the map holds the strong ref, so it
        // stays alive; after untrack it can deallocate — no retain cycle).
        client.stateUpdateHandler = { [weak self, weak client] state in
            switch state {
            case .cancelled, .failed:
                if let client { self?.untrack(client) }
            default:
                break
            }
        }
        client.start(queue: queue)
        readConnectRequest(on: client, accumulated: Data())
    }

    /// Reads until the CONNECT request headers terminate with CRLF CRLF.
    private func readConnectRequest(on client: NWConnection, accumulated: Data) {
        client.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let error {
                Logger.warn("[Proxy] client recv error: \(error)")
                client.cancel()
                return
            }
            var buffer = accumulated
            if let data { buffer.append(data) }

            guard let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) else {
                if isComplete || buffer.count > 16 * 1024 {
                    client.cancel()
                    return
                }
                self.readConnectRequest(on: client, accumulated: buffer)
                return
            }

            let headerData = buffer.subdata(in: buffer.startIndex..<headerEnd.lowerBound)
            // Any bytes after CRLFCRLF are already inner-TLS payload — preserve them.
            let leftover = buffer.subdata(in: headerEnd.upperBound..<buffer.endIndex)

            guard let target = self.parseConnectTarget(headerData) else {
                self.reply(client, status: "400 Bad Request") { client.cancel() }
                return
            }
            // Diagnostic: proves the CONNECT reached loopback (rules out a dead client/listener) and
            // records whether it takes the tunnel or goes direct.
            let tunnel = self.config.shouldTunnel(host: target.host)
            Logger.info("[Proxy] CONNECT -> \(target.host):\(target.port) (\(tunnel ? "tunnel" : "direct"))")
            self.openUpstream(for: target, client: client, pendingClientBytes: leftover)
        }
    }

    private struct Target { let host: String; let port: Int }

    private func parseConnectTarget(_ header: Data) -> Target? {
        guard let line = String(data: header, encoding: .utf8)?
            .components(separatedBy: "\r\n").first else { return nil }
        // "CONNECT host:port HTTP/1.1"
        let parts = line.split(separator: " ")
        guard parts.count >= 2, parts[0].uppercased() == "CONNECT" else { return nil }
        let hostPort = String(parts[1])
        guard let colon = hostPort.lastIndex(of: ":") else { return nil }
        let host = String(hostPort[hostPort.startIndex..<colon])
        let port = Int(hostPort[hostPort.index(after: colon)...]) ?? 443
        return Target(host: host, port: port)
    }

    // MARK: Upstream side (us -> proxy via outer TLS, or direct)

    private func openUpstream(for target: Target, client: NWConnection, pendingClientBytes: Data) {
        let upstream: NWConnection
        if config.shouldTunnel(host: target.host) {
            // Tunnel: connect to the proxy host:port with an OUTER TLS hop (pin fp).
            // The proxy's nginx-terminate peels the outer TLS; the inner TLS bytes that
            // the client sends afterwards reach the relay verbatim.
            // UInt16(clamping:) avoids a trap on an out-of-range port from a malformed link;
            // an invalid port just fails the upstream connect -> 502, no crash.
            let port = NWEndpoint.Port(rawValue: UInt16(clamping: config.port)) ?? .https
            let endpoint = NWEndpoint.hostPort(host: .init(config.host), port: port)
            upstream = NWConnection(to: endpoint, using: outerTlsParameters())
        } else {
            // Direct: plain TCP to the real host; client lays its own TLS on top.
            let port = NWEndpoint.Port(rawValue: UInt16(clamping: target.port)) ?? .https
            let endpoint = NWEndpoint.hostPort(host: .init(target.host), port: port)
            upstream = NWConnection(to: endpoint, using: .tcp)
        }

        track(upstream)
        // weak upstream/client: the handler is stored ON `upstream`, so a strong self-capture of
        // `upstream` (and its peer `client`) would be a retain cycle leaking every tunneled CONNECT
        // for the life of the process. While live, both are held strong by `liveConnections`, so the
        // weak refs stay valid; once untracked + cancelled they can deallocate.
        upstream.stateUpdateHandler = { [weak self, weak upstream, weak client] state in
            guard let self, let upstream, let client else { return }
            switch state {
            case .ready:
                self.reply(client, status: "200 Connection Established") {
                    // Flush any inner-TLS bytes that arrived glued to the CONNECT request.
                    if pendingClientBytes.isEmpty {
                        self.splice(from: client, to: upstream)
                    } else {
                        upstream.send(content: pendingClientBytes, completion: .contentProcessed { _ in
                            self.splice(from: client, to: upstream)
                        })
                    }
                    self.splice(from: upstream, to: client)
                }
            case .failed(let error):
                Logger.warn("[Proxy] upstream failed: \(error)")
                self.untrack(upstream)
                self.reply(client, status: "502 Bad Gateway") { client.cancel() }
                upstream.cancel()
            case .cancelled:
                self.untrack(upstream)
                client.cancel()
            default:
                break
            }
        }
        upstream.start(queue: queue)
    }

    /// Outer-layer TLS parameters: decoy SNI + SPKI fingerprint pinning, fully isolated from
    /// the chative CA. Shared with ProxyConnectivityChecker via ProxyOuterTLS.
    private func outerTlsParameters() -> NWParameters {
        return ProxyOuterTLS.parameters(for: config, on: queue)
    }

    // MARK: Plumbing

    private func reply(_ client: NWConnection, status: String, then: @escaping () -> Void) {
        let response = "HTTP/1.1 \(status)\r\n\r\n"
        client.send(content: Data(response.utf8), completion: .contentProcessed { _ in then() })
    }

    /// One-directional byte pump. Two of these (client<->upstream) form the full splice.
    private func splice(from src: NWConnection, to dst: NWConnection) {
        src.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            // If the proxy was torn down, stop pumping and close both ends rather than retaining self.
            guard let self else {
                dst.cancel()
                src.cancel()
                return
            }
            if let data, !data.isEmpty {
                dst.send(content: data, completion: .contentProcessed { _ in })
            }
            if isComplete || error != nil {
                dst.cancel()
                src.cancel()
                return
            }
            self.splice(from: src, to: dst)
        }
    }
}
