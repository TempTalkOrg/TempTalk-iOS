//
//  DTAskAddFriendsApi.swift
//  TTServiceKit
//
//  Created by hornet on 2022/11/16.
//

import Foundation
@objc
public class DTAskAddFriendsApi : DTBaseAPI {
    
    public override var requestMethod: String {
        get {
            return "POST";
        }
        set{
            super.requestMethod = newValue
        }
    }
    
    public override var requestUrl: String {
        get {
            return "/v3/friend/ask";
        }
        set{
            super.requestUrl = newValue
        }
    }

    /// Request body for `/v3/friend/ask`. Kept apart from the transport so the shape of what we
    /// report is readable on its own — `source` is omitted entirely when unspecified.
    private static func requestParameters(
        uid: String,
        source: AddFriendSource,
        action: String?
    ) -> [String: Any] {
        var params: [String: Any] = ["uid": uid]

        let sourceParameters = source.apiParameters
        if !sourceParameters.isEmpty {
            params["source"] = sourceParameters
        }

        if let action = action {
            params["action"] = action
        }

        return params
    }

    public func askAddContacts(
        uid: String,
        source: AddFriendSource,
        action: String? = nil
    ) async throws -> DTAPIMetaEntity {
        let params = Self.requestParameters(uid: uid, source: source, action: action)

        guard let url = URL(string: self.requestUrl) else {
            throw NSError(
                domain: "DTAskAddFriendsApi",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]
            )
        }

        let request = TSRequest(url: url, method: self.requestMethod, parameters: params)
        request.shouldHaveAuthorizationHeaders = true

        let token = try await DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken()
        request.authToken = token

        let response = try await networkManager.asyncRequest(request)

        let entity = try MTLJSONAdapter.model(
            of: DTAPIMetaEntity.self,
            fromJSONDictionary: response.responseBodyJson as? [AnyHashable: Any]
        ) as! DTAPIMetaEntity

        guard entity.status == 0 else {
            throw NSError(
                domain: "DTAskAddFriendsApi",
                code: entity.status,
                userInfo: [NSLocalizedDescriptionKey: entity.reason]
            )
        }

        return entity
    }
}

