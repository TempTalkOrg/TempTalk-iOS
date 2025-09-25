//
//  PersonCardHandler.swift
//  TempTalk
//
//  Created by Kris.s on 2025/4/28.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation


struct PersonCardHandler: AppLinkHandler {
    static func canHandle(url: URL) -> Bool {
        return url.scheme?.lowercased() == AppLinkNotificationHandler.kURLSchemePersoninfocard
    }
    
    static func parse(url: URL) -> AppLinkType {
        guard canHandle(url: url),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return .unknown(url.absoluteString)
        }
        
        if let number = components.host, isValidPhoneNumber(phoneNumber: number) {
            return .personCard(number: number)
        }
        
        return .unknown(url.absoluteString)
    }
    
    static func isValidPhoneNumber(phoneNumber: String) -> Bool {
        if phoneNumber.hasPrefix("+") {
            if phoneNumber.count == 6 || phoneNumber.count == 12 {
                return true
            }
        }
        return false
    }
    
    static func handle(url: URL, fromExternal: Bool, sourceVC: UIViewController?) -> Bool {
        // 只支持内部跳转
        guard !fromExternal else { return false }
        
        guard canHandle(url: url) else { return false }
        
        let linkType = parse(url: url)
        guard case .personCard(let number) = linkType else {
            DTToastHelper.show(withInfo: Localized("GROUP_COMMEN_ERROR_SCHEME_ERROR"))
            Logger.error("number is empty!")
            return false
        }
        
        if let sourceVC {
            sourceVC.showProfileCardInfo(with: number)
        }
        
        return false
    }

}
