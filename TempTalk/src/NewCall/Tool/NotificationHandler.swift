//
//  NotificationHandler.swift
//  Difft
//
//  Created by Henry on 2025/5/20.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

/// Handles Darwin notifications from NSE for background call termination
@objc class NotificationHandler: NSObject {
    @objc static let shared = NotificationHandler()

    private static let notificationName = "com.temptalk.nseCallkitStop" as CFString
    private var isRegistered = false

    /// Registers Darwin notification observer
    /// CRITICAL: Must be called early in app lifecycle to handle locked/background state
    /// Safe to call multiple times - will only register once
    @objc func registerDarwinNotification() {
        // Prevent duplicate registration
        guard !isRegistered else {
            Logger.info("[call][darwin] Already registered, skipping")
            return
        }

        let center = CFNotificationCenterGetDarwinNotifyCenter()

        CFNotificationCenterAddObserver(center,
                                        Unmanaged.passUnretained(self).toOpaque(),
                                        darwinCallback,
                                        Self.notificationName,
                                        nil,
                                        .deliverImmediately)

        isRegistered = true
        Logger.info("[call][darwin] Notification observer registered successfully")
    }

    /// Unregisters Darwin notification observer on deallocation
    deinit {
        guard isRegistered else { return }

        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterRemoveObserver(center,
                                          Unmanaged.passUnretained(self).toOpaque(),
                                          CFNotificationName(Self.notificationName),
                                          nil)
        Logger.info("[call][darwin] Notification observer unregistered")
    }

    /// Handles Darwin notification for call termination from NSE
    /// This is critical for background/locked state where WebSocket may be disconnected
    func handleDarwinNotification(name: CFString?) {
        // Validate notification name
        guard let notificationName = name,
              CFStringCompare(notificationName, Self.notificationName, []) == .compareEqualTo else {
            return
        }

        // Read target roomId from UserDefaults (set by NSE)
        guard let targetRoomId = UserDefaults.app().string(forKey: OWSPreferencesKeySystemEndCallKey) else {
            return
        }

        // Check if roomId is in active list
        let allActiveRoomIds = RoomIdManager.shared.getAllActiveRoomIds()

        if allActiveRoomIds.contains(targetRoomId) {
            // Normal case: call is still active, do full cleanup
            Task {
                await DTMeetingManager.shared.othersideHungupCall(roomId: targetRoomId)
            }
        } else {
            // State already cleared, but CallKit might still be showing
            // Since there's only one CallKit, end it using callerMap
            let callKitManager = DTCallKitManager.shared()
            DispatchQueue.main.async {
                if let firstCaller = (callKitManager.callerMap.allKeys as? [String])?.first {
                    callKitManager.endCallAction(firstCaller, onlyForCallKit: true)
                }
            }
        }

        // Always clean UserDefaults
        cleanupUserDefaults()
    }

    private func cleanupUserDefaults() {
        UserDefaults.app().removeObject(forKey: OWSPreferencesKeySystemEndCallKey)
        UserDefaults.app().synchronize()
    }
}

// MARK: - C Callback Bridge
// Must be a top-level function (not instance property) because CFNotificationCallback
// requires a stable C function pointer that persists independently of instance lifecycle
private func darwinCallback(_ center: CFNotificationCenter?,
                            _ observer: UnsafeMutableRawPointer?,
                            _ name: CFNotificationName?,
                            _ object: UnsafeRawPointer?,
                            _ userInfo: CFDictionary?) {
    guard let observer = observer else {
        Logger.error("[call][darwin] Observer pointer is nil, cannot handle notification")
        return
    }

    let instance = Unmanaged<NotificationHandler>.fromOpaque(observer).takeUnretainedValue()
    instance.handleDarwinNotification(name: name?.rawValue)
}

