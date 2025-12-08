//
//  TTCallServiceUrlManager.swift
//  TempTalk
//
//  Created by Kris.s on 2025/3/13.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

public class TTCallServiceUrlManager {
    private let queue = DispatchQueue(label: "TTCallServiceUrlManager.queue")
    private var _currentIndex: Int = 0
    private var currentIndex: Int {
        get { queue.sync { _currentIndex } }
        set { queue.sync { _currentIndex = newValue } }
    }
    
    private var allUrls: [String] {
        return DTMeetingManager.shared.clusterSpeedTester.sortedUrls
    }

    /// 当前正在使用的 URL
    func getCurrentUrl() async -> String? {
        if DTParamsUtils.validateArray(allUrls).boolValue, currentIndex < allUrls.count {
            Logger.info("[new call] currentUrl from allUrls = \(allUrls[currentIndex])")
            return allUrls[currentIndex]
        }

        // fallback：调用接口
        do {
            let servers = try await fetchLiveKitServers()
            if DTParamsUtils.validateArray(servers).boolValue {
                Logger.info("[new call] currentUrl from servers = \(servers.first ?? "nil")")
                return servers.first
            } else {
                Logger.error("[new call] livekit servcers nil")
            }
        } catch {
            Logger.error("[new call] livekit servcers exception")
        }
        return nil
    }

    /// 把回调封装成 async
    private func fetchLiveKitServers() async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            LiveKitServersApi().liveKitServers { entity in
                if let servers = entity?.data["serviceUrls"] as? [String] {
                    continuation.resume(returning: servers)
                } else {
                    continuation.resume(returning: [])
                }
            } failure: { error, _ in
                continuation.resume(throwing: error)
            }
        }
    }

    /// 是否还有下一地址可尝试
    var hasNext: Bool {
        return currentIndex < allUrls.count - 1
    }

    /// 切换到下一个地址（失败时调用）
    @discardableResult
    func switchToNextUrl() -> Bool {
        guard hasNext else { return false }
        currentIndex += 1
        Logger.info("\(DTMeetingManager.shared.logTag) room switch next index \(currentIndex)")
        return true
    }

    /// 重置为第一个地址（可选）
    func reset() {
        currentIndex = 0
    }
}
