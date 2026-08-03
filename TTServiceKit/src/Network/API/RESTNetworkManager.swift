//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalCoreKit
import CoreImage

public extension RESTNetworkManager {
    func makePromise(request: TSRequest) -> Promise<HTTPResponse> {
        let (promise, future) = Promise<HTTPResponse>.pending()
        self.makeRequest(request,
                         completionQueue: .global(),
                         success: { (response: HTTPResponse) in
                            future.resolve(response)
                         },
                         failure: { (error: OWSHTTPErrorWrapper) in
                            future.reject(error.error)
                         })
        return promise
    }
    
    func asyncRequest(_ request: TSRequest) async throws -> HTTPResponse {
        try await withCheckedThrowingContinuation { continuation in
            makeRequest(request, completionQueue: .global(), success: { continuation.resume(returning: $0) }, failure: { continuation.resume(throwing: $0.error) })
        }
    }
}

// MARK: -

@objc
public class RESTSessionManager: NSObject {

    private let urlSession: OWSURLSession
    private let urlCallSession: OWSURLSession
    private let urlFileShareSession: OWSURLSession
    private let urlSpeech2TextSession: OWSURLSession
    private let urlStorageSession: OWSURLSession
    private let urlRootSession: OWSURLSession

    @objc
    public let createdDate = Date()

    @objc public var baseUrlHost: String? {
        urlSession.baseUrl?.host
    }

    @objc
    public override required init() {
        assertOnQueue(NetworkManagerQueue())

        self.urlSession = Self.signalService.urlSessionForMainSignalService()
        self.urlCallSession = Self.signalService.urlSessionForCallService()
        self.urlFileShareSession = Self.signalService.urlSessionForFileShareService()
        self.urlSpeech2TextSession = Self.signalService.urlSessionForSpeech2TextService()
        self.urlStorageSession = Self.signalService.urlSessionForStorageService()
        self.urlRootSession = Self.signalService.urlSessionForRootService()
    }

    @objc
    public func performRequest(_ request: TSRequest,
                               success: @escaping RESTNetworkManagerSuccess,
                               failure: @escaping RESTNetworkManagerFailure) {
        assertOnQueue(NetworkManagerQueue())
        owsAssertDebug(!FeatureFlags.deprecateREST || signalService.isCensorshipCircumventionActive)

        // Select session by request server type; each session's baseUrl is
        // computed dynamically from TSConstants via its serviceType.
        // isMainService: services sharing the chat domain pool; record LastHost on success.
        let urlSession: OWSURLSession
        let isMainService: Bool
        switch request.serverType {
        case .avatar:
            urlSession = self.urlStorageSession
            isMainService = false
        case .fileSharing:
            urlSession = self.urlFileShareSession
            isMainService = true
        case .call:
            urlSession = self.urlCallSession
            isMainService = true
        case .speech2Text:
            urlSession = self.urlSpeech2TextSession
            isMainService = true
        case .root:
            urlSession = self.urlRootSession
            isMainService = true
        default:
            urlSession = self.urlSession
            isMainService = true
        }

        guard let requestUrl = request.url else {
            owsFailDebug("Missing requestUrl.")
            let url: URL = urlSession.baseUrl ?? URL(string: TSConstants.mainServiceURL)!
            failure(OWSHTTPErrorWrapper(error: .missingRequest(requestUrl: url)))
            return
        }

        firstly {
            urlSession.promiseForTSRequest(request)
        }.done(on: DispatchQueue.global()) { (response: HTTPResponse) in
            Logger.debug("Request base url: \(String(describing: urlSession.baseUrl))")

            if isMainService,
               let host = urlSession.baseUrl?.host,
               DTServerUrlManager.shared().containsHost(host, serverType: .chat) {
                DTLastSuccessfulHostManager.shared.saveLastSuccessfulHost(
                    host,
                    serverType: .chat
                )
            }
            
            success(response)
        }.catch(on: DispatchQueue.global()) { error in
            // OWSUrlSession should only throw OWSHTTPError or OWSAssertionError.
            if let httpError = error as? OWSHTTPError {
                HTTPUtils.applyHTTPError(httpError)

                failure(OWSHTTPErrorWrapper(error: httpError))
            } else {
                owsFailDebug("Unexpected error: \(error)")

                failure(OWSHTTPErrorWrapper(error: OWSHTTPError.invalidRequest(requestUrl: requestUrl)))
            }
        }
    }
}

// MARK: -

@objc
public class RESTSpeedtestSessionManager: NSObject {
    
    private let urlSession: OWSURLSession
    @objc
    public let createdDate = Date()
    
    @objc
    public override required init() {
        assertOnQueue(NetworkManagerQueue())
        
        self.urlSession = Self.signalService.urlSessionForNoneService()
    }
    
    @objc
    public func performRequest(_ request: TSRequest,
                               success: @escaping RESTNetworkManagerSuccess,
                               failure: @escaping RESTNetworkManagerFailure) {
        assertOnQueue(NetworkManagerQueue())
        owsAssertDebug(!FeatureFlags.deprecateREST || signalService.isCensorshipCircumventionActive)
        
        // We should only use the RESTSpeedtestSessionManager for requests to the Signal main service.
        let urlSession = self.urlSession
                
        guard let requestUrl = request.url else {
            owsFailDebug("Missing requestUrl.")
            let url: URL = urlSession.baseUrl ?? URL(string: TSConstants.mainServiceURL)!
            failure(OWSHTTPErrorWrapper(error: .missingRequest(requestUrl: url)))
            return
        }
        
        firstly {
            urlSession.promiseForTSRequest(request)
        }.done(on: DispatchQueue.global()) { (response: HTTPResponse) in
            success(response)
        }.catch(on: DispatchQueue.global()) { error in
            // OWSUrlSession should only throw OWSHTTPError or OWSAssertionError.
            if let httpError = error as? OWSHTTPError {
                HTTPUtils.applyHTTPError(httpError)
                
                failure(OWSHTTPErrorWrapper(error: httpError))
            } else {
                owsFailDebug("Unexpected error: \(error)")
                
                failure(OWSHTTPErrorWrapper(error: OWSHTTPError.invalidRequest(requestUrl: requestUrl)))
            }
        }
    }
}

