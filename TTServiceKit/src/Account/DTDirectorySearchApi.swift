//
//  DTDirectorySearchApi.swift
//  TTServiceKit
//
//  Created by henry Code on 2025/1/7.
//

import Foundation

@objc
public class DTDirectorySearchApi: DTBaseAPI {

    public override var requestMethod: String {
        get {
            return "POST"
        }
        set {
            super.requestMethod = newValue
        }
    }

    public override var requestUrl: String {
        get {
            return "/v3/directory/search"
        }
        set {
            super.requestUrl = newValue
        }
    }

    @objc
    public func search(_ condition: String,
                      success: @escaping ((DTDirectorySearchResult?) -> Void),
                      failure: @escaping ((Error) -> Void)) {

        guard let url = URL(string: self.requestUrl), !condition.isEmpty else {
            Logger.info("Directory search params abnormal")
            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.paramsError,
                                              kDTAPIParamsErrorDescription))
            return
        }

        let parameters: [String: Any] = [
            "ver": 1,
            "condition": condition
        ]

        let request: TSRequest = TSRequest(url: url, method: self.requestMethod, parameters: parameters)
        request.shouldHaveAuthorizationHeaders = true

        DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken { [weak self] token, error in
            guard let weakSelf = self else {
                Logger.info("Api released")
                failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.invalidToken,
                                                  kDTAPIParamsErrorDescription))
                return
            }

            request.authToken = token
            weakSelf.networkManager.makeRequest(request, success: { response in
                do {
                    let entity: DTAPIMetaEntity = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self,
                                                    fromJSONDictionary: response.responseBodyJson as? [AnyHashable: Any]) as! DTAPIMetaEntity
                    if entity.status != 0 {
                        let error = NSError(domain: "Directory search error", code: entity.status,
                                          userInfo: [NSLocalizedDescriptionKey: entity.reason])
                        failure(error)
                    } else {
                        // Parse the data field into DTDirectorySearchResult
                        if let data = entity.data as? [String: Any],
                           let jsonData = try? JSONSerialization.data(withJSONObject: data) {
                            do {
                                let result = try JSONDecoder().decode(DTDirectorySearchResult.self, from: jsonData)
                                success(result)
                            } catch {
                                Logger.error("Failed to decode DTDirectorySearchResult: \(error)")
                                failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError,
                                                                  kDTAPIDataErrorDescription))
                            }
                        } else {
                            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError,
                                                              kDTAPIDataErrorDescription))
                        }
                    }
                } catch _ {
                    failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError,
                                                      kDTAPIDataErrorDescription))
                }
            }, failure: { errorWrapper in
                Logger.info("Directory search failure")
                let error = errorWrapper.asNSError
                failure(error)
            })
        }
    }
}
