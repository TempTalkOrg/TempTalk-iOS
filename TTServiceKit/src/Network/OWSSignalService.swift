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
        default:
            return SignalServiceInfo(baseUrl: URL(string: TSConstants.mainServiceURL),
                                      censorshipCircumventionPathPrefix: "",
                                      shouldHandleRemoteDeprecation: true)
        }
    }
    
    private func buildUrlSession(for signalServiceType: SignalServiceType, configuration: URLSessionConfiguration? = nil) -> OWSURLSession  {
        let signalServiceInfo = self.signalServiceInfo(for: signalServiceType)

        let baseUrl = signalServiceInfo.baseUrl
        let securityPolicy: OWSHTTPSecurityPolicy
        switch signalServiceType {
        case .mainSignalService, .callService, .fileShareService:
            securityPolicy = OWSURLSession.signalServiceSecurityPolicy
        default:
            securityPolicy = OWSURLSession.defaultSecurityPolicy
        }
        
        var sessionConfiguration = OWSURLSession.defaultConfigurationWithoutCaching
        if let configuration {
            sessionConfiguration = configuration
        }
        
        let urlSession = OWSURLSession(
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
    // 临时服务，删除代码的时候会给去掉
    func urlSessionForNoneService() -> OWSURLSession {
        buildUrlSession(for: .noneService)
    }

    // call 服务
    func urlSessionForCallService() -> OWSURLSession {
        let configuration = OWSURLSession.defaultConfigurationWithoutCaching
        configuration.timeoutIntervalForRequest = 5
        return buildUrlSession(for: .callService, configuration: configuration)
    }
    
    // 主服务
    func urlSessionForMainSignalService() -> OWSURLSession {
        let configuration = OWSURLSession.defaultConfigurationWithoutCaching
        configuration.timeoutIntervalForRequest = 15
        return buildUrlSession(for: .mainSignalService, configuration: configuration)
    }
    
    // 文件操作的服务
    func urlSessionForFileShareService() -> OWSURLSession {
        let configuration = OWSURLSession.defaultConfigurationWithoutCaching
        configuration.timeoutIntervalForRequest = 30
        return buildUrlSession(for: .fileShareService, configuration: configuration)
    }
}
