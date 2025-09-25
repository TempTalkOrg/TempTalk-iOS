//
//  DTGetLocationApi.swift
//  Signal
//
//  Created by hornet on 2022/11/3.
//  Copyright © 2022 Difft. All rights reserved.
//

import Foundation
@objc
public class DTGetLocationApi : DTBaseAPI {
    
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
            return "/v1/utils/location";
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
    public func location(_ sucess: @escaping RESTNetworkManagerSuccess, failure: ((Error, DTAPIMetaEntity?) -> Void)? = nil)  {
        guard let url = URL(string: self.requestUrl) else {
            return
        }
        let request : TSRequest = TSRequest.init(url: url, method: self.requestMethod, parameters: nil)
        request.shouldHaveAuthorizationHeaders = false
        self.networkManager.makeRequest(request, success: { response in
            sucess(response)
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
