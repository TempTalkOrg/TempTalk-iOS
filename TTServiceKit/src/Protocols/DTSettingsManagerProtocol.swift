//
//  DTSettingsManagerProtocol.swift
//  Pods
//
//  Created by Henry on 2025/6/15.
//

import Foundation

@objc public protocol DTSettingsManagerProtocol: NSObjectProtocol {
    // 同步profile消息
    @objc func syncRemoteProfileInfo()
    // 处理threads数据
    @objc func deleteResetIdentityKeyThreads(operatorId: String, resetIdentityKeyTime: UInt64)
}
