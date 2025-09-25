//
//  DTQueryIdentityKeyApi.swift
//  TTServiceKit
//
//  Created by hornet on 2022/12/31.
//

@objc
public class DTQueryIdentityKeyApi : DTBaseAPI {
    
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
            return "/v3/keys/identity/bulk";
        }
        set{
            super.requestUrl = newValue
        }
    }
    private struct JSONValue {
        let json: Any?
    }

    private static func parseJSON(data: Data?) -> JSONValue {
        guard let data = data,
              !data.isEmpty else {
                  return JSONValue(json: nil)
              }
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            return JSONValue(json: json)
        } catch {
            owsFailDebug("Could not parse JSON: \(error).")
            return JSONValue(json: nil)
        }
    }
    
    @objc
    public func quertIdentity(_ uids: [String], resetIdentityKeyTime: UInt64, sucess: @escaping RESTNetworkManagerSuccess, failure:((Error, DTAPIMetaEntity?) -> Void)? = nil)  {
        
        guard let url = URL(string: self.requestUrl) else {
            Logger.info("\(uids) quertIdentity parms abnormal")
            guard let failure = failure else { return }
            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.paramsError, kDTAPIParamsErrorDescription),nil)
            return
        }
        var params: [String: Any] = [:]
        if !uids.isEmpty {
            params["uids"] = uids
        }
        
        if resetIdentityKeyTime > 0 {
            params["beginTimestamp"] = resetIdentityKeyTime
        }
        
        let request : TSRequest = TSRequest.init(url: url, method: self.requestMethod, parameters: params)
        request.shouldHaveAuthorizationHeaders = true;
        DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken {[weak self] token, error in
            guard let weakSelf = self else {
                Logger.info("Api release")
                return
            }
            request.authToken = token
            weakSelf.networkManager.makeRequest(request, success: { response in
                Logger.info("quertIdentity sucess")
                sucess(response)
            }, failure: { errorWrapper in
                Logger.info("quertIdentity failure")
                guard let failure = failure else { return }
                if(errorWrapper.error.httpStatusCode == 413){
                    let error = errorWrapper.asNSError
                    failure(error, nil);
                    return
                }
                if (errorWrapper.error.httpStatusCode == 403 || errorWrapper.error.httpStatusCode == 500){
                    let json  =  errorWrapper.error.httpResponseJson
                    guard let jsonDic = json as? [String : Any] else {
                        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError, kDTAPIDataErrorDescription),nil)
                        return
                    }
                    do {
                        let errorResponse =  try MTLJSONAdapter.model(of: DTAPIMetaEntity.self, fromJSONDictionary: jsonDic)
                        guard let errorResponseEntity = errorResponse as? DTAPIMetaEntity else {
                            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError, kDTAPIDataErrorDescription),nil)
                            return
                        }
                        let error = errorWrapper.asNSError
                        failure(error, errorResponseEntity)
                        return
                    } catch _ {
                        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatus.dataError, kDTAPIDataErrorDescription),nil)
                    }
                } else {
                    failure(errorWrapper.asNSError, nil)
                }
                
            })
        };
    }
}
