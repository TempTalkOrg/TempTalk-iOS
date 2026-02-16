//
//  ClusterSpeedTester.swift
//  Difft
//
//  Created by Henry on 2025/7/31.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

struct ClusterMetric {
    let url: URL
    /// 最大响应时间上限 (ms)，超时或错误时使用此值
    static let maxResponseTime: TimeInterval = 99999
    /// 惩罚时间 (ms)
    static let penaltyTime: TimeInterval = 2000
    /// 错误恢复时间 (秒)
    static let recoveryInterval: TimeInterval = 300

    var lastResponseTime: TimeInterval = ClusterMetric.maxResponseTime
    var errorCount: Int = 0
    var errorTime: TimeInterval = 0

    mutating func applyPenalty() {
        // 确保不超过最大值
        lastResponseTime = min(lastResponseTime + Self.penaltyTime, Self.maxResponseTime)
    }

    mutating func resetIfRecovered(currentTime: TimeInterval) {
        if errorCount > 0 && (currentTime - errorTime) > Self.recoveryInterval {
            errorCount = 0
        }
    }

    /// 格式化响应时间用于显示
    var formattedResponseTime: String {
        if lastResponseTime >= Self.maxResponseTime {
            return "timeout"
        }
        return String(format: "%.2f", lastResponseTime)
    }
}

class ClusterSpeedTester {
    private var metrics: [ClusterMetric] = []
    private let lock = NSLock()
    private let session: URLSession
    private var timerTask: Task<Void, Never>?
    private let interval: TimeInterval = 1800

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15.0
        configuration.timeoutIntervalForResource = 15.0
        self.session = URLSession(configuration: configuration)
    }

    deinit {
        stop()
        session.invalidateAndCancel()
    }

    /// 获取按响应时间排序的服务器URL列表
    var sortedUrls: [String] {
        lock.withLock {
            metrics.sorted { $0.lastResponseTime < $1.lastResponseTime }
                .compactMap { $0.url.absoluteString }
        }
    }

    /// 获取排序后的可用集群
    func sortedAvailableClusters() -> [ClusterMetric] {
        lock.withLock {
            metrics.sorted { $0.lastResponseTime < $1.lastResponseTime }
        }
    }

    /// 开始测速循环
    func start() {
        stop()
        timerTask = Task.detached { [weak self] in
            guard let self else { return }
            await self.performSpeedTest()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(self.interval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self.performSpeedTest()
            }
        }
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func performSpeedTest() async {
        let clusters = await fetchClusters()
        guard !clusters.isEmpty else {
            Logger.error("[SpeedTest] No clusters returned from server")
            return
        }

        let results = await testAllClusters(clusters)

        lock.withLock {
            metrics = results
        }

        // 打印测速结果
        for metric in results.sorted(by: { $0.lastResponseTime < $1.lastResponseTime }) {
            Logger.info("[SpeedTest] url=\(metric.url.absoluteString), time=\(metric.formattedResponseTime) ms")
        }
    }

    private func fetchClusters() async -> [ClusterMetric] {
        await withCheckedContinuation { continuation in
            // ✅ Fix: Keep strong reference to prevent premature deallocation
            let api = LiveKitServersApi()
            api.liveKitServers { entity in
                if let servers = entity?.data["serviceUrls"] as? [String],
                   DTParamsUtils.validateArray(servers).boolValue {
                    let metrics = servers.compactMap { server -> ClusterMetric? in
                        let trimmed = server.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
                        return ClusterMetric(url: url)
                    }
                    continuation.resume(returning: metrics)
                } else {
                    Logger.error("[SpeedTest] entity data nil")
                    continuation.resume(returning: [])
                }
            } failure: { error, _ in
                Logger.error("[SpeedTest] livekit request error: \(error.localizedDescription)")
                continuation.resume(returning: [])
            }
        }
    }

    private func testAllClusters(_ clusters: [ClusterMetric]) async -> [ClusterMetric] {
        await withTaskGroup(of: ClusterMetric.self) { group in
            for cluster in clusters {
                group.addTask {
                    await self.testSingleCluster(cluster)
                }
            }

            var results: [ClusterMetric] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }

    private func testSingleCluster(_ metric: ClusterMetric) async -> ClusterMetric {
        var mutableMetric = metric
        let currentTime = Date().timeIntervalSince1970
        mutableMetric.resetIfRecovered(currentTime: currentTime)

        var request = URLRequest(url: metric.url)
        request.httpMethod = "GET"
        request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        request.setValue(TSConstants.appUserAgent, forHTTPHeaderField: "User-Agent")

        let start = Date()

        do {
            let (_, response) = try await session.data(for: request)
            let elapsed = Date().timeIntervalSince(start)

            if response is HTTPURLResponse {
                mutableMetric.lastResponseTime = elapsed * 1000
            } else {
                mutableMetric.applyPenalty()
                mutableMetric.errorCount += 1
                mutableMetric.errorTime = currentTime
            }
        } catch {
            mutableMetric.applyPenalty()
            mutableMetric.errorCount += 1
            mutableMetric.errorTime = currentTime
        }

        return mutableMetric
    }
}
