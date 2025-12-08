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
    // 使用字典存储提供 O(1) 查找性能
    private var _metricsDict: [URL: ClusterMetric] = [:]
    private let metricsQueue = DispatchQueue(label: "com.difft.clusterspeedtester.metrics", attributes: .concurrent)
    private let interval: TimeInterval = 300
    private let session: URLSession
    private let queue = DispatchQueue(label: "com.difft.clusterspeedtester")
    
    private var _sortedUrls: [String] = []
    // sortedUrlsQueue 为串行队列，无需 barrier 标志
    private let sortedUrlsQueue = DispatchQueue(label: "com.difft.clusterspeedtester.sortedUrls")
    
    private var timerTask: Task<Void, Never>?
    
    private var metricsDict: [URL: ClusterMetric] {
        get {
            metricsQueue.sync { _metricsDict }
        }
        set {
            metricsQueue.sync(flags: .barrier) {
                _metricsDict = newValue
            }
        }
    }

    init() {
        self.session = URLSession(configuration: .ephemeral)
    }
    
    deinit {
        stop()
        session.invalidateAndCancel()
    }

    var sortedUrls: [String] {
        sortedUrlsQueue.sync { _sortedUrls }
    }

    private func setSortedUrls(_ urls: [String]) {
        sortedUrlsQueue.sync { _sortedUrls = urls }
    }

    /// 开始测速循环
    func start() {
        stop() // 停掉已有任务
        timerTask = Task.detached { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                // performSpeedTest 不涉及 UI，无需在 MainActor 执行
                self.performSpeedTest()
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
    
    /// 线程安全地更新指定URL的metric (O(1) 字典操作)
    private func updateMetric(for url: URL, with metric: ClusterMetric, completion: (() -> Void)? = nil) {
        metricsQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { 
                completion?()
                return 
            }
            self._metricsDict[url] = metric
            completion?()
        }
    }

    private func performSpeedTest() {
        let source = MeetingClusterSource()
        source.fetchClusters { [weak self] clusters in
            guard let self = self else { return }
            self.queue.async {
                // 将数组转换为字典，处理重复 URL（保留第一个）
                let dict = Dictionary(clusters.map { ($0.url, $0) }, uniquingKeysWith: { first, _ in first })
                self.metricsDict = dict
                self.testClusters()
            }
        }
    }

    private func testClusters() {
        let innerGroup = DispatchGroup()
        let currentTime = Date().timeIntervalSince1970

        // 获取当前metrics的副本，避免在测试过程中被修改
        let currentMetrics = metricsDict.values
        
        // 确保metrics不为空
        guard !currentMetrics.isEmpty else {
            Logger.warn("[SpeedTest] No metrics to test")
            return
        }

        for metric in currentMetrics {
            innerGroup.enter()
            var mutableMetric = metric
            mutableMetric.resetIfRecovered(currentTime: currentTime)

            var request = URLRequest(url: mutableMetric.url)
            request.httpMethod = "HEAD"
            let start = Date()

            let task = session.dataTask(with: request) { [weak self] _, response, error in
                guard let self = self else {
                    // 如果 self 已释放，直接调用 leave 避免死锁
                    innerGroup.leave()
                    return
                }
                
                let elapsed = Date().timeIntervalSince(start)

                if error == nil, let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) {
                    mutableMetric.lastResponseTime = elapsed * 1000
                    mutableMetric.lastTestTime = Date().timeIntervalSince1970
                } else {
                    mutableMetric.errorCount += 1
                    mutableMetric.errorTime = Date().timeIntervalSince1970
                }

                // 使用URL而非索引更新，避免竞态条件
                // 在更新完成后才调用 leave，确保所有更新都完成后才触发 notify
                self.updateMetric(for: mutableMetric.url, with: mutableMetric) {
                    innerGroup.leave()
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
        let currentMetrics = metricsDict.values
        return currentMetrics.filter(\.isAvailable).sorted { $0.lastResponseTime < $1.lastResponseTime }
    }
}
