//
//  LogoutManager.swift
//  Difft
//
//  Created by henry on 2025/9/26.
//  Copyright © 2025 Difft. All rights reserved.
//

@objcMembers
open class LogoutManager: NSObject, ObservableObject {
    static let shared = LogoutManager()
    
    public weak var logoutDelegate: LogoutDelegate?

    public override init() {}

    public func handleKickoutMessage() {
        logoutDelegate?.didRequestLogout()
    }
}
