//
//  Untitled.swift
//  Difft
//
//  Created by Henry on 2025/7/31.
//  Copyright © 2025 Difft. All rights reserved.
//

struct ClusterMetric {
    let clusterId: String
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

class ClusterSpeedTester {
    private(set) var metrics: [ClusterMetric] = []
    private var timer: Timer?
    // 5分钟触发一次
    private let interval: TimeInterval = 300
    private let session = URLSession(configuration: .ephemeral)
    private let queue = DispatchQueue(label: "com.difft.clusterspeedtester")

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.performSpeedTest()
        }
        performSpeedTest()
    }

    private func performSpeedTest() {
        // 主服务测速
        TSConstants.refreshDomainSpeeds()
        // 会议测速
        DTMeetingManager.shared.fetchClustersConfig { clusters in
            var result: [ClusterMetric] = []
            for dict in clusters {
                guard let id = dict["id"],
                      let globalStr = dict["global_url"],
                      let mainlandStr = dict["mainland_url"],
                      let globalURL = URL(string: globalStr),
                      let mainlandURL = URL(string: mainlandStr) else {
                    continue
                }
                result.append(ClusterMetric(clusterId: id, url: globalURL))
                result.append(ClusterMetric(clusterId: id, url: mainlandURL))
            }
            self.metrics = result
            
            let currentTime = Date().timeIntervalSince1970
            for i in self.metrics.indices {
                var metric = self.metrics[i]
                metric.resetIfRecovered(currentTime: currentTime)

                var request = URLRequest(url: metric.url)
                request.httpMethod = "HEAD"
                let start = Date()
                let task = self.session.dataTask(with: request) { [weak self] _, response, error in
                    let elapsed = Date().timeIntervalSince(start)
                    if error == nil, let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) {
                        metric.lastResponseTime = elapsed * 1000
                        metric.lastTestTime = Date().timeIntervalSince1970
                        Logger.info("[Speed Test] \(metric.url.absoluteString) responseTime: \(metric.lastResponseTime) ms")
                    } else {
                        metric.errorCount += 1
                        metric.errorTime = Date().timeIntervalSince1970
                        Logger.info("[Speed Test] \(metric.url.absoluteString)  errorCount=\(metric.errorCount)")
                    }
                    self?.queue.async {
                        self?.metrics[i] = metric
                    }
                }
                task.resume()
            }
        }  
    }

    func sortedAvailableClusters() -> [ClusterMetric] {
        metrics.filter(\.isAvailable).sorted {
            $0.lastResponseTime < $1.lastResponseTime
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
