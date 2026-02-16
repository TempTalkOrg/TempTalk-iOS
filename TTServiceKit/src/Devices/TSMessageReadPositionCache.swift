//
//  TSMessageReadPositionCache.swift
//  TTServiceKit
//
//  Created by Kris on 2026/01/20.
//

import Foundation

/// 管理 TSMessageReadPosition 的内存缓存，用于优化查询性能和支持基于基准时间的合并逻辑
@objc
public class TSMessageReadPositionCache: NSObject {

    @objc
    public static let shared = TSMessageReadPositionCache()

    private var cache: [String: Any] = [:]
    private let queue = DispatchQueue(label: "org.dt.readposition.cache", qos: .userInitiated)

    private override init() {
        super.init()
    }

    /// 生成缓存 key
    private func cacheKey(threadId: String, recipientId: String) -> String {
        return "\(threadId)_\(recipientId)"
    }

    /// 从缓存中获取指定会话和接收者的最新 readPosition
    /// - Parameters:
    ///   - threadId: 会话 ID
    ///   - recipientId: 接收者 ID
    /// - Returns: 缓存的 readPosition，如果没有则返回 nil
    @objc
    public func getCachedPosition(threadId: String, recipientId: String) -> Any? {
        return queue.sync {
            let key = cacheKey(threadId: threadId, recipientId: recipientId)
            return cache[key]
        }
    }

    /// 更新缓存中的 readPosition（同步更新，确保原子性）
    /// - Parameter position: 要缓存的 readPosition
    @objc
    public func updateCache(with position: TSMessageReadPosition) {
        queue.sync {
            let key = cacheKey(threadId: position.uniqueThreadId, recipientId: position.recipientId)
            cache[key] = position
        }
    }

    /// 从缓存中移除指定的 readPosition（例如删除后）
    /// - Parameters:
    ///   - threadId: 会话 ID
    ///   - recipientId: 接收者 ID
    @objc
    public func removeCachedPosition(threadId: String, recipientId: String) {
        queue.sync {
            let key = cacheKey(threadId: threadId, recipientId: recipientId)
            cache.removeValue(forKey: key)
        }
    }

    /// 清空所有缓存（应用登出时）
    @objc
    public func clearAllCache() {
        queue.sync {
            cache.removeAll()
            OWSLogger.info("TSMessageReadPositionCache: cleared all cache")
        }
    }

    /// 获取当前缓存的条目数量（仅用于调试）
    @objc
    public var cachedCount: Int {
        return queue.sync {
            return cache.count
        }
    }

    /// 处理 readPosition 的插入或更新逻辑，支持基于基准时间的合并
    /// - Parameters:
    ///   - newPosition: 新的 readPosition
    ///   - timeThresholdMillis: 时间阈值（毫秒），在此阈值内的消息会合并到同一个 readPosition
    ///   - transaction: 写事务
    @objc
    public func processReadPosition(
        newPosition: TSMessageReadPosition,
        timeThresholdMillis: UInt64,
        transaction: SDSAnyWriteTransaction
    ) {
        let threadId = newPosition.uniqueThreadId
        let recipientId = newPosition.recipientId

        assert(recipientId == TSAccountManager.shared.localNumber(with: transaction),
               "processReadPosition should only be called for local user")

        // 1. 尝试从缓存获取现有 position
        var existingPosition = getCachedPosition(threadId: threadId, recipientId: recipientId) as? TSMessageReadPosition

        // 2. 如果缓存没有，从数据库查询并缓存
        if existingPosition == nil {
            let finder = AnyMessageReadPositonFinder()
            existingPosition = finder.latestRecipientReadPosition(uniqueThreadId: threadId, transaction: transaction)
            if let position = existingPosition {
                updateCache(with: position)
            }
        }

        // 3. 如果没有现有记录，直接插入
        guard let existing = existingPosition else {
            newPosition.anyInsert(transaction: transaction)
            updateCache(with: newPosition)
            return
        }

        // 4. 比较基准时间（readAt）
        let anchorReadAt = existing.readAt
        let currentReadAt = newPosition.readAt
        let timeDiff = currentReadAt > anchorReadAt ?
                      currentReadAt - anchorReadAt :
                      anchorReadAt - currentReadAt

        // 5. 根据时间差决定插入或更新
        if timeDiff >= timeThresholdMillis {
            // 超过阈值，插入新记录
            newPosition.anyInsert(transaction: transaction)
            updateCache(with: newPosition)
        } else {
            // 在阈值内，检查是否需要更新
            // 只有当新消息的 maxServerTime 更大时才更新（避免已读位置倒退）
            if newPosition.maxServerTime > existing.maxServerTime {
                existing.anyUpdate(transaction: transaction) { instance in
                    instance.maxServerTime = newPosition.maxServerTime
                    instance.maxNotifySequenceId = newPosition.maxNotifySequenceId
                    instance.creationTimestamp = newPosition.creationTimestamp
                    instance.updateCount = existing.updateCount + 1
                }
                updateCache(with: existing)
            }
        }
    }
}

