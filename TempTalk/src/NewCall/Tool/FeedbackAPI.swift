//
//  FeedbackAPI.swift
//  Difft
//
//  Created by henry on 2025/10/15.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
@objc
public class FeedbackAPI : DTBaseAPI {
    
    override init() {
        super.init()
    }
     
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
            return "/v3/call/feedback";
        }
        set{
            super.requestUrl = newValue
        }
    }
    
    private struct JSONValue {
        let json: Any?
    }
    
    private static func parseJSON(data: Data?) -> JSONValue {
        guard let data = data,
              !data.isEmpty else {
                  return JSONValue(json: nil)
              }
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return JSONValue(json: json)
        } catch {
            owsFailDebug("Could not parse JSON: \(error).")
            return JSONValue(json: nil)
        }
    }
    
    @objc
    func feedbackServers(params: [String: Any], success: @escaping((DTAPIMetaEntity?) -> Void), failure:((Error, DTAPIMetaEntity?) -> Void)? = nil)  {
        guard let url = URL(string: self.requestUrl) else {
            return
        }
        let request : TSRequest = TSRequest.init(url: url, method: self.requestMethod, parameters: params)
        request.shouldHaveAuthorizationHeaders = true
        request.serverType = .call
        DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken {[weak self] token, error in
            guard let weakSelf = self else {
                let error = NSError(domain: "feedbackServersError", code: 100000 ,userInfo: [NSLocalizedDescriptionKey:"parameters error"])
                guard let failure = failure else { return }
                failure(error, nil)
                return
            }
            request.authToken = token
            weakSelf.networkManager.makeRequest(request, success: { response in
                do {
                    let entity :DTAPIMetaEntity = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self, fromJSONDictionary: response.responseBodyJson as? [AnyHashable : Any]) as! DTAPIMetaEntity
                    if(entity.status != 0){
                        guard let failure = failure else { return }
                        let error = NSError(domain: "\(weakSelf.requestUrl) error", code: entity.status ,userInfo: [NSLocalizedDescriptionKey:entity.reason])
                        failure(error,entity)
                    } else {
                        success(entity)
                    }
                } catch _ {
                    guard let failure = failure else { return }
                    failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError, kDTAPIDataErrorDescription),nil)
                }
            }, failure: { errorWrapper in
                guard let failure = failure else { return }
                if(errorWrapper.error.httpStatusCode == 413){
                    let error = errorWrapper.asNSError
                    failure(error, nil);
                    return
                }
                let json  =  errorWrapper.error.httpResponseJson
                guard let jsonDic = json as? [String : Any] else {
                    failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError, kDTAPIDataErrorDescription),nil)
                    return
                }
                do {
                    let errorResponse =  try MTLJSONAdapter.model(of: DTAPIMetaEntity.self, fromJSONDictionary: jsonDic)
                    guard let errorResponseEntity = errorResponse as? DTAPIMetaEntity else {
                        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError, kDTAPIDataErrorDescription),nil)
                        return
                    }
                    let error = errorWrapper.asNSError
                    failure(error, errorResponseEntity)
                    return
                } catch _ {
                    failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError, kDTAPIDataErrorDescription),nil)
                }
            });
        }
    }
}
