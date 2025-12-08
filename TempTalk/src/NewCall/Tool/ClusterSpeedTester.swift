//
//  ClusterSpeedTester.swift
//  Difft
//
//  Created by Henry on 2025/7/31.
//  Copyright © 2025 Difft. All rights reserved.
//

struct ClusterMetric {
    let url: URL
    var lastResponseTime: TimeInterval = .greatestFiniteMagnitude
    var lastTestTime: TimeInterval = 0
    var errorCount: Int = 0
    var errorTime: TimeInterval = 0

    var isAvailable: Bool {
        errorCount < 3
    }

    mutating func resetIfRecovered(currentTime: TimeInterval) {
        if errorCount != 0 && (currentTime - errorTime) > 300 {
            errorCount = 0
        }
    }
}

protocol ClusterSource {
    func fetchClusters(completion: @escaping ([ClusterMetric]) -> Void)
}

class MeetingClusterSource: ClusterSource {
    func fetchClusters(completion: @escaping ([ClusterMetric]) -> Void) {
        var result: [ClusterMetric] = []
        LiveKitServersApi().liveKitServers { entity in
            if let servers = entity?.data["serviceUrls"] as? [String],
               DTParamsUtils.validateArray(servers).boolValue {
                for server in servers {
                    // 确保server字符串有效且不为空
                    let trimmedServer = server.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedServer.isEmpty, let url = URL(string: trimmedServer) {
                        result.append(ClusterMetric(url: url))
                    }
                }
                completion(result)
            } else {
                Logger.error("[SpeedTest] entity data nil")
            }
        } failure: { error, _ in
            // 安全地获取错误描述
            let errorDescription = error.localizedDescription
            Logger.error("[SpeedTest] livekit request error: \(errorDescription)")
        }
    }
}

class ClusterSpeedTester {
    private(set) var metrics: [ClusterMetric] = []
    private let interval: TimeInterval = 300
    private let session: URLSession
    private let queue = DispatchQueue(label: "com.difft.clusterspeedtester")
    
    private var _sortedUrls: [String] = []
    private let sortedUrlsQueue = DispatchQueue(label: "com.difft.clusterspeedtester.sortedUrls")
    
    private var timerTask: Task<Void, Never>?

    init() {
        self.session = URLSession(configuration: .ephemeral)
    }

    var sortedUrls: [String] {
        sortedUrlsQueue.sync { _sortedUrls }
    }

    private func setSortedUrls(_ urls: [String]) {
        sortedUrlsQueue.sync { _sortedUrls = urls }
    }
    
//    deinit {
//        stop()
//    }

    /// 开始测速循环
    func start() {
        stop() // 停掉已有任务
        timerTask = Task.detached { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await MainActor.run {
                    self.performSpeedTest()
                }
                try? await Task.sleep(nanoseconds: UInt64(self.interval * 1_000_000_000))
            }
        }
        // 立即执行一次
        performSpeedTest()
    }

    func stop() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func performSpeedTest() {
        let source = MeetingClusterSource()
        source.fetchClusters { clusters in
            self.queue.async {
                self.metrics = clusters
                self.testClusters()
            }
        }
    }

    private func testClusters() {
        let innerGroup = DispatchGroup()
        let currentTime = Date().timeIntervalSince1970

        // 确保metrics数组不为空
        guard !metrics.isEmpty else {
            Logger.warn("[SpeedTest] No metrics to test")
            return
        }

        for i in metrics.indices {
            innerGroup.enter()
            var metric = metrics[i]
            metric.resetIfRecovered(currentTime: currentTime)

            var request = URLRequest(url: metric.url)
            request.httpMethod = "HEAD"
            let start = Date()

            let task = session.dataTask(with: request) { [weak self] _, response, error in
                defer { innerGroup.leave() }
                let elapsed = Date().timeIntervalSince(start)

                if error == nil, let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) {
                    metric.lastResponseTime = elapsed * 1000
                    metric.lastTestTime = Date().timeIntervalSince1970
                } else {
                    metric.errorCount += 1
                    metric.errorTime = Date().timeIntervalSince1970
                }

                self?.queue.async {
                    // 确保索引仍然有效
                    if i < self?.metrics.count ?? 0 {
                        self?.metrics[i] = metric
                    }
                }
            }
            task.resume()
        }

        innerGroup.notify(queue: .main) {
            let available = self.sortedAvailableClusters()
            for metric in available {
                // 安全地获取URL字符串，避免崩溃
                let urlString = metric.url.absoluteString
                let ms = String(format: "%.2f", metric.lastResponseTime)
                
                // 使用更安全的日志记录方式
                if !urlString.isEmpty {
                    Logger.info("[SpeedTest] url=\(urlString), time=\(ms) ms")
                } else {
                    Logger.info("[SpeedTest] url=invalid, time=\(ms) ms")
                }
            }
            
            // 安全地映射URL字符串
            let urlStrings = available.compactMap { metric -> String? in
                let urlString = metric.url.absoluteString
                return urlString.isEmpty ? nil : urlString
            }
            self.setSortedUrls(urlStrings)
        }
    }

    func sortedAvailableClusters() -> [ClusterMetric] {
        metrics.filter(\.isAvailable).sorted { $0.lastResponseTime < $1.lastResponseTime }
    }
}
