//
//  DTRenewAccountsApi.swift
//  Signal
//
//  Created by hornet on 2023/1/31.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation

public class DTResetAuthPasswordApi : DTBaseAPI {
    public override var requestMethod: String {
           get {
               return "PUT";
           }
           set{
               super.requestMethod = newValue
           }
    }
    public override var requestUrl: String {
        get {
            return "/v1/accounts/resetpassword/";
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
    
    ///CreatePreKeysOperation 中灰创建密钥相关
    /// TSAccountManager 中的 verifyAccountWithCode 这个方法需要生成和缓存 password （password = verifyAccountWithCode中 authToken），且该接口中的signalingKey 是用于解密消息的时候使用
    @objc
    func resetAuthPassword(_ token: String, password: String, sucess: @escaping (DTAPIMetaEntity?) -> Void, failure:((Error, DTAPIMetaEntity?) -> Void)? = nil)  {
        let parms: [String : Any] = ["token":token,"password":password]
        guard let url = URL(string: self.requestUrl) else {
            return
        }
        let request : TSRequest = TSRequest.init(url: url, method: self.requestMethod, parameters: parms)
        request.shouldHaveAuthorizationHeaders = false
        self.networkManager.makeRequest(request, success: { response in
            do {
                let entity :DTAPIMetaEntity = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self, fromJSONDictionary: response.responseBodyJson as? [AnyHashable : Any]) as! DTAPIMetaEntity
                if(entity.status != 0 ){
                    guard let failure = failure else { return }
                    let error = NSError(domain: "acceptForAddContactsRequest", code: entity.status ,userInfo: [NSLocalizedDescriptionKey:entity.reason])
                    failure(error,nil)
                } else {
                    sucess(entity)
                }
            } catch _ {
                guard let failure = failure else { return }
                failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError, kDTAPIDataErrorDescription),nil)
            }
//            sucess(response)
        }, failure: { errorWrapper in
            guard let failure = failure else { return }
            if(errorWrapper.error.httpStatusCode == 413){
                let error = errorWrapper.asNSError
                failure(error, nil);
                return
            }
            if (errorWrapper.error.httpStatusCode == 403 || errorWrapper.error.httpStatusCode == 500){
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
            } else {
                failure(errorWrapper.asNSError, nil)
            }
            
        });
    }
    
}


