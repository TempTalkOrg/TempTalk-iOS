//
//  OWSURLSession+nonmain.swift
//  TTServiceKit
//
//  Created by Felix on 2022/7/22.
//

import Foundation

// MARK: - Non-main Service Requests

@objc
public extension OWSURLSession {

    /// Performs a non-main service request with callbacks on the main thread
    @objc
    func performNonmainRequest(_ request: TSRequest,
                               success: @escaping RESTNetworkManagerSuccess,
                               failure: @escaping RESTNetworkManagerFailure) {
        performNonmainRequest(request, completeQueue: .main, success: success, failure: failure)
    }

    /// Performs a non-main service request with callbacks on the specified queue
    @objc
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
            Logger.debug("Request base url: \(String(describing: self.baseUrl))")
            
            if let host = self.baseUrl?.host,
               DTServerUrlManager.shared().containsHost(host, serverType: .chat) {
                DTLastSuccessfulHostManager.shared.saveLastSuccessfulHost(
                    host,
                    serverType: .chat
                )
            }
            success(response)
        }.catch(on: completeQueue) { error in
            // OWSUrlSession should only throw OWSHTTPError or OWSAssertionError.
            if let httpError = error as? OWSHTTPError {
                HTTPUtils.applyHTTPError(httpError)
                // Switch domain if status code is outside normal range [100, 499]
                // Status code 0 means no response (network failure)
                let statusCode = httpError.responseStatusCode
                let shouldSwitchDomain = statusCode < 100 || statusCode >= 500

                if shouldSwitchDomain,
                   let host = requestUrl.host,
                   DTServerUrlManager.shared().containsHost(host, serverType: .chat) {
                    DTServerUrlManager.shared().markAsInvalid(withUrl: host, serverType: .chat)
                    let serverUrls: [String] = DTServerUrlManager.shared().getTheServerUrls(withServerType: .chat)
                    if let nextHost = serverUrls.first {
                        TSConstants.mainServiceHost = nextHost
                        Logger.info("[DomainSwitch] change host from \(host) to \(nextHost) (status: \(statusCode))")
                    }
                }

                failure(OWSHTTPErrorWrapper(error: httpError))
            } else {
                // Don't assert here: network-layer failures (URLError timeout/cancelled/offline)
                // are normal runtime errors and would SIGILL when no debugger is attached.
                Logger.error("Unexpected error: \(error)")
                failure(OWSHTTPErrorWrapper(error: OWSHTTPError.invalidRequest(requestUrl: requestUrl)))
            }
        }
    }
}

// MARK: - Simple Upload Requests

@objc
public extension OWSURLSession {

    /// Simple upload (no progress), callbacks on main thread
    @objc
    func performUploadRequest(_ request: URLRequest,
                              data: Data,
                              success: @escaping RESTNetworkManagerSuccess,
                              failure: @escaping RESTNetworkManagerFailure) {
        performUploadRequest(request,
                             data: data,
                             completeQueue: .main,
                             success: success,
                             failure: failure)
    }

