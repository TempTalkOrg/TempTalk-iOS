//
//  DTRecordScreenShotApi.swift
//  TTServiceKit
//
//  Created by hornet on 2023/5/11.
//

import Foundation
@objc
public class DTRecordScreenShotApi : DTBaseAPI {
    
    public override init() {
        super.init()
        self.serverType = .fileSharing
    }
    
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
            return "/v1/file/screencapture";
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
    func uploadScreenShotInfo(parms: [String : Any], sucess: @escaping RESTNetworkManagerSuccess, failure:((Error, DTAPIMetaEntity?) -> Void)? = nil)  {
        guard let url = URL(string: self.requestUrl) else {
            return
        }
        let request : TSRequest = TSRequest.init(url: url, method: self.requestMethod, parameters: parms)
        request.shouldHaveAuthorizationHeaders = true
        
        self.send(request) { entity in
            Logger.info("uploadScreenShotInfo sucess")
        } failure: { error in
            Logger.error("\(String(describing: error.httpStatusCode))")
        }
    }
}
