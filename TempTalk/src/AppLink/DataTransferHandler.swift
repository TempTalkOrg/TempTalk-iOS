//
//  DataTransferHandler.swift
//  TempTalk
//
//  Created by Kris.s on 2025/4/24.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

struct DataTransferHandler: AppLinkHandler {
    static func canHandle(url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), supportedSchemes.contains(scheme) else {
            return false
        }
        return url.host?.lowercased() == AppLinkNotificationHandler.kURLHostTransfer
    }
    
    static func parse(url: URL) -> AppLinkType {
        guard canHandle(url: url) else { return .unknown(url.absoluteString) }
        return .dataTransfer
    }
    
    static func handle(url: URL, fromExternal: Bool, sourceVC: UIViewController?) -> Bool {
        return false
    }
}
