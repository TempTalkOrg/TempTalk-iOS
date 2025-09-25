//
//  TranslateManager.swift
//  Pods
//
//  Created by Henry on 2025/3/8.
//

@objc
public class DatabaseOfflineManager: NSObject {
    @objc static public let shared = DatabaseOfflineManager()
    @objc public var canOfflineUpdateDatabase = false
}
