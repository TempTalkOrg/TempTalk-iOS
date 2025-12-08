//
//  CallCriticalAlertApi.swift
//  Difft
//
//  Created by henry on 2025/10/15.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

@objc
public class CallCriticalAlertApi : DTBaseAPI {
    
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
            return "/v3/messages/criticalAlert";
        }
        set{
            super.requestUrl = newValue
        }
    }
    private struct JSONValue {
        let json: Any?
    }
    
    func criticalAlertServers(_ parms: [String : Any], success:  @escaping((DTAPIMetaEntity?) -> Void), failure:((Error, DTAPIMetaEntity?) -> Void)? = nil)  {
        guard let url = URL(string: self.requestUrl) else {
            return
        }
        guard DTParamsUtils.validateDictionary(parms).boolValue == true else { return }
        let request : TSRequest = TSRequest.init(url: url, method: self.requestMethod, parameters: parms)
        request.shouldHaveAuthorizationHeaders = true;
        self.networkManager.makeRequest(request, success: { response in
            do {
                guard let entity = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self, fromJSONDictionary: response.responseBodyJson as? [AnyHashable : Any]) as? DTAPIMetaEntity else {
                    guard let failure = failure else { return }
                    failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError, kDTAPIDataErrorDescription), nil)
                    return
                }
                
                if(entity.status != 0 ){
                    guard let failure = failure else { return }
                    
                    let error = NSError(domain: "criticalAlert", code: entity.status ,userInfo: [NSLocalizedDescriptionKey:entity.reason])
                    failure(error,nil)
                } else {
                    success(entity)
                }
            } catch _ {
                guard let failure = failure else { return }
                failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError, kDTAPIDataErrorDescription),nil)
            }
            
        }, failure: { errorWrapper in
            guard let failure = failure else { return }
            let error = errorWrapper.asNSError
            failure(error, nil);
        });
    }
}


