//
//  DTLoginWithPhoneNumberCodeApi.swift
//  Signal
//
//  Created by hornet on 2022/11/3.
//  Copyright © 2022 Difft. All rights reserved.
//

import Foundation
@objc
public class DTLoginWithPhoneCodeApi : DTBaseAPI {
    
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
            return "/v2/auth/login/sms/verification";
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
    func login(_ phone: String, verificationCode: String, sucess: @escaping RESTNetworkManagerSuccess, failure:((Error, DTAPIMetaEntity?) -> Void)? = nil)  {
        let parms: [String : Any] = ["phone":phone, "verificationCode": verificationCode,"supportTransfer":1]
        guard let url = URL(string: self.requestUrl) else {
            return
        }
        let request : TSRequest = TSRequest.init(url: url, method: self.requestMethod, parameters: parms)
        request.shouldHaveAuthorizationHeaders = false
        self.networkManager.makeRequest(request, success: { response in
            do {
                let entity :DTAPIMetaEntity = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self, fromJSONDictionary: response.responseBodyJson as? [AnyHashable : Any]) as! DTAPIMetaEntity
                if(entity.status != 0){
                    guard let failure = failure else { return }
                    let error = NSError(domain: "/v2/auth/login/sms/verification error", code: entity.status ,userInfo: [NSLocalizedDescriptionKey:entity.reason])
                    failure(error,nil)
                } else {
                    sucess(response)
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
                failure(errorWrapper.asNSError,nil)
            }
           
        });
    }
}
