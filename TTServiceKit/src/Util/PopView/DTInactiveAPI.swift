//
//  DTInactiveAPI.swift
//  Pods
//
//  Created by Henry on 2025/2/12.
//

import Foundation

@objc
public class DTInactiveAPI : DTBaseAPI {
    
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
            return "v1/accounts/activate";
        }
        set{
            super.requestUrl = newValue
        }
    }
    
    func activeDeviceRequest(success: @escaping (DTAPIMetaEntity) -> Void, failure:((Error) -> Void)? = nil) {
        guard let url = URL(string: self.requestUrl) else {
            failure?(DTRequestErrorWithCodeDescription(DTAPIRequestStatus.urlError, kDTAPIRequestURLErrorDescription))
            Logger.error("Invalid URL")
            return
        }
        let request = TSRequest(url: url, method: self.requestMethod, parameters: nil)
        
        send(request) { entity in
            success(entity)
        } failure: { error in
            failure?(error)
        }
    }
}
