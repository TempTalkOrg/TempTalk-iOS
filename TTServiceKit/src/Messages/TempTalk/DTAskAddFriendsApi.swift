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

    public func askAddContacts(
        uid: String,
        source: AddFriendSource,
        action: String? = nil
    ) async throws -> DTAPIMetaEntity {
        var params: [String: Any] = ["uid": uid]
        params["source"] = source.apiParameters

        if let action = action {
            params["action"] = action
        }

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

    // MARK: - Legacy Callback API (Backward Compatibility)

    @objc
    public func askAddContacts(_ uid: String,
                               sourceType: String?,
                               sourceConversationID: String?,
                               shareContactCardUid: String?,
                               action: String?,
                               sucess: @escaping (DTAPIMetaEntity?) -> Void,
                               failure: ((Error, DTAPIMetaEntity?) -> Void)? = nil) {
        var parms: [String: Any] = ["uid": uid]

        if let sourceType = sourceType {
            var source: [String: Any] = ["type": sourceType]

            switch sourceType {
            case "fromGroup":
                if let groupID = sourceConversationID {
                    source["groupID"] = groupID
                }
            case "shareContact":
                if let shareUid = shareContactCardUid {
                    source["uid"] = shareUid
                }
            case "randomCode":
                break
            case "search":
                break
            case "link":
                break
            default:
                break
            }

            parms["source"] = source
        }

        if let action = action {
            parms["action"] = action
        }

        guard let url = URL(string: self.requestUrl) else {
            return
        }

        let request = TSRequest(url: url, method: self.requestMethod, parameters: parms)
        request.shouldHaveAuthorizationHeaders = true

        DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken { [weak self] token, error in
            guard let weakSelf = self else {
                guard let failure = failure else { return }
                OWSLogger.info("asyncGetAuthToken self error")
                let error = NSError(domain: "askAddContactsError", code: -10000, userInfo: [NSLocalizedDescriptionKey: "pointer error"])
                failure(error, nil)
                return
            }

            guard error == nil else {
                guard let failure = failure else { return }
                let error = NSError(domain: "ask Add ContactsError", code: -10002, userInfo: [NSLocalizedDescriptionKey: "token invalid"])
                OWSLogger.info("asyncGetAuthToken token invalid")
                failure(error, nil)
                return
            }

            request.authToken = token
            weakSelf.networkManager.makeRequest(request, success: { response in
                do {
                    let entity = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self, fromJSONDictionary: response.responseBodyJson as? [AnyHashable: Any]) as! DTAPIMetaEntity
                    if entity.status != 0 {
                        guard let failure = failure else { return }
                        let error = NSError(domain: "ask Add Contacts", code: entity.status, userInfo: [NSLocalizedDescriptionKey: entity.reason])
                        failure(error, nil)
                    } else {
                        sucess(entity)
                    }
                } catch {
                    guard let failure = failure else { return }
                    failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError, kDTAPIDataErrorDescription), nil)
                }
            }, failure: { errorWrapper in
                guard let failure = failure else { return }
                let error = errorWrapper.asNSError
                failure(error, nil)
            })
        }
    }
}