// MARK: -

extension OWSURLSession {
    public func promiseForTSRequest(_ rawRequest: TSRequest) -> Promise<HTTPResponse> {

        guard let rawRequestUrl = rawRequest.url else {
            owsFailDebug("Missing requestUrl.")
            let url: URL = self.baseUrl ?? URL(string: TSConstants.mainServicePath)!
            return Promise(error: OWSHTTPError.missingRequest(requestUrl: url))
        }

        let httpHeaders = OWSHttpHeaders()

        // Set User-Agent and Accept-Language headers.
        httpHeaders.addDefaultHeaders()

        // Then apply any custom headers for the request
        httpHeaders.addHeaderMap(rawRequest.allHTTPHeaderFields, overwriteOnConflict: true)


        if let verifyRequest = rawRequest as? TSVerifyCodeRequest, !rawRequest.parameters.isEmpty {
            var params = rawRequest.parameters
            if let authKey = params["AuthKey"] as? String {
                do {
                    try httpHeaders.addAuthHeader(username: verifyRequest.numberToValidate,
                                                  password: authKey)
                    params.removeValue(forKey: "AuthKey")
                    verifyRequest.parameters = params
                } catch {
                    owsFailDebug("Could not add auth header: \(error).")
                    return Promise(error: OWSHTTPError.invalidAppState(requestUrl: rawRequestUrl))
                }
            } else {
                owsFailDebug("Could not add auth header: no authKey")
                return Promise(error: OWSHTTPError.invalidAppState(requestUrl: rawRequestUrl))
            }
        } else if rawRequest.canUseAuth,
           rawRequest.shouldHaveAuthorizationHeaders {
            
            //TODO
            if let authToken = rawRequest.authToken {
                httpHeaders.addHeader(OWSHttpHeaders.authHeaderKey, value: authToken, overwriteOnConflict: true)
            } else {
                owsAssertDebug(nil != rawRequest.authUsername?.nilIfEmpty)
                owsAssertDebug(nil != rawRequest.authPassword?.nilIfEmpty)
                do {
                    try httpHeaders.addAuthHeader(username: rawRequest.authUsername ?? "",
                                                  password: rawRequest.authPassword ?? "")
                } catch {
                    owsFailDebug("Could not add auth header: \(error).")
                    return Promise(error: OWSHTTPError.invalidAppState(requestUrl: rawRequestUrl))
                }
            }
        }
        
        let method: HTTPMethod
        do {
            method = try HTTPMethod.method(for: rawRequest.httpMethod)
        } catch {
            owsFailDebug("Invalid HTTP method: \(rawRequest.httpMethod)")
            return Promise(error: OWSHTTPError.invalidRequest(requestUrl: rawRequestUrl))
        }

        let urlSession = self

        // Process parameters based on HTTP method (URL query for GET/HEAD; JSON body otherwise)
        let processedRequest: (url: URL, body: Data)
        do {
            processedRequest = try urlSession.processRequestParameters(
                baseURL: rawRequestUrl,
                method: method,
                parameters: rawRequest.parameters,
                httpBody: rawRequest.httpBody
            )
        } catch {
            owsFailDebug("Failed to process request parameters: \(error)")
            return Promise(error: OWSHTTPError.invalidRequest(requestUrl: rawRequestUrl))
        }

        // Add Content-Type for JSON body
        if !processedRequest.body.isEmpty && !httpMethodsEncodingParametersInURI.contains(method) {
            httpHeaders.addHeader("Content-Type", value: "application/json", overwriteOnConflict: true)
        }

        let request: URLRequest
        do {
            request = try urlSession.buildRequest(processedRequest.url.absoluteString,
                                                  method: method,
                                                  headers: httpHeaders.headers,
                                                  body: processedRequest.body)
        } catch {
            owsFailDebug("Missing or invalid request: \(processedRequest.url).")
            return Promise(error: OWSHTTPError.invalidRequest(requestUrl: rawRequestUrl))
        }

        var backgroundTask: OWSBackgroundTask? = OWSBackgroundTask(label: "\(#function)")

        Logger.verbose("Making request: \(rawRequest.description)")

        return firstly(on: DispatchQueue.global()) { () throws -> Promise<HTTPResponse> in
            urlSession.uploadTaskPromise(request: request, data: processedRequest.body)
        }.map(on: DispatchQueue.global()) { (response: HTTPResponse) -> HTTPResponse in
            Logger.info("Success: \(rawRequest.description)")
            return response
        }.ensure(on: DispatchQueue.global()) {
            owsAssertDebug(backgroundTask != nil)
            backgroundTask = nil
        }.recover(on: DispatchQueue.global()) { error -> Promise<HTTPResponse> in
            Logger.warn("Failure: \(rawRequest.description), error: \(error)")
            throw error
        }
    }
}

// MARK: -

@objc
public extension TSRequest {
    var canUseAuth: Bool { !isUDRequest }
}
