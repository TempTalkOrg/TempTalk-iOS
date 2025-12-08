//
//  NotificationCleanupManager.swift
//  TTServiceKit
//
//  Created by Assistant on 2025/1/27.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import UserNotifications

@objc
public class NotificationCleanupManager: NSObject {
    
    // MARK: - Constants
    private static let notificationCleanupKey = "NotificationCleanupDone"
    private static let cleanupRequestKey = "NotificationCleanupRequest"
    
    // Darwin Notification Names
    private static let cleanupRequestNotification = DarwinNotificationName("org.difft.notificationCleanupRequest")
    private static let cleanupCompletedNotification = DarwinNotificationName("org.difft.notificationCleanupCompleted")
    
    // 旧 App 名称（用于清理老通知）
    private static let oldAppName = "TempTalk"
    
    // Shared instance
    @objc public static let shared = NotificationCleanupManager()
    
    private override init() {
        super.init()
        setupDarwinNotifications()
    }
    
    // MARK: - Public Methods
    @objc public func shouldPerformNotificationCleanup() -> Bool {
        let userDefaults = CurrentAppContext().appUserDefaults()
        let currentVersion = AppVersion.shared().currentAppReleaseVersion
        let cleanupDone = userDefaults.bool(forKey: Self.notificationCleanupKey)
        let targetVersion = "3.5.3"
        
        let result = currentVersion.compare(targetVersion, options: .numeric)
        return (result == .orderedDescending || result == .orderedSame) && !cleanupDone
    }
    
    @objc public func performNotificationCleanup() {
        Logger.info("Main app performing notification cleanup")
        
        let group = DispatchGroup()
        
        // 清理待处理通知
        group.enter()
        UNUserNotificationCenter.current().getPendingNotificationRequests { [weak self] pendingRequests in
            self?.cleanupNotifications(from: pendingRequests, type: "pending")
            group.leave()
        }
        
        // 清理已发送通知
        group.enter()
        UNUserNotificationCenter.current().getDeliveredNotifications { [weak self] deliveredNotifications in
            let requests = deliveredNotifications.map { $0.request }
            self?.cleanupNotifications(from: requests, type: "delivered")
            group.leave()
        }
        
        // 清理完成后通知
        group.notify(queue: .main) { [weak self] in
            DarwinNotificationCenter.post(Self.cleanupCompletedNotification)
            self?.markCleanupAsCompleted()
            Logger.info("Notification cleanup fully completed")
        }
    }
    
    @objc public func requestNotificationCleanup() {
        Logger.info("Extension requesting notification cleanup from main app")
        DarwinNotificationCenter.post(Self.cleanupRequestNotification)
    }
    
    // MARK: - Private Methods
    private func setupDarwinNotifications() {
        DarwinNotificationCenter.addObserver(for: Self.cleanupRequestNotification, queue: .main) { [weak self] _ in
            self?.handleCleanupRequest()
        }
    }
    
    private func handleCleanupRequest() {
        Logger.info("Main app received cleanup request from extension")
        performNotificationCleanup()
    }
    
    private func cleanupNotifications(from requests: [UNNotificationRequest], type: String) {
        var identifiersToRemove: [String] = []
        
        for request in requests {
            if shouldCleanupNotification(request: request) {
                identifiersToRemove.append(request.identifier)
            }
        }
        
        guard !identifiersToRemove.isEmpty else {
            Logger.info("No \(type) notifications to remove")
            return
        }
        
        if type == "pending" {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        } else {
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiersToRemove)
        }
        
        Logger.info("Removed \(identifiersToRemove.count) \(type) notifications")
    }
    
    private func shouldCleanupNotification(request: UNNotificationRequest) -> Bool {
        let content = request.content
        let userInfo = content.userInfo
        
        let oldAppName = Self.oldAppName
        if content.title.range(of: oldAppName, options: .caseInsensitive) != nil ||
           content.body.range(of: oldAppName, options: .caseInsensitive) != nil {
            return true
        }
        
        if let timestamp = userInfo["timestamp"] as? Double {
            let notificationTime = Date(timeIntervalSince1970: timestamp)
            let hoursSinceNotification = Date().timeIntervalSince(notificationTime) / 3600
            if hoursSinceNotification > 24 {
                return true
            }
        }
        
        return false
    }
    
    private func markCleanupAsCompleted() {
        let userDefaults = CurrentAppContext().appUserDefaults()
        userDefaults.set(true, forKey: Self.notificationCleanupKey)
        userDefaults.synchronize()
        
        Logger.info("Notification cleanup marked as completed")
    }
}
