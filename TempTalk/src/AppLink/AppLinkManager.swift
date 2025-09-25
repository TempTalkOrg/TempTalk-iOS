//
//  AppLinkManager.swift
//  TempTalk
//
//  Created by Kris.s on 2025/4/24.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

import Foundation

enum AppLinkType {
    case invite(referralCode: String)
    case linkDevice(uuid: String, pubKey: String)
    case dataTransfer
    case personCard(number: String)
    case unknown(String?)
}

protocol AppLinkHandler {
    static func canHandle(url: URL) -> Bool
    static func parse(url: URL) -> AppLinkType
    static func handle(url: URL, fromExternal: Bool, sourceVC: UIViewController?) -> Bool
    static var supportedSchemes: [String] { get }
}

extension AppLinkHandler {
    static var supportedSchemes: [String] {
        return [AppLinkNotificationHandler.kURLSchemeTempTalk, AppLinkNotificationHandler.kURLSchemeChative]
    }
}

struct AppLinkManager {

    private static var handlers: [AppLinkHandler.Type] = [
        InviteLinkHandler.self,
        PersonCardHandler.self,
//        DeviceLinkHandler.self,
//        DataTransferHandler.self
    ]
    
    static func handle(url: URL, fromExternal: Bool) -> Bool {
        return handle(url: url, fromExternal: fromExternal, sourceVC: nil)
    }
    
    static func handle(url: URL, fromExternal: Bool = false, sourceVC: UIViewController?) -> Bool {
        for handler in handlers {
            if handler.canHandle(url: url) {
                return handler.handle(url: url, fromExternal: fromExternal, sourceVC: sourceVC)
            }
        }
        
        Logger.info("没有找到能处理URL的处理器")
        
        if !fromExternal, let sourceVC {
            let scheme = url.scheme?.lowercased()
            if scheme == "https" ||
                scheme == "http" {
                handleUnknowURL(url, sourceVC: sourceVC, showWarning: true)
            } else {
                handleUnsupportPlatformURL(url)
            }
        }
        
        return false
    }
    
    private static func handleUnsupportPlatformURL(_ url: URL) {
        DTToastHelper.show(withInfo: Localized("GROUP_COMMEN_ERROR_SCHEME_ERROR"))
    }
    
    private static func handleUnknowURL(_ url: URL, sourceVC: UIViewController, showWarning: Bool) {
        openURL(url, sourceVC: sourceVC, showWarning: showWarning)
    }
    
    private static func openURL(_ url: URL, sourceVC: UIViewController, showWarning: Bool) {
        guard showWarning else {
            guard UIApplication.shared.canOpenURL(url) else {
                OWSLogger.error("open url failed")
                return
            }
            UIApplication.shared.open(url, options: [.universalLinksOnly: false])
            return
        }
        
        let alertVC = UIAlertController(
            title: Localized("WORKSPACE_WARNING_TITLE"),
            message: String(format: Localized("WORKSPACE_WARNING_DESC"), url.absoluteString),
            preferredStyle: .alert
        )
        let cancelAction = UIAlertAction(title: Localized("CANCEL"), style: .cancel)
        let openAction = UIAlertAction(title: Localized("OPEN"), style: .destructive) { action in
            guard UIApplication.shared.canOpenURL(url) else {
                OWSLogger.error("[func -> showWarningAlert] open url failed")
                return
            }
            UIApplication.shared.open(url, options: [.universalLinksOnly: false])
        }
        alertVC.addAction(cancelAction)
        alertVC.addAction(openAction)
        sourceVC.present(alertVC, animated: true)
    }

    
    static func registerHandler(_ handler: AppLinkHandler.Type, at index: Int? = nil) {

        guard !handlers.contains(where: { $0 == handler }) else { return }
        
        if let index = index, index >= 0 && index <= handlers.count {
            handlers.insert(handler, at: index)
        } else {
            handlers.append(handler)
        }
    }
    
    static func unregisterHandler(_ handler: AppLinkHandler.Type) {
        handlers.removeAll { $0 == handler }
    }
}
