//
//  DTUpdateConversationShareConfigApi.swift
//  Signal
//
//  Created by hornet on 2022/11/10.
//  Copyright © 2022 Difft. All rights reserved.
//

import Foundation
@objc
public class DTUpdateConversationShareConfigApi : DTBaseAPI {
    
    public override init() {
        super.init()
    }
    
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
            return "/v1/conversationconfig/share/";
        }
        set{
            super.requestUrl = newValue
        }
    }
    
    private struct JSONValue {
        let json: Any?
    }
    
    @objc
    public func updateConversationShareConfig(_ conversation: String, messageExpiry: NSNumber, sucess:@escaping (DTAPIMetaEntity?) -> Void, failure:((Error, DTAPIMetaEntity?) -> Void)? = nil)  {
        var parms : [String : Any]?
        guard let url = URL(string: self.requestUrl + "\(conversation)") else {
            let error = NSError(domain: "updateConversationShareConfigError", code: 100001 ,userInfo: [NSLocalizedDescriptionKey:"parms error"])
            guard let failure = failure else { return }
            failure(error, nil)
            return
        }
        parms = ["messageExpiry":messageExpiry]
        guard let parms = parms else {
            let error = NSError(domain: "updateConversationShareConfigError", code: 100002 ,userInfo: [NSLocalizedDescriptionKey:"parms messageExpiry error"])
            guard let failure = failure else { return }
            failure(error, nil)
            return
        }
       
        let request : TSRequest = TSRequest.init(url: url, method: self.requestMethod, parameters: parms)
        
        request.shouldHaveAuthorizationHeaders = true;
         DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken {[weak self] token, error in
             guard let weakSelf = self else {
                 let error = NSError(domain: "updateConversationShareConfigError", code: 100000 ,userInfo: [NSLocalizedDescriptionKey:"parms error"])
                 guard let failure = failure else { return }
                 failure(error, nil)
                 return
             }
             request.authToken = token
             weakSelf.send(request) { entity in
                 if(entity.status != 0){
                     guard let failure = failure else { return }
                     let error = NSError(domain: "updateConversationShareConfigError", code: entity.status ,userInfo: [NSLocalizedDescriptionKey:entity.reason])
                     failure(error,nil)
                 } else {
                     sucess(entity)
                 }

             } failure: { error in
                 guard let failure = failure else { return }
                 failure(error, nil);
             }
         };
    }
}
