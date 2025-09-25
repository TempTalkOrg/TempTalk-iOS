//
//  DTSpookyBotConfig.swift
//  TTServiceKit
//
//  Created by Ethan on 03/02/2023.
//

import Foundation

@objcMembers
public class DTBotConfig: NSObject {

    private class func defultSpookyBotConfig() -> String {
        guard let appInfo = Bundle.main.infoDictionary else {
            return ""
        }
        let appName = appInfo["CFBundleDisplayName"] as! String
        
        return appName == "WeaTest" ? "+22098" : "+21163"
    }
    
     public class func serverSpookyBotId() -> String {
        var spookyBotId = defultSpookyBotConfig()
        DTServerConfigManager.shared().fetchConfigFromLocal(withSpaceName: "spookyBotId") { config, error in
            guard let config = config as? String, error == nil else {
                return
            }
            spookyBotId = config
        }
        
        return spookyBotId
    }
    
    private class func defultTranslateCacheBotConfig() -> [String] {
        guard let appInfo = Bundle.main.infoDictionary else {
            return [""]
        }
        let appName = appInfo["CFBundleDisplayName"] as! String
        
        if appName == "WeaTest" || appName == "ccTest" {
            
            return ["+20001"]
        } else {
            
            return ["+20001",
                    "+21110",
                    "+22057",
                    "+21165",
                    "+21176",
                    "+21200",
                    "+21225",
                    "+21240",
                    "+21132",
                    "+21312",
                    "+21399",
                    "+20186",
                    "+21311",
                    "+21350",
                    "+21448",
                    "+21449",
                    "+21450",
                    "+21451",
                    "+21452",
                    "+21453",
                    "+21487"]
        }
    }
    
    public class func serverTranslateCacheBot() -> [String] {
        var translateCacheBot = defultTranslateCacheBotConfig()
        DTServerConfigManager.shared().fetchConfigFromLocal(withSpaceName: "translateCacheBot") { config, error in
            guard let config = config as? [String], error == nil else {
                return
            }
            translateCacheBot = config
        }
        
        return translateCacheBot
    }
    
    public class func meetingBotId() -> String {
        "+10002"
    }
    
    public class func criticalBotId() -> String {
        "+22435"
    }

}
