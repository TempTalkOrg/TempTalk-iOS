//
//  DTRemoveFriendsApi.swift
//  TTServiceKit
//
//  Created by hornet on 2022/11/18.
//

import Foundation
@objc
public class DTRemoveFriendsApi : DTBaseAPI {
    
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
            return "/v3/friend/";
        }
        set{
            super.requestUrl = newValue
        }
    }

    @objc
    public func removeContact(_ uid: String, sucess:@escaping (DTAPIMetaEntity?) -> Void, failure:((Error, DTAPIMetaEntity?) -> Void)? = nil)  {
        let requestUrl = self.requestUrl + uid
        guard let url = URL(string: requestUrl) else {
            return
        }
        let request : TSRequest = TSRequest.init(url: url, method: self.requestMethod, parameters: nil)
        request.shouldHaveAuthorizationHeaders = true;
         DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken {[weak self] token, error in
             guard let weakSelf = self else {
                 return
             }
             request.authToken = token
             weakSelf.networkManager.makeRequest(request, success: { response in
                 do {
                     let entity :DTAPIMetaEntity = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self, fromJSONDictionary: response.responseBodyJson as? [AnyHashable : Any]) as! DTAPIMetaEntity
                     if(entity.status != 0 ){
                         guard let failure = failure else { return }
                         
                         let error = NSError(domain: "askAddContactsRequestError", code: entity.status ,userInfo: [NSLocalizedDescriptionKey:entity.reason])
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
         };
    }
}
