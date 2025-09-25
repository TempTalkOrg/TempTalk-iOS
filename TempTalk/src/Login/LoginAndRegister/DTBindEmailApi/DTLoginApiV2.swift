//
//  DTLoginApiV2.swift
//  TempTalk
//
//  Created by undefined on 21/12/24.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

class DTLoginApiV2: DTBaseAPI {
    
    override init() {
        super.init()
        
        self.serverType = .chat
    }
    
    func generateNonceCode(_ uuid: String, solution: String?, success: @escaping (DTAPIMetaEntity) -> Void, failure:((Error) -> Void)? = nil) {
        var parms : [String : Any]?
        parms = ["uuid":uuid, "solution": solution ?? ""]
        if let url = URL(string: "\(OWSRequestFactory.textSecureAccountsAPI)/generateNonceCode") {
            
            let request = TSRequest(url: url, method: "POST", parameters: parms)
            request.shouldHaveAuthorizationHeaders = false
            
            send(request) { entity in
                success(entity)
            } failure: { error in
                failure?(error)
            }
        } else {
            failure?(DTRequestErrorWithCodeDescription(DTAPIRequestStatus.urlError, kDTAPIRequestURLErrorDescription))
            Logger.error("Invalid URL")
        }
    }
    
    func receiveNonceInfo(success: @escaping (DTAPIMetaEntity) -> Void, failure:((Error) -> Void)? = nil) {
        guard let url = URL(string: "v1/accounts/getNonceInfo") else {
            failure?(DTRequestErrorWithCodeDescription(DTAPIRequestStatus.urlError, kDTAPIRequestURLErrorDescription))
            Logger.error("Invalid URL")
            return
        }
        let request = TSRequest(url: url, method: "POST", parameters: nil)
        
        send(request) { entity in
            success(entity)
        } failure: { error in
            failure?(error)
        }
    }
}