    /// Simple upload (no progress), callbacks on specified queue
    @objc
    func performUploadRequest(_ request: URLRequest,
                              data: Data,
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
            promiseForUploadRequest(request, data: data)
        }.done(on: completeQueue) { (response: HTTPResponse) in
            success(response)
        }.catch(on: completeQueue) { error in
            if let httpError = error as? OWSHTTPError {
                HTTPUtils.applyHTTPError(httpError)
                failure(OWSHTTPErrorWrapper(error: httpError))
            } else {
                // Don't assert here: network-layer failures (URLError timeout/cancelled/offline)
                // are normal runtime errors and would SIGILL when no debugger is attached.
                Logger.error("Unexpected error: \(error)")
                failure(OWSHTTPErrorWrapper(error: OWSHTTPError.invalidRequest(requestUrl: requestUrl)))
            }
        }
    }

    /// Simple upload with progress, callbacks on main thread
    @objc
    func performUploadRequest(_ request: URLRequest,
                              data: Data,
                              success: @escaping RESTNetworkManagerSuccess,
                              progress: @escaping RESTNetworkManagerProgress,
                              failure: @escaping RESTNetworkManagerFailure) {
        performUploadRequest(request,
                             data: data,
                             completeQueue: .main,
                             success: success,
                             progress: progress,
                             failure: failure)
    }

    /// Simple upload with progress, callbacks on specified queue
    @objc
    func performUploadRequest(_ request: URLRequest,
                              data: Data,
                              completeQueue: DispatchQueue,
                              success: @escaping RESTNetworkManagerSuccess,
                              progress: @escaping RESTNetworkManagerProgress,
                              failure: @escaping RESTNetworkManagerFailure) {
        guard let requestUrl = request.url else {
            owsFailDebug("Missing requestUrl.")
            let url: URL = baseUrl ?? URL(string: TSConstants.mainServiceURL)!
            failure(OWSHTTPErrorWrapper(error: .missingRequest(requestUrl: url)))
            return
        }

        firstly {
            promiseForUploadRequest(request, data: data, progress: progress)
        }.done(on: completeQueue) { (response: HTTPResponse) in
            success(response)
        }.catch(on: completeQueue) { error in
            if let httpError = error as? OWSHTTPError {
                HTTPUtils.applyHTTPError(httpError)
                failure(OWSHTTPErrorWrapper(error: httpError))
            } else {
                // Don't assert here: network-layer failures (URLError timeout/cancelled/offline)
                // are normal runtime errors and would SIGILL when no debugger is attached.
                Logger.error("Unexpected error: \(error)")
                failure(OWSHTTPErrorWrapper(error: OWSHTTPError.invalidRequest(requestUrl: requestUrl)))
            }
        }
    }
}

// MARK: - Multipart Upload Requests

@objc
public extension OWSURLSession {

    /// Multipart upload (no progress), callbacks on main thread
    @objc
    func performMultiPartUploadRequest(_ request: URLRequest,
                                       fileUrl: URL,
                                       name: String,
                                       fileName: String,
                                       mimeType: String,
                                       textParts: [String: String],
                                       success: @escaping RESTNetworkManagerSuccess,
                                       failure: @escaping RESTNetworkManagerFailure) {
        performMultiPartUploadRequest(request,
                                      fileUrl: fileUrl,
                                      name: name,
                                      fileName: fileName,
                                      mimeType: mimeType,
                                      textParts: textParts,
                                      completeQueue: .main,
                                      success: success,
                                      failure: failure)
    }

    /// Multipart upload (no progress), callbacks on specified queue
    @objc
    func performMultiPartUploadRequest(_ request: URLRequest,
                                       fileUrl: URL,
                                       name: String,
                                       fileName: String,
                                       mimeType: String,
                                       textParts: [String: String],
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
            promiseForMultiPartUploadRequest(request,
                                             fileUrl: fileUrl,
                                             name: name,
                                             fileName: fileName,
                                             mimeType: mimeType,
                                             textParts: textParts)
        }.done(on: completeQueue) { (response: HTTPResponse) in
            success(response)
        }.catch(on: completeQueue) { error in
            if let httpError = error as? OWSHTTPError {
                HTTPUtils.applyHTTPError(httpError)
                failure(OWSHTTPErrorWrapper(error: httpError))
            } else {
                // Don't assert here: network-layer failures (URLError timeout/cancelled/offline)
                // are normal runtime errors and would SIGILL when no debugger is attached.
                Logger.error("Unexpected error: \(error)")
                failure(OWSHTTPErrorWrapper(error: OWSHTTPError.invalidRequest(requestUrl: requestUrl)))
            }
        }
    }

    /// Multipart upload with progress, callbacks on main thread
    @objc
    func performMultiPartUploadRequest(_ request: URLRequest,
                                       fileUrl: URL,
                                       name: String,
                                       fileName: String,
                                       mimeType: String,
                                       textParts: [String: String],
                                       success: @escaping RESTNetworkManagerSuccess,
                                       progress: @escaping RESTNetworkManagerProgress,
                                       failure: @escaping RESTNetworkManagerFailure) {
        performMultiPartUploadRequest(request,
                                      fileUrl: fileUrl,
                                      name: name,
                                      fileName: fileName,
                                      mimeType: mimeType,
                                      textParts: textParts,
                                      completeQueue: .main,
                                      success: success,
                                      progress: progress,
                                      failure: failure)
    }

    /// Multipart upload with progress, callbacks on specified queue
    @objc
    func performMultiPartUploadRequest(_ request: URLRequest,
                                       fileUrl: URL,
                                       name: String,
                                       fileName: String,
                                       mimeType: String,
                                       textParts: [String: String],
                                       completeQueue: DispatchQueue,
                                       success: @escaping RESTNetworkManagerSuccess,
                                       progress: @escaping RESTNetworkManagerProgress,
                                       failure: @escaping RESTNetworkManagerFailure) {
        guard let requestUrl = request.url else {
            owsFailDebug("Missing requestUrl.")
            let url: URL = baseUrl ?? URL(string: TSConstants.mainServiceURL)!
            failure(OWSHTTPErrorWrapper(error: .missingRequest(requestUrl: url)))
            return
        }

        firstly {
            promiseForMultiPartUploadRequest(request,
                                             fileUrl: fileUrl,
                                             name: name,
                                             fileName: fileName,
                                             mimeType: mimeType,
                                             textParts: textParts,
                                             progress: progress)
        }.done(on: completeQueue) { (response: HTTPResponse) in
            success(response)
        }.catch(on: completeQueue) { error in
            if let httpError = error as? OWSHTTPError {
                HTTPUtils.applyHTTPError(httpError)
                failure(OWSHTTPErrorWrapper(error: httpError))
            } else {
                // Don't assert here: network-layer failures (URLError timeout/cancelled/offline)
                // are normal runtime errors and would SIGILL when no debugger is attached.
                Logger.error("Unexpected error: \(error)")
                failure(OWSHTTPErrorWrapper(error: OWSHTTPError.invalidRequest(requestUrl: requestUrl)))
            }
        }
    }
}

