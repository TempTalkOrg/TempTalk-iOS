//
//  LiveKitServersApi.swift
//  Difft
//
//  Created by henry on 2025/9/15.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
@objc
public class LiveKitServersApi : DTBaseAPI {
    
    override init() {
        super.init()
        self.serverType = .call
    }
     
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
            return "/v3/call/serviceurl";
        }
        set{
            super.requestUrl = newValue
        }
    }
    private struct JSONValue {
        let json: Any?
    }
    
    @objc
    func liveKitServers(success: @escaping((DTAPIMetaEntity?) -> Void), failure:((Error, DTAPIMetaEntity?) -> Void)? = nil)  {
        guard let url = URL(string: self.requestUrl) else {
            return
        }
        let request : TSRequest = TSRequest.init(url: url, method: self.requestMethod, parameters: nil)
        request.shouldHaveAuthorizationHeaders = true
        DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken {[weak self] token, error in
            guard let weakSelf = self else {
                let error = NSError(domain: "LiveKitServersAPIError", code: 100000 ,userInfo: [NSLocalizedDescriptionKey:"parameters error"])
                guard let failure = failure else { return }
                failure(error, nil)
                return
            }
            request.authToken = token
            weakSelf.send(request) { entity in
                if(entity.status != 0){
                    guard let failure = failure else { return }
                    let error = NSError(domain: "LiveKitServersAPIError", code: entity.status ,userInfo: [NSLocalizedDescriptionKey:entity.reason])
                    failure(error,nil)
                } else {
                    success(entity)
                }

            } failure: { error in
                guard let failure = failure else { return }
                failure(error, nil);
            }
        };
    }
}
