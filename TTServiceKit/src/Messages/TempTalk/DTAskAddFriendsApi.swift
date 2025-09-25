//
//  DTAskAddFriendsApi.swift
//  TTServiceKit
//
//  Created by hornet on 2022/11/16.
//

import Foundation
@objc
public class DTAskAddFriendsApi : DTBaseAPI {
    
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
            return "/v3/friend/ask";
        }
        set{
            super.requestUrl = newValue
        }
    }

    @objc
    public func askAddContacts(_ uid: String,
                               sourceType: String?,
                               sourceConversationID: String?,
                               shareContactCardUid: String?,
                               action:String?,
                               sucess:@escaping (DTAPIMetaEntity?) -> Void,
                               failure:((Error, DTAPIMetaEntity?) -> Void)? = nil)  {
        var parms: [String : Any] = ["uid":uid]
        if let sourceType = sourceType, let sourceConversationID = sourceConversationID {
            parms["source"] = ["type":sourceType,"groupID":sourceConversationID]
        } else if let sourceType = sourceType, let shareContactCardUid = shareContactCardUid {
            parms["source"] = ["type":sourceType,"uid":shareContactCardUid]
        }
        if let action = action {
            parms["action"] = action
        }
        guard let url = URL(string: self.requestUrl) else {
            return
        }
        let request : TSRequest = TSRequest.init(url: url, method: self.requestMethod, parameters: parms)
        request.shouldHaveAuthorizationHeaders = true;
        DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken {[weak self] token, error in
            guard let weakSelf = self else {
                guard let failure = failure else { return }
                OWSLogger.info("asyncGetAuthToken self error")
                let error = NSError(domain: "askAddContactsError", code: -10000 ,userInfo:[NSLocalizedDescriptionKey:"pointer error"])
                failure(error,nil)
                return
            }
            
            guard  error == nil else {
                guard let failure = failure else { return }
                let error = NSError(domain: "ask Add ContactsError", code: -10002 ,userInfo:[NSLocalizedDescriptionKey:"token invalid"])
                OWSLogger.info("asyncGetAuthToken token invalid")
                failure(error,nil)
                return
            }
            
            request.authToken = token
            weakSelf.networkManager.makeRequest(request, success: { response in
                do {
                    let entity :DTAPIMetaEntity = try MTLJSONAdapter.model(of: DTAPIMetaEntity.self, fromJSONDictionary: response.responseBodyJson as? [AnyHashable : Any]) as! DTAPIMetaEntity
                    if(entity.status != 0 ){
                        guard let failure = failure else { return }
                        
                        let error = NSError(domain: "ask Add Contacts", code: entity.status ,userInfo: [NSLocalizedDescriptionKey:entity.reason])
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

