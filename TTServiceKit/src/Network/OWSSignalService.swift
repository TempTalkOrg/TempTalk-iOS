//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation

fileprivate extension OWSSignalService {

    enum SignalServiceType {
        case mainSignalService
        case storageService
        case fileShareService
        case noneService
        case callService
        case speech2TextService
        case rootService
        case gifService

        func toSessionServiceType() -> OWSURLSessionServiceType {
            switch self {
            case .mainSignalService:
                return .mainSignalService
            case .storageService:
                return .storageService
            case .fileShareService:
                return .fileShareService
            case .noneService:
                return .noneService
            case .callService:
                return .callService
            case .speech2TextService:
                return .speech2TextService
            case .rootService:
                return .rootService
            case .gifService:
                return .gifService
            }
        }
    }

    enum SerializerType {
        case json
        case binary
    }

    struct SignalServiceInfo {
        let baseUrl: URL?
        let censorshipCircumventionPathPrefix: String
        let shouldHandleRemoteDeprecation: Bool
    }

    func signalServiceInfo(for signalServiceType: SignalServiceType) -> SignalServiceInfo {
        switch signalServiceType {
        case .noneService:
            return SignalServiceInfo(baseUrl: nil,
                                     censorshipCircumventionPathPrefix: "",
                                     shouldHandleRemoteDeprecation: true)
        case .fileShareService:
            return SignalServiceInfo(baseUrl: URL(string: TSConstants.fileShareServiceURL),
                                     censorshipCircumventionPathPrefix: "",
                                     shouldHandleRemoteDeprecation: true)
        case .storageService:
            return SignalServiceInfo(baseUrl: URL(string: TSConstants.avatarStorageServerURL),
                                     censorshipCircumventionPathPrefix: "",
                                     shouldHandleRemoteDeprecation: true)
        case .callService:
            return SignalServiceInfo(baseUrl: URL(string: TSConstants.callServerURL),
                                     censorshipCircumventionPathPrefix: "",
                                     shouldHandleRemoteDeprecation: true)
        case .speech2TextService:
            return SignalServiceInfo(baseUrl: URL(string: TSConstants.speechToTextServerURL),
                                     censorshipCircumventionPathPrefix: "",
                                     shouldHandleRemoteDeprecation: true)
        case .mainSignalService:
            return SignalServiceInfo(baseUrl: URL(string: TSConstants.mainServiceURL),
                                     censorshipCircumventionPathPrefix: "",
                                     shouldHandleRemoteDeprecation: true)
        case .rootService:
            return SignalServiceInfo(baseUrl: URL(string: TSConstants.rootServiceURL),
                                     censorshipCircumventionPathPrefix: "",
                                     shouldHandleRemoteDeprecation: true)
        case .gifService:
            return SignalServiceInfo(baseUrl: URL(string: TSConstants.gifServiceURL),
                                     censorshipCircumventionPathPrefix: "",
                                     shouldHandleRemoteDeprecation: true)
        }
    }

    func buildUrlSession(for signalServiceType: SignalServiceType, configuration: URLSessionConfiguration? = nil) -> OWSURLSession {
        let signalServiceInfo = self.signalServiceInfo(for: signalServiceType)
        let sessionServiceType = signalServiceType.toSessionServiceType()
        let urlSession: OWSURLSession
        let baseUrl = signalServiceInfo.baseUrl
        let securityPolicy: OWSHTTPSecurityPolicy
        switch signalServiceType {
        // GIF proxy rides the self-hosted chat domain (chative-CA self-signed),
        // so it needs the pinned policy just like the chat/call/file/root tunnels.
        // systemDefault() would reject the self-signed cert during the TLS
        // handshake and surface as invalidResponse before the request is sent.
        case .mainSignalService, .callService, .fileShareService, .rootService, .gifService:
            securityPolicy = OWSURLSession.signalServiceSecurityPolicy
        default:
            securityPolicy = OWSURLSession.defaultSecurityPolicy
        }
        
        var sessionConfiguration = OWSURLSession.defaultConfigurationWithoutCaching
        if let configuration {
            sessionConfiguration = configuration
        }

        // Self-hosted proxy routing, from one atomic snapshot (no start/teardown read race):
        //  • tunnel ready → route through the in-process local CONNECT proxy;
        //  • proxy intended but tunnel NOT ready → route through a dead proxy so the request FAILS
        //    (fail closed) instead of connecting DIRECT and leaking the real IP;
        //  • proxy off → no proxy dict, a normal direct connection.
        switch ProxyManager.shared.urlSessionRouting() {
        case .viaProxy(let dict), .failClosed(let dict):
            sessionConfiguration.connectionProxyDictionary = dict
        case .direct:
            break
        }

        urlSession = OWSURLSession(
            serviceType: sessionServiceType,
            baseUrl: baseUrl,
            securityPolicy: securityPolicy,
            configuration: sessionConfiguration,
            extraHeaders: [:]
        )
        urlSession.shouldHandleRemoteDeprecation = signalServiceInfo.shouldHandleRemoteDeprecation
        return urlSession
    }
}

// MARK: -

@objc
public extension OWSSignalService {
    // 无特定域名的下载服务（OSS 等）
    func urlSessionForNoneService() -> OWSURLSession {
        buildUrlSession(for: .noneService)
    }

    // call 服务 (5s timeout)
    func urlSessionForCallService() -> OWSURLSession {
        let configuration = OWSURLSession.defaultConfigurationWithoutCaching
        configuration.timeoutIntervalForRequest = 5
        return buildUrlSession(for: .callService, configuration: configuration)
    }

    // 主服务 (15s timeout)
    func urlSessionForMainSignalService() -> OWSURLSession {
        let configuration = OWSURLSession.defaultConfigurationWithoutCaching
        configuration.timeoutIntervalForRequest = 15
        return buildUrlSession(for: .mainSignalService, configuration: configuration)
    }

    // 文件操作服务 (30s timeout)
    func urlSessionForFileShareService() -> OWSURLSession {
        let configuration = OWSURLSession.defaultConfigurationWithoutCaching
        configuration.timeoutIntervalForRequest = 30
        return buildUrlSession(for: .fileShareService, configuration: configuration)
    }

    // 根路径服务（无 path 后缀，跟随 chat 域名切换）
    func urlSessionForRootService() -> OWSURLSession {
        let configuration = OWSURLSession.defaultConfigurationWithoutCaching
        configuration.timeoutIntervalForRequest = 15
        return buildUrlSession(for: .rootService, configuration: configuration)
    }

    // 语音转文字
    func urlSessionForSpeech2TextService() -> OWSURLSession {
        buildUrlSession(for: .speech2TextService)
    }

    // 头像存储
    func urlSessionForStorageService() -> OWSURLSession {
        buildUrlSession(for: .storageService)
    }

    // GIF proxy (/gifs on the chat domain)
    func urlSessionForGIF() -> OWSURLSession {
        buildUrlSession(for: .gifService)
    }
}
