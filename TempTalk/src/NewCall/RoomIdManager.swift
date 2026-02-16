//
//  RoomIdManager.swift
//  TempTalk
//
//  Created by henry on 2026/02/02.
//  Copyright © 2026 Difft. All rights reserved.
//

import Foundation

/// 活跃会议信息
struct ActiveCallInfo: Codable {
    let roomId: String
    let deviceIdentifier: String
    let timestamp: UInt64
    let callType: String
    let conversationId: String?
}

/// RoomId 统一管理器
class RoomIdManager {
    static let shared = RoomIdManager()

    private let lock = NSLock()
    private let deviceId: String = {
        #if os(iOS)
        return UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        #else
        return UUID().uuidString
        #endif
    }()
    private let userDefaultsKey = "OWSPreferencesKeyActiveCalls"

    private init() {}

    // MARK: - 保存 RoomId

    /// 保存 roomId（原子操作）
    /// 调用时机：连接成功后（dealConnetedSuccess）
    func saveRoomId(_ roomId: String,
                    callType: CallType,
                    conversationId: String?,
                    timestamp: UInt64) {
        lock.withLock {
            var activeCalls = loadActiveCalls()

            let callInfo = ActiveCallInfo(
                roomId: roomId,
                deviceIdentifier: deviceId,
                timestamp: timestamp,
                callType: callType.rawValue,
                conversationId: conversationId
            )

            activeCalls[roomId] = callInfo
            saveActiveCalls(activeCalls)
        }
    }

    // MARK: - 查询 RoomId

    /// 检查 roomId 是否属于当前设备
    func isCurrentDeviceCall(_ roomId: String) -> Bool {
        lock.withLock {
            let activeCalls = loadActiveCalls()
            guard let callInfo = activeCalls[roomId] else {
                return false
            }
            return callInfo.deviceIdentifier == deviceId
        }
    }

    /// 获取所有活跃的 roomId
    func getAllActiveRoomIds() -> [String] {
        lock.withLock {
            return Array(loadActiveCalls().keys)
        }
    }

    /// 获取当前设备的 roomId（最新的一个）
    func getCurrentDeviceRoomId() -> String? {
        lock.withLock {
            let activeCalls = loadActiveCalls()
            return activeCalls.values
                .filter { $0.deviceIdentifier == deviceId }
                .sorted { $0.timestamp > $1.timestamp }
                .first?.roomId
        }
    }

    // MARK: - 清理 RoomId

    /// 清理指定的 roomId
    /// 调用时机：挂断时（clearCallState）
    func removeRoomId(_ roomId: String) {
        lock.withLock {
            var activeCalls = loadActiveCalls()
            activeCalls.removeValue(forKey: roomId)
            saveActiveCalls(activeCalls)
        }
    }

    /// 清理所有 roomId
    /// 调用时机：removeAllMeetingBars
    func removeAllRoomIds(except preserveRoomId: String? = nil) {
        lock.withLock {
            var activeCalls = loadActiveCalls()

            if let preserveRoomId = preserveRoomId {
                activeCalls = activeCalls.filter { $0.key == preserveRoomId }
            } else {
                activeCalls.removeAll()
            }

            saveActiveCalls(activeCalls)
        }
    }

    // MARK: - 私有方法

    private func loadActiveCalls() -> [String: ActiveCallInfo] {
        // Use file coordinator for inter-process synchronization
        let fileURL = getSharedFileURL()
        var result: [String: ActiveCallInfo] = [:]

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var error: NSError?

        coordinator.coordinate(readingItemAt: fileURL, options: .withoutChanges, error: &error) { url in
            guard let data = try? Data(contentsOf: url),
                  let calls = try? JSONDecoder().decode([String: ActiveCallInfo].self, from: data) else {
                // Fallback to UserDefaults for backward compatibility
                if let legacyData = UserDefaults.app().data(forKey: userDefaultsKey),
                   let legacyCalls = try? JSONDecoder().decode([String: ActiveCallInfo].self, from: legacyData) {
                    result = legacyCalls
                }
                return
            }
            result = calls
        }

        // Check and log file coordination errors
        if let error = error {
            Logger.error("[RoomIdManager] File coordination error during read: \(error.localizedDescription)")
        }

        return result
    }

    private func saveActiveCalls(_ calls: [String: ActiveCallInfo]) {
        // Use file coordinator for inter-process synchronization
        let fileURL = getSharedFileURL()

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var error: NSError?

        coordinator.coordinate(writingItemAt: fileURL, options: .forReplacing, error: &error) { url in
            if let data = try? JSONEncoder().encode(calls) {
                try? data.write(to: url, options: .atomic)

                // Also update UserDefaults for backward compatibility
                UserDefaults.app().set(data, forKey: userDefaultsKey)
                UserDefaults.app().synchronize()
            }
        }

        // Check and log file coordination errors
        if let error = error {
            Logger.error("[RoomIdManager] File coordination error during write: \(error.localizedDescription)")
        }
    }

    private func getSharedFileURL() -> URL {
        guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: TSConstants.applicationGroup) else {
            Logger.error("[RoomIdManager] Unable to access shared container, falling back to app documents directory")
            guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                fatalError("[RoomIdManager] Unable to access documents directory - critical system error")
            }
            return documentsURL.appendingPathComponent("active_calls.json")
        }
        return containerURL.appendingPathComponent("active_calls.json")
    }
}
