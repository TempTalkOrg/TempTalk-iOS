//
//  InviteLinkHandler.swift
//  TempTalk
//
//  Created by Kris.s on 2025/4/24.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

struct InviteLinkHandler: AppLinkHandler {
    private static let invitePattern = #"pi=(([a-zA-Z0-9]{8}|[a-zA-Z0-9]{32})|\d{4})"#
    private static let inviteRegex = try! NSRegularExpression(pattern: invitePattern, options: .caseInsensitive)
    private static let supportedHosts = [AppLinkNotificationHandler.kURLHostTempTalk, AppLinkNotificationHandler.kURLHost3WTempTalk]
    
    static func canHandle(url: URL) -> Bool {
        // 处理Universal Link
        if url.scheme?.lowercased() == "https" {
            if let host = url.host?.lowercased(),
                supportedHosts.contains(host),
                url.path == AppLinkNotificationHandler.kULinkPathInvite{
                return true
            }
        }
        
        // 处理Custom Scheme
        if let scheme = url.scheme?.lowercased(), supportedSchemes.contains(scheme) {
            return url.host?.lowercased() == AppLinkNotificationHandler.kURLHostInvite
        }
        
        return false
    }
    
    static func parse(url: URL) -> AppLinkType {
        let query = url.query ?? ""
        
        if let match = inviteRegex.firstMatch(in: query, options: [], range: NSRange(location: 0, length: query.count)) {
            let range = match.range(at: 1)
            if let swiftRange = Range(range, in: query) {
                let referralCode = String(query[swiftRange])
                return .invite(referralCode: referralCode)
            }
        }
        
        return .unknown(url.absoluteString)
    }
    
    static func handle(url: URL, fromExternal: Bool, sourceVC: UIViewController?) -> Bool {
        guard canHandle(url: url) else { return false }
        
        let linkType = parse(url: url)
        guard case .invite(let referralCode) = linkType else {
            DTToastHelper.show(withInfo: Localized("REGISTRATION_VIEW_NO_INVITE_CODE_TITLE"))
            Logger.error("referralCode is empty!")
            return false
        }
        
        AppReadiness.runNowOrWhenAppDidBecomeReadySync {
            
            if !TSAccountManager.isRegistered() ||
                TSAccountManager.shared.isDeregistered(){
                return
            }
            
            if fromExternal {
                AppLinkNotificationHandler.postExternalInviteNotification(inviteCode: referralCode)
            } else if let sourceVC {
                let inviteRequestHandler = DTInviteRequestHandler(sourceVc: sourceVC)
                inviteRequestHandler.queryUserAccount(byInviteCode: referralCode)
            }
        }
        
        return true
    }
    
}
