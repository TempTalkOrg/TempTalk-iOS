//
//  DTChatSetProfileApi.swift
//  Difft
//
//  Created by Henry on 2025/6/13.
//  Copyright © 2025 Difft. All rights reserved.
//

@objc public class DTChatSetProfileApi : DTBaseAPI {
    
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
            return "/v1/profile";
        }
        set{
            super.requestUrl = newValue
        }
    }
    
    @objc
    public func setProfileInfo(_ isOn: Bool, success:((DTAPIMetaEntity?) -> Void)? = nil, failure:((Error) -> Void)? = nil)  {
        guard let url = URL(string: self.requestUrl) else {
            return
        }
        let params: [String: Any] = [
            "privateConfigs": [
                "saveToPhotos": isOn
            ]
        ]
        let request : TSRequest = TSRequest.init(url: url, method: self.requestMethod, parameters: params)
        request.shouldHaveAuthorizationHeaders = true;
        self.networkManager.makeRequest(request, success: { response in
            do {
                let entity :DTAPIMetaEntity = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self, fromJSONDictionary: response.responseBodyJson as? [AnyHashable : Any]) as! DTAPIMetaEntity
                if(entity.status != 0 ){
                    guard let failure = failure else { return }
                    
                    let error = NSError(domain: "setProfileInfo", code: entity.status ,userInfo: [NSLocalizedDescriptionKey:entity.reason])
                    failure(error)
                } else {
                    guard let sucess = success else { return  }
                    sucess(entity)
                }
            } catch _ {
                guard let failure = failure else { return }
                failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError, kDTAPIDataErrorDescription))
            }
            
        }, failure: { errorWrapper in
            guard let failure = failure else { return }
            let error = errorWrapper.asNSError
            failure(error);
        });
    }
}
