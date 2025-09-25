//
//  DTCheckUserPasskeyApi.swift
//  TTServiceKit
//
//  Created by hornet on 2023/7/25.
//

import Foundation
@objc
public class DTCheckUserPasskeyApi : DTBaseAPI {
    
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
            return "/v3/webauthn/user";
        }
        set{
            super.requestUrl = newValue
        }
    }
    private struct JSONValue {
        let json: Any?
    }
    
    ///暂时不用
    @objc func checkPasskeys(email: String?, phoneNumber: String?, sucess: @escaping (DTAPIMetaEntity?) -> Void, failure:((Error, DTAPIMetaEntity?) -> Void)? = nil) {
        guard  let url = URL(string: self.requestUrl) else {
            return
        }
        var parms = [String : Any]()
        if let email = email {
            parms["email"] = email
        }
        if let phoneNumber = phoneNumber {
            parms["phone"] = phoneNumber
        }
        
        if(!DTParamsUtils.validateDictionary(parms).boolValue){
            Logger.info("checkPasskeysUserInfo parms error ")
            return
        }
        
        let request : TSRequest = TSRequest.init(url: url, method: self.requestMethod, parameters: parms)
        request.shouldHaveAuthorizationHeaders = false
        self.networkManager.makeRequest(request, success: { response in
            do {
                let entity :DTAPIMetaEntity = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self, fromJSONDictionary: response.responseBodyJson as? [AnyHashable : Any]) as! DTAPIMetaEntity
                if(entity.status != 0){
                    guard let failure = failure else { return }
                    let error = NSError(domain: "\(self.requestUrl) error", code: entity.status ,userInfo: [NSLocalizedDescriptionKey:entity.reason])
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
    }
}
