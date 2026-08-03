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

    /// Returns true when `recipientId` belongs to a bot / service account.
    ///
    /// Bot and service accounts (official, meeting, critical, spooky, translate-cache, ...)
    /// use short E.164-style ids ("+10000", "+21163", ...) and do not run E2E encryption,
    /// so messages to them must carry legacy plaintext content. Real users have full-length
    /// phone numbers (> 6 chars).
    ///
    /// Note: broader than `SignalAccount.isBot`, which only matches `officialBotId`.
    public class func isBotId(_ recipientId: String) -> Bool {
        return !recipientId.isEmpty && recipientId.count <= 6
    }

}
