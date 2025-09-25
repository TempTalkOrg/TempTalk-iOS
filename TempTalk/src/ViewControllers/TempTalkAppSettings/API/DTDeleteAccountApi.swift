//
//  DTDeleteAccountApi.swift
//  Signal
//
//  Created by hornet on 2023/6/23.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
@objc
public class DTDeleteAccountApi : DTBaseAPI {
    
    public override var requestMethod: String {
           get {
               return "DELETE";
           }
           set{
               super.requestMethod = newValue
           }
       
    }
    public override var requestUrl: String {
        get {
            return "/v1/accounts";
        }
        set{
            super.requestUrl = newValue
        }
    }

    @objc
    public func deleteRequest( sucess:@escaping (DTAPIMetaEntity?) -> Void, failure:((Error, DTAPIMetaEntity?) -> Void)? = nil)  {
        guard let url = URL(string: self.requestUrl) else {
            return
        }
        let request : TSRequest = TSRequest.init(url: url, method: self.requestMethod, parameters: nil)
        self.networkManager.makeRequest(request, success: { response in
                 do {
                     let entity :DTAPIMetaEntity = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self, fromJSONDictionary: response.responseBodyJson as? [AnyHashable : Any]) as! DTAPIMetaEntity
                     if(entity.status != 0 ){
                         guard let failure = failure else { return }
                         
                         let error = NSError(domain: "deleteRequest", code: entity.status ,userInfo: [NSLocalizedDescriptionKey:entity.reason])
                         failure(error,nil)
                     } else {
                         sucess(entity)
                     }
                 } catch _ {
                     guard let failure = failure else { return }
                     failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError, kDTAPIDataErrorDescription),nil)
                 }
                 
             }, failure: { errorWrapper in
                 guard let failure = failure else { return }
                 let error = errorWrapper.asNSError
                 failure(error, nil);
             });
    }
}
