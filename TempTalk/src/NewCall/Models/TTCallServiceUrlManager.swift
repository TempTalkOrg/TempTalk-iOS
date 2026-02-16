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

    /// 获取 URL 列表的快照，避免多次访问时数据不一致
    private func getAllUrls() -> [String] {
        return DTMeetingManager.shared.clusterSpeedTester.sortedUrls
    }

    /// 当前正在使用的 URL
    func getCurrentUrl() async -> String? {
        // 获取快照，避免多次访问时数据变化
        let urls = getAllUrls()
        let index = currentIndex

        if DTParamsUtils.validateArray(urls).boolValue, index < urls.count {
            Logger.info("[new call] currentUrl from allUrls = \(urls[index])")
            return urls[index]
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
            // ✅ Fix: Keep strong reference to prevent premature deallocation
            let api = LiveKitServersApi()
            api.liveKitServers { entity in
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
        let urls = getAllUrls()
        return currentIndex < urls.count - 1
    }

    /// 切换到下一个地址（失败时调用）
    @discardableResult
    func switchToNextUrl() -> Bool {
        let urls = getAllUrls()
        let index = currentIndex
        guard index < urls.count - 1 else { return false }
        currentIndex = index + 1
        Logger.info("\(DTMeetingManager.shared.logTag) room switch next index \(currentIndex)")
        return true
    }

    /// 重置为第一个地址（可选）
    func reset() {
        currentIndex = 0
    }
}
