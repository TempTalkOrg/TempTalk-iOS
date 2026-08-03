//
//  Copyright (c) 2022 Open Whisper Systems. All rights reserved.
//

import Foundation
//import TTMessaging
//import Starscream

@objc
public class WebSocketFactoryHybrid: NSObject, WebSocketFactory {

    public var canBuildWebSocket: Bool { true }

    public func buildSocket(request: URLRequest,
                            callbackQueue: DispatchQueue) -> SSKWebSocket? {
        // One atomic routing snapshot (avoids racing a tunnel start/teardown across two reads).
        switch ProxyManager.shared.urlSessionRouting() {
        case .failClosed:
            // Proxy on but tunnel not ready: connecting the IM WSS directly would leak the real
            // client IP, so return a socket that never dials — it just reports failure and
            // OWSWebSocket retries; a later rebuild picks the proxied transport once the tunnel is up.
            return SSKWebSocketFailClosed(callbackQueue: callbackQueue)
        case .viaProxy(let dict):
            return SSKWebSocketNative(request: request, callbackQueue: callbackQueue, proxyDictionary: dict)
        case .direct:
            return SSKWebSocketNative(request: request, callbackQueue: callbackQueue, proxyDictionary: nil)
        }
    }

    public func statusCode(forError error: Error) -> Int {
        switch error {
//        case let error as StarscreamError:
//            return error.code
        case SSKWebSocketNativeError.failedToConnect(let statusCode):
            return statusCode ?? 0
        case SSKWebSocketNativeError.remoteClosed(let statusCode, _):
            return statusCode
        default:
            return error.httpStatusCode ?? 0
        }
    }
}

// MARK: -

/// The self-hosted proxy's tunnel isn't carrying traffic. Reported by the fail-closed socket so
/// callers never mistake it for a routed connection.
public enum SSKWebSocketProxyError: Error {
    case tunnelUnavailable
}

/// A no-op `SSKWebSocket` that never opens a connection. The factory returns this — instead of the
/// direct-connecting `SSKWebSocketNative` — when the proxy is enabled but its tunnel isn't ready:
/// dialing directly would leak the real client IP, so we fail closed. `connect()` immediately
/// reports a disconnect; `OWSWebSocket` then retries, and once the tunnel comes up a later
/// `buildSocket` returns the proxied transport instead.
final class SSKWebSocketFailClosed: SSKWebSocket {

    private static let idCounter = AtomicUInt(lock: .sharedGlobal)
    let id = SSKWebSocketFailClosed.idCounter.increment()

    weak var delegate: SSKWebSocketDelegate?

    private let callbackQueue: DispatchQueue
    private let hasReported = AtomicBool(false, lock: .sharedGlobal)

    init(callbackQueue: DispatchQueue? = nil) {
        self.callbackQueue = callbackQueue ?? .main
    }

    var state: SSKWebSocketState { .disconnected }

    func connect() {
        guard !hasReported.swap(true) else { return }
        Logger.warn("[Proxy] IM WSS fail-closed: proxy on but tunnel not ready [\(id)]")
        callbackQueue.async { [weak self] in
            guard let self, let delegate = self.delegate else { return }
            delegate.websocketDidDisconnectOrFail(socket: self, error: SSKWebSocketProxyError.tunnelUnavailable)
        }
    }

    func disconnect() {}
    func write(data: Data) {}
    func writePing() {}
}

// MARK: -

