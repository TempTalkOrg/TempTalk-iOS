//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation
import SignalCoreKit
import CoreImage
import AFNetworking

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
    
    @objc
    public let createdDate = Date()
    
    @objc public var baseUrlHost: String? {
        urlSession.baseUrl?.host
    }

    @objc
    public override required init() {
        assertOnQueue(NetworkManagerQueue())

        // 15s
        self.urlSession = Self.signalService.urlSessionForMainSignalService()
        // 5s
        self.urlCallSession = Self.signalService.urlSessionForCallService()
        // 30s
        self.urlFileShareSession = Self.signalService.urlSessionForFileShareService()
    }

    @objc
    public func performRequest(_ request: TSRequest,
                               success: @escaping RESTNetworkManagerSuccess,
                               failure: @escaping RESTNetworkManagerFailure) {
        assertOnQueue(NetworkManagerQueue())
        owsAssertDebug(!FeatureFlags.deprecateREST || signalService.isCensorshipCircumventionActive)

        // We should only use the RESTSessionManager for requests to the Signal main service.
        var urlSession = self.urlSession
        
        var urlStr = TSConstants.mainServiceURL
        if request.serverType == .fileSharing {
            urlStr = TSConstants.fileShareServiceURL
            urlSession = self.urlFileShareSession
        } else if request.serverType == .call {
            urlStr = TSConstants.callServerURL
            urlSession = self.urlCallSession
        } else if request.serverType == .speech2Text {
            urlStr = TSConstants.speechToTextServerURL
        } else if request.serverType == .avatar {
            urlStr = TSConstants.avatarStorageServerURL
        }
         
        if let url = URL(string: urlStr), urlSession.unfrontedBaseUrl != url {
            urlSession.baseUrl = url
        }
            
        owsAssertDebug(urlSession.unfrontedBaseUrl == URL(string: urlStr))

        guard let requestUrl = request.url else {
            owsFailDebug("Missing requestUrl.")
            let url: URL = urlSession.baseUrl ?? URL(string: urlStr)!
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

        let methods = [HTTPMethod.get, HTTPMethod.head]
        var requestBody = Data()
        if !(methods.contains(method)) {
            if let httpBody = rawRequest.httpBody {
                owsAssertDebug(rawRequest.parameters.isEmpty)
                
                requestBody = httpBody
            } else if !rawRequest.parameters.isEmpty {
                let jsonData: Data?
                do {
                    jsonData = try JSONSerialization.data(withJSONObject: rawRequest.parameters, options: [])
                } catch {
                    owsFailDebug("Could not serialize JSON parameters: \(error).")
                    return Promise(error: OWSHTTPError.invalidRequest(requestUrl: rawRequestUrl))
                }
                
                if let jsonData = jsonData {
                    requestBody = jsonData
                    // If we're going to use the json serialized parameters as our body, we should overwrite
                    // the Content-Type on the request.
                    httpHeaders.addHeader("Content-Type",
                                          value: "application/json",
                                          overwriteOnConflict: true)
                }
            }
        }

        let urlSession = self
        var request: URLRequest
        do {
            request = try urlSession.buildRequest(rawRequestUrl.absoluteString,
                                                  method: method,
                                                  headers: httpHeaders.headers,
                                                  body: requestBody)
        } catch {
            owsFailDebug("Missing or invalid request: \(rawRequestUrl).")
            return Promise(error: OWSHTTPError.invalidRequest(requestUrl: rawRequestUrl))
        }
        
        if methods.contains(method), !rawRequest.parameters.isEmpty {
            guard let url = request.url else {
                owsFailDebug("Missing or invalid request url: \(rawRequestUrl).")
                return Promise(error: OWSHTTPError.invalidRequest(requestUrl: rawRequestUrl))
            }
            
            if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                let querystring = AFQueryStringFromParameters(rawRequest.parameters)
                
                let newQueryString = [components.percentEncodedQuery, querystring].compactMap { $0 }.joined(separator: "&")
                components.percentEncodedQuery = newQueryString.isEmpty ? nil : newQueryString
                
                guard let newURL = components.url else {
                    owsFailDebug("Missing or invalid new request url: \(url).")
                    return Promise(error: OWSHTTPError.invalidRequest(requestUrl: rawRequestUrl))
                }
                
                request.url = newURL
            }
        }

        var backgroundTask: OWSBackgroundTask? = OWSBackgroundTask(label: "\(#function)")

        Logger.verbose("Making request: \(rawRequest.description)")

        return firstly(on: DispatchQueue.global()) { () throws -> Promise<HTTPResponse> in
            urlSession.uploadTaskPromise(request: request, data: requestBody)
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
