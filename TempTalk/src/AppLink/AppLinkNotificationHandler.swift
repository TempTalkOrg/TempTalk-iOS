//
//  AppLinkNotificationHandler.swift
//  TempTalk
//
//  Created by Kris.s on 2025/4/24.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

@objc class AppLinkNotificationHandler: NSObject {
    
    @objc static let kURLSchemeChative = "chative"
    @objc static let kURLSchemeTempTalk = "temptalk"
    
    //only support internal
    @objc static let kURLSchemePersoninfocard = "personinfocard"
    
    @objc static let kURLHostTransfer = "transfer"
    @objc static let kURLHostInvite = "invite"
    @objc static let kURLHostTempTalk = "temptalk.app"
    @objc static let kURLHost3WTempTalk = "www.temptalk.app"
    
    @objc static let kULinkPathInvite = "/u"
    
    @objc static let kURLPeroidInviteCodeKey = "pi"
    
    
    @objc static let externalInviteNotification = Notification.Name("kExternalInviteNotification")
    
    @objc static let inviteCodeKey = "kOpenAppInviteCodeKey"
    
    // MARK: - Public Methods
    
    @objc static func postExternalInviteNotification(inviteCode: String) {

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            
            TTNavigator.goToHomePage()
            
            let notificationName: Notification.Name
            
            NotificationCenter.default.post(
                name: externalInviteNotification,
                object: nil,
                userInfo: [inviteCodeKey: inviteCode]
            )
        }
    }
        
}