// MARK: - Download Requests

@objc
public extension OWSURLSession {

    /// Download request, callbacks on main thread
    @objc
    func performDownloadRequest(_ request: TSRequest,
                                success: @escaping RESTNetworkManagerDownloadSuccess,
                                progress: @escaping RESTNetworkManagerProgress,
                                failure: @escaping RESTNetworkManagerFailure) {
        performDownloadRequest(request, completeQueue: .main, success: success, progress: progress, failure: failure)
    }

    /// Download request, callbacks on specified queue
    @objc
    func performDownloadRequest(_ request: TSRequest,
                                completeQueue: DispatchQueue,
                                success: @escaping RESTNetworkManagerDownloadSuccess,
                                progress: @escaping RESTNetworkManagerProgress,
                                failure: @escaping RESTNetworkManagerFailure) {
        guard let requestUrl = request.url else {
            owsFailDebug("Missing requestUrl.")
            let url: URL = baseUrl ?? URL(string: TSConstants.mainServiceURL)!
            failure(OWSHTTPErrorWrapper(error: .missingRequest(requestUrl: url)))
            return
        }

        firstly {
            promiseForDownloadTSRequest(request, progress)
        }.done(on: completeQueue) { (response: OWSUrlDownloadResponse) in
            success(response)
        }.catch(on: completeQueue) { error in
            if let httpError = error as? OWSHTTPError {
                HTTPUtils.applyHTTPError(httpError)

                let statusCode = httpError.responseStatusCode
                let shouldSwitchDomain = statusCode < 100 || statusCode >= 500
                
                if shouldSwitchDomain,
                   let host = requestUrl.host,
                   DTServerUrlManager.shared().containsHost(host, serverType: .chat) {
                    // Only switch if the download URL belongs to the chat domain pool.
                    DTServerUrlManager.shared().markAsInvalid(withUrl: host, serverType: .chat)

                    let serverUrls: [String] = DTServerUrlManager.shared().getTheServerUrls(withServerType: .chat)
                    if let nextHost = serverUrls.first {
                        TSConstants.mainServiceHost = nextHost
                        Logger.info("[DomainSwitch] change host from \(host) to \(nextHost) (status: \(statusCode))")
                    }
                }

                failure(OWSHTTPErrorWrapper(error: httpError))
            } else {
                // Don't assert here: network-layer failures (URLError timeout/cancelled/offline)
                // are normal runtime errors and would SIGILL when no debugger is attached.
                Logger.error("Unexpected error: \(error)")
                failure(OWSHTTPErrorWrapper(error: OWSHTTPError.invalidRequest(requestUrl: requestUrl)))
            }
        }
    }
}

