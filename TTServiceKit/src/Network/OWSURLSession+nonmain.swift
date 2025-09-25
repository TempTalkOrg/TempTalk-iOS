//
//  DTMeetingNetworkManager.swift
//  TTServiceKit
//
//  Created by Felix on 2022/7/22.
//

import Foundation
import AFNetworking

@objc
public extension OWSURLSession {
    
    @objc // 回调在主线程
    func performNonmainRequest(_ request: TSRequest,
                               success: @escaping RESTNetworkManagerSuccess,
                               failure: @escaping RESTNetworkManagerFailure) {
        performNonmainRequest(request, completeQueue: .main, success: success, failure: failure)
    }
    
    @objc // 回调在非主线程
    func performNonmainRequest(_ request: TSRequest,
                               completeQueue: DispatchQueue,
                               success: @escaping RESTNetworkManagerSuccess,
                               failure: @escaping RESTNetworkManagerFailure) {        
        guard let requestUrl = request.url else {
            owsFailDebug("Missing requestUrl.")
            let url: URL = baseUrl ?? URL(string: TSConstants.mainServiceURL)!
            failure(OWSHTTPErrorWrapper(error: .missingRequest(requestUrl: url)))
            return
        }
        
        firstly {
            promiseForNonMainTSRequest(request)
        }.done(on: completeQueue) { (response: HTTPResponse) in
            success(response)
        }.catch(on: completeQueue) { error in
            // OWSUrlSession should only throw OWSHTTPError or OWSAssertionError.
            if let httpError = error as? OWSHTTPError {
                HTTPUtils.applyHTTPError(httpError)
                
                if httpError.httpResponseData == nil {
                    
                    if let host = requestUrl.host {
                        DTServerUrlManager.shared().markAsInvalid(withUrl: host, serverType: .chat)
                        
                        let serverUrls: [String] = DTServerUrlManager.shared().getTheServerUrls(withServerType: .chat)
                        if serverUrls.count > 0 {
                            
                            TSConstants.mainServiceHost = serverUrls.first!
                            Logger.info("Multi-server: change nonmainServiceURL: \(serverUrls.first ?? "")")
                        }
                    }
                }
                
                failure(OWSHTTPErrorWrapper(error: httpError))
            } else {
                owsFailDebug("Unexpected error: \(error)")
                
                failure(OWSHTTPErrorWrapper(error: OWSHTTPError.invalidRequest(requestUrl: requestUrl)))
            }
        }
    }
}


extension OWSURLSession {
    
    public func promiseForNonMainTSRequest(_ rawRequest: TSRequest) -> Promise<HTTPResponse> {
        
        guard let rawRequestUrl = rawRequest.url else {
            owsFailDebug("Missing requestUrl.")
            let url: URL = self.baseUrl ?? URL(string: TSConstants.mainServiceHost)!
            return Promise(error: OWSHTTPError.missingRequest(requestUrl: url))
        }
        
        let httpHeaders = OWSHttpHeaders()
        
        // Set User-Agent and Accept-Language headers.
        httpHeaders.addDefaultHeaders()
        
        // Then apply any custom headers for the request
        httpHeaders.addHeaderMap(rawRequest.allHTTPHeaderFields, overwriteOnConflict: true)
        
        if let authToken = rawRequest.authToken {
            httpHeaders.addHeader("Authorization", value: authToken, overwriteOnConflict: true)
            // TODO: Task 使用 token, 暂时保留几个版本 from: 2.4.3
            httpHeaders.addHeader("token", value: authToken, overwriteOnConflict: true)
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
        
        Logger.info("Making nonmain request: \(rawRequest.description)")
        
        return firstly(on: DispatchQueue.global()) { () throws -> Promise<HTTPResponse> in
            urlSession.uploadTaskPromise(request: request, data: requestBody)
        }.map(on: DispatchQueue.global()) { (response: HTTPResponse) -> HTTPResponse in
            Logger.info("Success: \(rawRequest.description)")
            return response
        }.ensure(on: DispatchQueue.global()) {
            owsAssertDebug(backgroundTask != nil)
            backgroundTask = nil
        }.recover(on: DispatchQueue.global()) { error -> Promise<HTTPResponse> in
            Logger.error("Failure: \(rawRequest.description), error: \(error)")
            throw error
        }
    }
}
