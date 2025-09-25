//
//  SessionFetcher.swift
//  TTServiceKit
//
//  Created by Kris.s on 2024/12/3.
//

import Foundation


public class SessionFetcher: NSObject {
    
    public class func fetchSessions(identifiers: [String]) async throws -> [DTPrekeyBundle] {
        if identifiers.isEmpty {
            return []
        }
        
        var targetIdentifiers = [String]()
        self.databaseStorage.read { transaction in
            for identifier in identifiers {
                if !SessionStore.containsSession(identifier: identifier, transaction: transaction) {
                    targetIdentifiers.append(identifier)
                }
            }
        }
        if targetIdentifiers.isEmpty {
            return []
        }
        
        let token = try await self.requestAuthToken()
        let requestUrl = "/v3/keys/identity/bulk"
        let requestMethod = "POST"
        let parameters = ["uids":targetIdentifiers]
        guard let url = URL(string: requestUrl), !token.isEmpty else {
            let errorDesc = "Invalid parameters, token is empty!"
            OWSLogger.error(errorDesc)
            throw OWSAssertionError(errorDesc)
        }
        
        let request = TSRequest(
            url: url,
            method: requestMethod,
            parameters: parameters
        )
        request.authToken = token
        
        let response = try await self.networkManager.asyncRequest(request)
        guard let jsonData = response.responseBodyJson as? [AnyHashable : Any] else {
            let errorDesc = "data to json error!"
            OWSLogger.error(errorDesc)
            throw OWSAssertionError(errorDesc)
        }
        guard let metaData = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self, fromJSONDictionary: jsonData) as? DTAPIMetaEntity else {
            let errorDesc = "json to metaData error!"
            OWSLogger.error(errorDesc)
            throw OWSAssertionError(errorDesc)
        }
        guard let keysData = metaData.data["keys"] as? [Any] else {
            let errorDesc = "keys is empty!"
            OWSLogger.error(errorDesc)
            throw OWSAssertionError(errorDesc)
        }
        guard let sessions = try MTLJSONAdapter.models(of: DTPrekeyBundle.self, fromJSONArray: keysData) as? [DTPrekeyBundle] else {
            let errorDesc = "keys to prekeyBundles error!"
            OWSLogger.error(errorDesc)
            throw OWSAssertionError(errorDesc)
        }
        return sessions
    }
    
    private class func requestAuthToken() async throws -> String {
        try await Promise { future in
                DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken { token, error in
                    guard let token, error == nil else {
                        let err = NSError(
                            domain: "com.tt.session.fetcher",
                            code: -10002,
                            userInfo: [NSLocalizedDescriptionKey: "token invalid"]
                        )
                        OWSLogger.error("token invalid")
                        future.reject(err)
                        return
                    }
                    future.resolve(token)
                }
        }.awaitable()
    }
    
}