// MARK: - Promise Implementations

extension OWSURLSession {

    /// Creates a Promise for simple upload requests
    public func promiseForUploadRequest(_ request: URLRequest,
                                        data: Data,
                                        progress: ProgressBlock? = nil) -> Promise<HTTPResponse> {

        guard let requestUrl = request.url else {
            owsFailDebug("Missing requestUrl.")
            let url: URL = self.baseUrl ?? URL(string: TSConstants.mainServiceHost)!
            return Promise(error: OWSHTTPError.missingRequest(requestUrl: url))
        }

        var backgroundTask: OWSBackgroundTask? = OWSBackgroundTask(label: "\(#function)")

        Logger.info("Making upload request: \(requestUrl)")

        return firstly(on: DispatchQueue.global()) { () throws -> Promise<HTTPResponse> in
            self.uploadTaskPromise(request: request, data: data, progress: progress)
        }.map(on: DispatchQueue.global()) { (response: HTTPResponse) -> HTTPResponse in
            Logger.info("Success: upload request: \(requestUrl)")
            return response
        }.ensure(on: DispatchQueue.global()) {
            owsAssertDebug(backgroundTask != nil)
            backgroundTask = nil
        }.recover(on: DispatchQueue.global()) { error -> Promise<HTTPResponse> in
            Logger.error("Failure: upload request: \(requestUrl), error: \(error)")
            throw error
        }
    }

    /// Creates a Promise for multipart upload requests
    public func promiseForMultiPartUploadRequest(_ request: URLRequest,
                                                 fileUrl: URL,
                                                 name: String,
                                                 fileName: String,
                                                 mimeType: String,
                                                 textParts: [String: String],
                                                 progress: ProgressBlock? = nil) -> Promise<HTTPResponse> {

        guard let requestUrl = request.url else {
            owsFailDebug("Missing requestUrl.")
            let url: URL = self.baseUrl ?? URL(string: TSConstants.mainServiceHost)!
            return Promise(error: OWSHTTPError.missingRequest(requestUrl: url))
        }

        // Convert dictionary to OrderedDictionary as required by multiPartUploadTaskPromise
        var orderedTextParts = OrderedDictionary<String, String>()
        for (key, value) in textParts {
            orderedTextParts.append(key: key, value: value)
        }

        var backgroundTask: OWSBackgroundTask? = OWSBackgroundTask(label: "\(#function)")

        Logger.info("Making multipart upload request: \(requestUrl)")

        return firstly(on: DispatchQueue.global()) { () throws -> Promise<HTTPResponse> in
            self.multiPartUploadTaskPromise(request: request,
                                            fileUrl: fileUrl,
                                            name: name,
                                            fileName: fileName,
                                            mimeType: mimeType,
                                            textParts: orderedTextParts,
                                            ignoreAppExpiry: true,
                                            progress: progress)
        }.map(on: DispatchQueue.global()) { (response: HTTPResponse) -> HTTPResponse in
            Logger.info("Success: multipart upload request: \(requestUrl)")
            return response
        }.ensure(on: DispatchQueue.global()) {
            owsAssertDebug(backgroundTask != nil)
            backgroundTask = nil
        }.recover(on: DispatchQueue.global()) { error -> Promise<HTTPResponse> in
            Logger.error("Failure: multipart upload request: \(requestUrl), error: \(error)")
            throw error
        }
    }

