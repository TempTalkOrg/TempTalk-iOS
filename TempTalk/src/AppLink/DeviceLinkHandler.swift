//
//  DeviceLinkHandler.swift
//  TempTalk
//
//  Created by Kris.s on 2025/4/24.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

struct DeviceLinkHandler: AppLinkHandler {
    static func canHandle(url: URL) -> Bool {
        return url.scheme?.lowercased() == "tsdevice"
    }
    
    static func parse(url: URL) -> AppLinkType {
        guard canHandle(url: url),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return .unknown(url.absoluteString)
        }
        
        var uuid: String?
        var pubKey: String?
        
        for item in components.queryItems ?? [] {
            if item.name == "uuid" {
                uuid = item.value
            } else if item.name == "pub_key" {
                pubKey = item.value
            }
        }
        
        if let uuid = uuid, let pubKey = pubKey {
            return .linkDevice(uuid: uuid, pubKey: pubKey)
        }
        
        return .unknown(url.absoluteString)
    }
    
    static func handle(url: URL, fromExternal: Bool, sourceVC: UIViewController?) -> Bool {
        return false
    }
}
