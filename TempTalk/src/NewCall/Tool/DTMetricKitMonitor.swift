//
//  DTMetricKitMonitor.swift
//  Difft
//
//  Created by henry on 2025/11/12.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import MetricKit

@available(iOS 14.0, *)
@objcMembers
public final class DTMetricKitMonitor: NSObject {
    
    public static let shared = DTMetricKitMonitor()
    
    private let metricLogTag = "[DTMetricKitMonitor]"
    private let workQueue = DispatchQueue(label: "com.difft.temtalk.metricKitMonitor", qos: .utility)
    private let storeURL: URL
    private var isSubscribed = false
    
    private override init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        storeURL = caches.appendingPathComponent("metricKitEvents.jsonl")
        super.init()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Lifecycle
    
    /// 注册 MetricKit 订阅者，立即消费历史数据
    public func startMonitoring() {
        guard !isSubscribed else {
            Logger.info("\(metricLogTag) Already monitoring.")
            return
        }
        MXMetricManager.shared.add(self)
        isSubscribed = true
        Logger.info("\(metricLogTag) MetricKit monitor registered.")
        
        // 兼容 iOS 14 起的历史数据接口
        let metricPayloads = MXMetricManager.shared.pastPayloads ?? []
        if !metricPayloads.isEmpty {
            Logger.info("\(metricLogTag) Consuming \(metricPayloads.count) historical metric payloads.")
            handleMetricPayloads(metricPayloads, source: "historical")
        }
        
        if #available(iOS 14.0, *) {
            let diagnosticPayloads = MXMetricManager.shared.pastDiagnosticPayloads ?? []
            if !diagnosticPayloads.isEmpty {
                Logger.info("\(metricLogTag) Consuming \(diagnosticPayloads.count) historical diagnostic payloads.")
                handleDiagnosticPayloads(diagnosticPayloads, source: "historical")
            }
        }
    }
    
    /// 移除订阅者
    public func stopMonitoring() {
        guard isSubscribed else { return }
        MXMetricManager.shared.remove(self)
        isSubscribed = false
        Logger.info("\(metricLogTag) MetricKit monitor removed.")
    }
    
    // MARK: - Export
    
    /// 读取持久化的 JSONL 数据
    public func exportPersistedEvents() -> String? {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return nil }
        return try? String(contentsOf: storeURL, encoding: .utf8)
    }
    
    // MARK: - Payload handlers
    
    private func handleMetricPayloads(_ payloads: [MXMetricPayload], source: String) {
        workQueue.async { [weak self] in
            payloads.forEach { self?.handleMetricPayload($0, source: source) }
        }
    }
    
    private func handleDiagnosticPayloads(_ payloads: [MXDiagnosticPayload], source: String) {
        workQueue.async { [weak self] in
            payloads.forEach { self?.handleDiagnosticPayload($0, source: source) }
        }
    }
    
    private func handleMetricPayload(_ payload: MXMetricPayload, source: String) {
        var event: [String: Any] = [
            "type": "metric",
            "source": source,
            "timeRange": [
                "start": ISO8601DateFormatter().string(from: payload.timeStampBegin),
                "end": ISO8601DateFormatter().string(from: payload.timeStampEnd)
            ]
        ]
        
        // 兼容 iOS 14–17+ 命名差异
        let launchMetrics: Any? = {
            if payload.responds(to: Selector(("appLaunchMetrics"))) {
                return payload.value(forKey: "appLaunchMetrics")
            } else if payload.responds(to: Selector(("applicationLaunchMetrics"))) {
                return payload.value(forKey: "applicationLaunchMetrics")
            } else {
                return nil
            }
        }()
        
        if let launchMetric = launchMetrics as? MXAppLaunchMetric {
            var launchInfo: [String: Any] = [
                "timeToFirstDraw": summarizeDurationHistogram(launchMetric.histogrammedTimeToFirstDraw),
                "resumeTime": summarizeDurationHistogram(launchMetric.histogrammedApplicationResumeTime)
            ]
            
            if #available(iOS 15.2, *) {
                let optimized = launchMetric.histogrammedOptimizedTimeToFirstDraw
                launchInfo["optimizedTimeToFirstDraw"] = summarizeDurationHistogram(optimized)
            }
            
            if #available(iOS 16.0, *) {
                let extended = launchMetric.histogrammedExtendedLaunch
                launchInfo["extendedLaunch"] = summarizeDurationHistogram(extended)
            }
            
            event["appLaunchMetric"] = launchInfo
            logLaunchSummary(launchInfo)
        }
        
        persistEvent(event)
    }
    
    private func handleDiagnosticPayload(_ payload: MXDiagnosticPayload, source: String) {
        var event: [String: Any] = [
            "type": "diagnostic",
            "source": source,
            "timeStampBegin": ISO8601DateFormatter().string(from: payload.timeStampBegin),
            "timeStampEnd": ISO8601DateFormatter().string(from: payload.timeStampEnd)
        ]
        
        var watchdogReports: [[String: Any]] = []
        
        // Crash diagnostics
        if let crashDiagnostics = payload.crashDiagnostics {
            let crashEntries = crashDiagnostics.map { crash -> [String: Any] in
                let reason = crash.terminationReason ?? ""
                let isWatchdog = reason.contains("0x8badf00d") || reason.localizedCaseInsensitiveContains("watchdog")
                var crashStacks = ""
                if isWatchdog {
                    let callStackTree = crash.callStackTree
                    crashStacks = String(data: callStackTree.jsonRepresentation(), encoding: .utf8) ?? "watchdog nil"
                    watchdogReports.append([
                        "terminationReason": reason,
                        "applicationVersion": crash.applicationVersion,
                        "signal": crash.signal ?? 0,
                        "exceptionCode": crash.exceptionCode ?? 0,
                        "mainThreadStack": crashStacks
                    ])
                }
                return [
                    "applicationVersion": crash.applicationVersion,
                    "terminationReason": reason,
                    "signal": crash.signal ?? 0,
                    "exceptionCode": crash.exceptionCode ?? 0,
                    "mainThreadStack": crashStacks
                ]
            }
            if !crashEntries.isEmpty {
                event["crashDiagnostics"] = crashEntries
            }
        }
        
//        if isWatchdog {
//            let callStackTree = diagnostic.callStackTree
//            let jsonString = String(data: callStackTree.jsonRepresentation(), encoding: .utf8)
//            watchdogReports.append([
//                "terminationReason": reason,
//                "applicationVersion": diagnostic.applicationVersion,
//                "signal": diagnostic.signal ?? 0,
//                "exceptionCode": diagnostic.exceptionCode ?? 0,
//                "mainThreadStack": jsonString
//            ])
//        }
//        return [
//            "applicationVersion": crash.applicationVersion,
//            "terminationReason": reason,
//            "signal": crash.signal ?? 0,
//            "exceptionCode": crash.exceptionCode ?? 0,
//            "mainThreadStack": jsonString
//        ]
        
        if #available(iOS 17.0, *) {
            if let exitDiagnostics = payload.value(forKey: "backgroundExitDiagnostics") as? [Any] {
                for diag in exitDiagnostics {
                    // 打印或序列化诊断内容（为了兼容，这里不要直接访问属性）
                    Logger.info("Got background exit diagnostic: \(diag)")
                }
            }
        }
        
        // Hang diagnostics
        if let hangDiagnostics = payload.hangDiagnostics {
            let hangEntries = hangDiagnostics.map { hang -> [String: Any] in
                [
                    "applicationVersion": hang.applicationVersion,
                    "hangDurationSeconds": hang.hangDuration.converted(to: UnitDuration.seconds).value
                ]
            }
            if !hangEntries.isEmpty {
                event["hangDiagnostics"] = hangEntries
            }
        }
        
        if !watchdogReports.isEmpty {
            Logger.error("\(metricLogTag) Watchdog detected: \(watchdogReports)")
        }
        
        persistEvent(event)
    }
    
    // MARK: - Helpers
    
    private func logLaunchSummary(_ info: [String: Any]) {
        guard
            let timeToFirstDraw = info["timeToFirstDraw"] as? [String: Any],
            let average = timeToFirstDraw["averageMilliseconds"] as? Double,
            let p90 = timeToFirstDraw["p90Milliseconds"] as? Double,
            let count = timeToFirstDraw["sampleCount"] as? Int
        else { return }
        
        Logger.info("\(metricLogTag) Launch samples: count=\(count), avg=\(String(format: "%.2f", average))ms, p90=\(String(format: "%.2f", p90))ms")
    }
    
    private struct HistogramBucketSummary {
        let startSeconds: Double
        let endSeconds: Double
        let count: Int
    }
    
    private func summarizeDurationHistogram(_ histogram: MXHistogram<UnitDuration>?) -> [String: Any] {
        guard let histogram = histogram else { return ["sampleCount": 0] }
        
        var buckets: [HistogramBucketSummary] = []
        var totalCount = 0
        
        let enumerator = histogram.bucketEnumerator
        while let bucket = enumerator.nextObject() as? MXHistogramBucket<UnitDuration> {
            let start = bucket.bucketStart.converted(to: .seconds).value
            let end = bucket.bucketEnd.converted(to: .seconds).value
            let count = bucket.bucketCount
            totalCount += count
            buckets.append(HistogramBucketSummary(startSeconds: start, endSeconds: end, count: count))
        }
        
        guard totalCount > 0 else { return ["sampleCount": 0] }
        
        var averageSeconds: Double = 0
        var percentileValues: [Double: Double] = [:]
        let percentileTargets: [Double] = [0.5, 0.9, 0.95, 0.99]
        var cumulativeCount = 0
        
        for bucket in buckets {
            let mid = (bucket.startSeconds + bucket.endSeconds) / 2.0
            averageSeconds += mid * Double(bucket.count)
        }
        averageSeconds /= Double(totalCount)
        
        for bucket in buckets {
            cumulativeCount += bucket.count
            let fraction = Double(cumulativeCount) / Double(totalCount)
            for target in percentileTargets where percentileValues[target] == nil && fraction >= target {
                percentileValues[target] = bucket.endSeconds
            }
        }
        
        let maxSeconds = buckets.map(\.endSeconds).max() ?? 0
        
        return [
            "sampleCount": totalCount,
            "averageMilliseconds": averageSeconds * 1000,
            "p50Milliseconds": (percentileValues[0.5] ?? averageSeconds) * 1000,
            "p90Milliseconds": (percentileValues[0.9] ?? maxSeconds) * 1000,
            "p95Milliseconds": (percentileValues[0.95] ?? maxSeconds) * 1000,
            "p99Milliseconds": (percentileValues[0.99] ?? maxSeconds) * 1000,
            "maxMilliseconds": maxSeconds * 1000
        ]
    }
    
    private func persistEvent(_ event: [String: Any]) {
        guard JSONSerialization.isValidJSONObject(event) else {
            Logger.error("\(metricLogTag) Invalid event json.")
            return
        }
        do {
            var data = try JSONSerialization.data(withJSONObject: event)
            data.append(0x0A)
            
            if FileManager.default.fileExists(atPath: storeURL.path),
               let handle = try? FileHandle(forWritingTo: storeURL) {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: storeURL, options: .atomic)
            }
        } catch {
            Logger.error("\(metricLogTag) Persist event failed: \(error)")
        }
    }
}

// MARK: - MXMetricManagerSubscriber
@available(iOS 14.0, *)
extension DTMetricKitMonitor: MXMetricManagerSubscriber {
    public func didReceive(_ payloads: [MXMetricPayload]) {
        handleMetricPayloads(payloads, source: "live")
    }
    
    public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        handleDiagnosticPayloads(payloads, source: "live")
    }
}