    /// Creates a Promise for non-main service requests
    public func promiseForNonMainTSRequest(_ rawRequest: TSRequest, _ progress: ProgressBlock? = nil) -> Promise<HTTPResponse> {

        guard let rawRequestUrl = rawRequest.url else {
            owsFailDebug("Missing requestUrl.")
            let url: URL = self.baseUrl ?? URL(string: TSConstants.mainServiceHost)!
            return Promise(error: OWSHTTPError.missingRequest(requestUrl: url))
        }

        let method: HTTPMethod
        do {
            method = try HTTPMethod.method(for: rawRequest.httpMethod)
        } catch {
            owsFailDebug("Invalid HTTP method: \(rawRequest.httpMethod)")
            return Promise(error: OWSHTTPError.invalidRequest(requestUrl: rawRequestUrl))
        }

        let urlSession = self
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

        let httpHeaders = OWSHttpHeaders()

        // Set User-Agent and Accept-Language headers — server-side WAF / routing
        // keys off these. Consistent with promiseForTSRequest.
        httpHeaders.addDefaultHeaders()

        // Add custom headers from the request
        httpHeaders.addHeaderMap(rawRequest.allHTTPHeaderFields, overwriteOnConflict: true)

        // Add authorization headers
        if let authToken = rawRequest.authToken {
            httpHeaders.addHeader("Authorization", value: authToken, overwriteOnConflict: true)
            // TODO: Task uses token; keep for a few releases from 2.4.3
            httpHeaders.addHeader("token", value: authToken, overwriteOnConflict: true)
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

        Logger.info("Making nonmain request: \(rawRequest.description)")

        return firstly(on: DispatchQueue.global()) { () throws -> Promise<HTTPResponse> in
            urlSession.uploadTaskPromise(request: request, data: processedRequest.body, progress: progress)
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

    /// Creates a Promise for download requests
    public func promiseForDownloadTSRequest(_ rawRequest: TSRequest, _ progress: ProgressBlock? = nil) -> Promise<OWSUrlDownloadResponse> {

        guard let rawRequestUrl = rawRequest.url else {
            owsFailDebug("Missing requestUrl.")
            let url: URL = self.baseUrl ?? URL(string: TSConstants.mainServiceHost)!
            return Promise(error: OWSHTTPError.missingRequest(requestUrl: url))
        }

        let httpHeaders = OWSHttpHeaders()

        // Set User-Agent and Accept-Language headers — server-side WAF / routing
        // keys off these. Consistent with promiseForTSRequest.
        httpHeaders.addDefaultHeaders()

        // Apply per-request custom headers
        httpHeaders.addHeaderMap(rawRequest.allHTTPHeaderFields, overwriteOnConflict: true)

        // Authorization — chat-pool downloads need the Bearer token; OSS URLs
        // carry their own signature so an extra Authorization header is harmless.
        if let authToken = rawRequest.authToken {
            httpHeaders.addHeader("Authorization", value: authToken, overwriteOnConflict: true)
            httpHeaders.addHeader("token", value: authToken, overwriteOnConflict: true)
        }

        let method: HTTPMethod
        do {
            method = try HTTPMethod.method(for: rawRequest.httpMethod)
        } catch {
            owsFailDebug("Invalid HTTP method: \(rawRequest.httpMethod)")
            return Promise(error: OWSHTTPError.invalidRequest(requestUrl: rawRequestUrl))
        }

        let urlSession = self
        var request: URLRequest
        do {
            request = try urlSession.buildRequest(rawRequestUrl.absoluteString,
                                                  method: method,
                                                  headers: httpHeaders.headers)
        } catch {
            owsFailDebug("Missing or invalid request: \(rawRequestUrl).")
            return Promise(error: OWSHTTPError.invalidRequest(requestUrl: rawRequestUrl))
        }

        var backgroundTask: OWSBackgroundTask? = OWSBackgroundTask(label: "\(#function)")

        Logger.info("Making download request: \(rawRequest.description)")

        return firstly(on: DispatchQueue.global()) { () throws -> Promise<OWSUrlDownloadResponse> in
            urlSession.downloadTaskPromise(request: request, progress: progress)
        }.map(on: DispatchQueue.global()) { (response: OWSUrlDownloadResponse) -> OWSUrlDownloadResponse in
            Logger.info("Success: \(rawRequest.description)")
            return response
        }.ensure(on: DispatchQueue.global()) {
            owsAssertDebug(backgroundTask != nil)
            backgroundTask = nil
        }.recover(on: DispatchQueue.global()) { error -> Promise<OWSUrlDownloadResponse> in
            Logger.error("Failure: \(rawRequest.description), error: \(error)")
            throw error
        }
    }
}
