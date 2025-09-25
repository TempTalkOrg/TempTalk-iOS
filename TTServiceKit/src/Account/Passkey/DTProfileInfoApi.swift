//
//  DTAskAddFriendsApi.swift
//  TTServiceKit
//
//  Created by hornet on 2022/11/16.
//

import Foundation


@objc public class ProfileInfoConstants: NSObject {
    @objc
    public static let passkeysSwitchKey: String = "kPasskeysSwitchKey"
}

@objc public class DTProfileInfoApi : DTBaseAPI {
    
    public override var requestUrl: String {
        get {
            return "/v3/directory/profile";
        }
        set{
            super.requestUrl = newValue
        }
    }

    @objc
    public func profileInfo(sucess:((DTAPIMetaEntity?) -> Void)? = nil , failure:((Error) -> Void)? = nil)  {
        guard let url = URL(string: self.requestUrl) else {
            return
        }
        let request : TSRequest = TSRequest.init(url: url, method: "GET", parameters: nil)
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
                         
                         let error = NSError(domain: "profileInfo", code: entity.status ,userInfo: [NSLocalizedDescriptionKey:entity.reason])
                         failure(error)
                     } else {
                         
                         guard let responseData = entity.data as? [String : Any] else {
                             sucess?(entity)
                             return
                         }
                         
                         if let passkeysSwitch =  responseData["passkeysSwitch"] as? Int{
                             DTTokenKeychainStore.setPassword("\(passkeysSwitch)", forAccount: ProfileInfoConstants.passkeysSwitchKey)
                         } else {
                             DTTokenKeychainStore.setPassword("\(0)", forAccount: ProfileInfoConstants.passkeysSwitchKey)
                         }
                         
                         let oldMasked = "********"
                         
                         if let emailMasked =  responseData["emailMasked"] as? String,
                            !emailMasked.isEmpty {
                             if emailMasked == oldMasked {
                                 if let userEmail = TSAccountManager.shared.loadStoredUserEmail(),
                                    !userEmail.isEmpty {
                                     //use old email
                                 } else {
                                     TSAccountManager.shared.storeUserEmail(emailMasked)
                                 }
                             } else {
                                 TSAccountManager.shared.storeUserEmail(emailMasked)
                             }
                         } else {
                             TSAccountManager.shared.storeUserEmail("")
                         }
                         
                         if let phoneMasked =  responseData["phoneMasked"] as? String,
                            !phoneMasked.isEmpty {
                             if phoneMasked == oldMasked {
                                 if let userPhone = TSAccountManager.shared.loadStoredUserPhone(),
                                    !userPhone.isEmpty {
                                     //use old phone
                                 } else {
                                     TSAccountManager.shared.storeUserPhone(phoneMasked)
                                 }
                             } else {
                                 TSAccountManager.shared.storeUserPhone(phoneMasked)
                             }
                         } else {
                             TSAccountManager.shared.storeUserPhone("")
                         }
                         
                         sucess?(entity)
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
         };
    }
    
    @objc
    public func setProfileInfo(_ parms: [String : Any], sucess:((DTAPIMetaEntity?) -> Void)? = nil, failure:((Error) -> Void)? = nil)  {
        guard let url = URL(string: self.requestUrl) else {
            return
        }
        let request : TSRequest = TSRequest.init(url: url, method: "PUT", parameters: parms)
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
                         
                         let error = NSError(domain: "setProfileInfo", code: entity.status ,userInfo: [NSLocalizedDescriptionKey:entity.reason])
                         failure(error)
                     } else {
                         guard let sucess = sucess else { return  }
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
         };
    }
}

