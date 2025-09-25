//
//  DTMTAManager.m
//  Signal
//
//  Created by hornet on 2023/5/11.
//  Copyright © 2023 Difft. All rights reserved.
//
///⚠️目的是建立打点工具，这个暂时没有自建日志系统，所以可用Api只有一个上报截屏 ,自建日志系统后调整该类


@objc
public class DTMTAManager: NSObject {
    
    @objc(sharedManager)
    public static let shared = DTMTAManager()

    private override init() {
        super.init()

        SwiftSingletons.register(self)
    }
    
    private let recordScreenShotApi = DTRecordScreenShotApi()

    @objc
    public class func screenShotEvent(picture:String ,page: String?, details: String?) {
//        DTTokenHelper.sharedInstance.asyncFetchGlobalAuthToken { token, error in
//            guard let token = token else {
//                Logger.error("token is nil")
//                return
//            }
//            
//            let time = NSDate.ows_millisecondTimeStamp()
//            let eventAttributes: [String : Any] = [
//                "token":token,
//                "action":"0",
//                "deviceType":"iOS",
//                "time":time,
//                "view": page == nil ? "" : page!,
//                "picture":picture,
//                "details": details == nil ? "" : details!
//            ]
//            
//            self.shared.recordScreenShotApi.uploadScreenShotInfo(parms: eventAttributes) { response in
//                
//            } failure: { error, _ in
//                
//            }
//        }
    }
}
