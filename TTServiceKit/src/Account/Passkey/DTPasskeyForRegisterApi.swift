//
//  DTRegisterForPasskeys.swift
//  Signal
//
//  Created by hornet on 2023/7/18.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
@objc
public class DTPasskeyForRegisterApi : DTBaseAPI {
    
    public override var requestMethod: String {
        get {
            return "GET";
        }
        set{
            super.requestMethod = newValue
        }
    }
    
    public override var requestUrl: String {
        get {
            return "/v3/webauthn/registration/initialize";
        }
        set{
            super.requestUrl = newValue
        }
    }
    private struct JSONValue {
        let json: Any?
    }
    
    @objc
    func registerForPasskeys(sucess: @escaping((DTAPIMetaEntity?) -> Void), failure:((Error, DTAPIMetaEntity?) -> Void)? = nil)  {
        guard let url = URL(string: self.requestUrl) else {
            return
        }
        let request : TSRequest = TSRequest.init(url: url, method: self.requestMethod, parameters: nil)
        request.shouldHaveAuthorizationHeaders = true
        DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken {[weak self] token, error in
            guard let weakSelf = self, error == nil else {
                return
            }
            request.authToken = token
            weakSelf.networkManager.makeRequest(request, success: { response in
                do {
                    let entity :DTAPIMetaEntity = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self, fromJSONDictionary: response.responseBodyJson as? [AnyHashable : Any]) as! DTAPIMetaEntity
                    if(entity.status != 0){
                        guard let failure = failure else { return }
                        let error = NSError(domain: "\(weakSelf.requestUrl)", code: entity.status ,userInfo: [NSLocalizedDescriptionKey:entity.reason])
                        failure(error,entity)
                    } else {
                        sucess(entity)
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
        };
    }
}
