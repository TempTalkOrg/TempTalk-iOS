//
//  RenewIDKeyAPI.swift
//  Signal
//
//  Created by Kris.s on 2024/10/30.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

@objc(DTRenewIDKeyAPI)
public class RenewIDKeyAPI : DTBaseAPI {
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
            return "/v2/keys/resetIdentity";
        }
        set{
            super.requestUrl = newValue
        }
    }
    
    @objc
    public func sendResetIdentityRequest(_ identityKey: String,
                                         registrationId: Int,
                                         newSign: String,
                                         oldSign: String?,
                                         sucess: @escaping (DTAPIMetaEntity) -> Void,
                                         failure: @escaping ((Error) -> Void))  {
        guard let url = URL(string: self.requestUrl) else {
            failure(DTErrorWithCodeDescription(.paramsError, kDTAPIParamsErrorDescription));
            return
        }
        if identityKey.isEmpty || registrationId <= 0 || newSign.isEmpty {
            failure(DTErrorWithCodeDescription(.paramsError, kDTAPIParamsErrorDescription));
            return
        }
        
        var parameters: [String: Any] = [
            "identityKey": identityKey,
            "registrationId": registrationId,
            "newSign": newSign
        ]
        if let oldSign, !oldSign.isEmpty {
            parameters["oldSign"] = oldSign
        }
        let request : TSRequest = TSRequest.init(url: url, method: self.requestMethod, parameters: parameters)
        request.shouldHaveAuthorizationHeaders = true;
        self.send(request, success: sucess, failure: failure)
    }
}