//class SSKWebSocketStarScream: SSKWebSocket {
//
//    private static let idCounter = AtomicUInt(lock: .sharedGlobal)
//    public let id = SSKWebSocketStarScream.idCounter.increment()
//
//    private let socket: Starscream.WebSocket
//
//    public var callbackQueue: DispatchQueue { socket.callbackQueue }
//
//    init(request: URLRequest,
//         callbackQueue: DispatchQueue? = nil) {
//
//        let socket = WebSocket(request: request)
//
//        if let callbackQueue = callbackQueue {
//            socket.callbackQueue = callbackQueue
//        }
//
//        socket.disableSSLCertValidation = true
//        socket.socketSecurityLevel = StreamSocketSecurityLevel.tlSv1_2
////        let security = SSLSecurity(certs: [TextSecureCertificate()], usePublicKeys: false)
////        security.validateEntireChain = false
////        socket.security = security
//
//        // TODO cipher suite selection
//        // socket.enabledSSLCipherSuites = [TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384, TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256]
//
//        self.socket = socket
//
//        socket.delegate = self
//    }
//
//    // MARK: - SSKWebSocket
//
//    weak var delegate: SSKWebSocketDelegate?
//
//    private let hasEverConnected = AtomicBool(false, lock: .sharedGlobal)
//
//    // This method is thread-safe.
//    var state: SSKWebSocketState {
//        if socket.isConnected {
//            return .open
//        }
//
//        if hasEverConnected.get() {
//            return .disconnected
//        }
//
//        return .connecting
//    }
//
//    func connect() {
//        socket.connect()
//    }
//
//    func disconnect() {
//        socket.disconnect()
//    }
//
//    func write(data: Data) {
//        socket.write(data: data)
//    }
//
//    func writePing() {
//        socket.write(ping: Data())
//    }
//}

// MARK: -

//extension SSKWebSocketStarScream: WebSocketDelegate {
//    func websocketDidConnect(socket: WebSocketClient) {
//        assertOnQueue(callbackQueue)
//        hasEverConnected.set(true)
//        delegate?.websocketDidConnect(socket: self)
//    }
//
//    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
//        assertOnQueue(callbackQueue)
//        let websocketError: Error?
//        switch error {
//        case let wsError as WSError:
//            websocketError = StarscreamError(underlyingError: wsError)
//        case let nsError as NSError:
//            // Assert that error is either a Starscream.WSError or an OS level networking error
//            assert(nsError.domain == NSPOSIXErrorDomain as String
//                   || nsError.domain == kCFErrorDomainCFNetwork as String
//                   || nsError.domain == NSOSStatusErrorDomain as String)
//            websocketError = error
//        default:
//            assert(error == nil, "unexpected error type: \(String(describing: error))")
//            websocketError = error
//        }
//
//        delegate?.websocketDidDisconnectOrFail(socket: self, error: websocketError)
//    }
//
//    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
//        assertOnQueue(callbackQueue)
//        owsFailDebug("We only expect binary frames.")
//    }
//
//    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
//        assertOnQueue(callbackQueue)
//        delegate?.websocket(self, didReceiveData: data)
//    }
//}

// MARK: -

//private func TextSecureCertificate() -> SSLCert {
//    let data = SSKTextSecureServiceCertificateData()
//    return SSLCert(data: data)
//}

// MARK: -

//private extension StreamSocketSecurityLevel {
//    static var tlSv1_2: StreamSocketSecurityLevel {
//        return StreamSocketSecurityLevel(rawValue: "kCFStreamSocketSecurityLevelTLSv1_2")
//    }
//}

// MARK: -

// TODO: Replace with OWSHTTPError.
//@objc
//public class StarscreamError: NSObject, CustomNSError {
//
//    let underlyingError: Starscream.WSError
//
//    public var code: Int { underlyingError.code }
//
//    init(underlyingError: Starscream.WSError) {
//        self.underlyingError = underlyingError
//    }
//
//    // MARK: - CustomNSError
//
//    @objc
//    public static let errorDomain = "TTServiceKit.StarscreamError"
//
//    public var errorUserInfo: [String: Any] {
//        return [
//            type(of: self).kStatusCodeKey: code,
//            NSUnderlyingErrorKey: (underlyingError as NSError)
//        ]
//    }
//
//    // MARK: -
//
//    // TODO: Eliminate.
//    @objc
//    public static var kStatusCodeKey: String { "StarscreamErrorStatusCode" }
//
//    public override var description: String {
//        return "StarscreamError - underlyingError: \(underlyingError)"
//    }
//}
