//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

import Foundation

// A class used for making HTTP requests against the main service.
@objc
public class NetworkManager: NSObject {
    private let restNetworkManager = RESTNetworkManager()
    
    @objc
    public static let sharedInstance = NetworkManager()

    @objc
    public override init() {
        super.init()

//        SwiftSingletons.register(self)
    }
    
    @objc
    public func makeRequest(_ request: TSRequest,
                            success: @escaping RESTNetworkManagerSuccess,
                            failure: @escaping RESTNetworkManagerFailure) {
        restNetworkManager.makeRequest(request,
                                       completionQueue: .main,
                                       success: success,
                                       failure: failure)
    }
    
    @objc
    public func makeRequest(_ request: TSRequest,
                            completionQueue: DispatchQueue = .main,
                            success: @escaping RESTNetworkManagerSuccess,
                            failure: @escaping RESTNetworkManagerFailure) {
        restNetworkManager.makeRequest(request,
                                       completionQueue: completionQueue,
                                       success: success,
                                       failure: failure)
    }


    // This method can be called from any thread.
    public func makePromise(request: TSRequest,
                            websocketSupportsRequest: Bool = false,
                            remainingRetryCount: Int = 0) -> Promise<HTTPResponse> {
        firstly { () -> Promise<HTTPResponse> in
            // Fail over to REST if websocket attempt fails.
//            let shouldUseWebsocket: Bool = {
//                guard !signalService.isCensorshipCircumventionActive else {
//                    return false
//                }
//                return (remainingRetryCount > 0 &&
//                        TSSocketManager.canMakeRequests() &&
//                        websocketSupportsRequest)
//            }()
//            return (shouldUseWebsocket
//                        ? websocketRequestPromise(request: request)
//                        : restRequestPromise(request: request))
            return restRequestPromise(request: request)
        }.recover(on: DispatchQueue.global()) { error -> Promise<HTTPResponse> in
            if error.isRetryable,
               remainingRetryCount > 0 {
                // TODO: Backoff?
                return self.makePromise(request: request,
                                        remainingRetryCount: remainingRetryCount - 1)
            } else {
                throw error
            }
        }
    }

    private func restRequestPromise(request: TSRequest) -> Promise<HTTPResponse> {
        restNetworkManager.makePromise(request: request)
    }
    
    public func asyncRequest(_ request: TSRequest) async throws -> HTTPResponse {
        try await restNetworkManager.asyncRequest(request)
    }

    private func websocketRequestPromise(request: TSRequest) -> Promise<HTTPResponse> {
        Self.socketManager.makeRequestPromise(request: request)
    }
    
    public func asyncWebsocketRequest(request: TSRequest) async throws -> HTTPResponse {
        try await Self.socketManager.makeRequestPromise(request: request).awaitable()
    }
}

// MARK: -

#if TESTABLE_BUILD

@objc
public class OWSFakeNetworkManager: NetworkManager {

    public override func makePromise(request: TSRequest,
                                     websocketSupportsRequest: Bool = false,
                                     remainingRetryCount: Int = 0) -> Promise<HTTPResponse> {
        Logger.info("Ignoring request: \(request)")
        // Never resolve.
        let (promise, _) = Promise<HTTPResponse>.pending()
        return promise
    }
}

#endif
