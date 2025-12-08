//
//  LogoutDelegate.swift
//  Difft
//
//  Created by henry on 2025/9/26.
//  Copyright © 2025 Difft. All rights reserved.
//

@objc public protocol LogoutDelegate: NSObjectProtocol {
    // 退出登录
    @objc func didRequestLogout()
}
