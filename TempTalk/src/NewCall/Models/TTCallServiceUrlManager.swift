//
//  TTCallServiceUrlManager.swift
//  TempTalk
//
//  Created by Kris.s on 2025/3/13.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

public class TTCallServiceUrlManager {

    private var allUrls: [String] = []
    private var currentIndex: Int = 0

    /// 当前正在使用的 URL
    var currentUrl: String? {
        guard allUrls.indices.contains(currentIndex) else { return nil }
        Logger.info("\(DTMeetingManager.shared.logTag) room connect currentUrl \(allUrls[currentIndex])")
        let clusters: [ClusterMetric] = DTMeetingManager.shared.clusterSpeedTester.sortedAvailableClusters()
        let sortedUrl: [String] = clusters.map { $0.url.absoluteString }
        let intersectionUrls = sortedUrl.filter { allUrls.contains($0) }
        if !intersectionUrls.isEmpty {
            return intersectionUrls.first
        }
        return allUrls[currentIndex]
    }

    /// 是否还有下一地址可尝试
    var hasNext: Bool {
        return currentIndex < allUrls.count - 1
    }

    /// 更新 URL 列表（在接口成功后调用）
    func update(with json: [String: AnyCodable]?) {
        var urls: [String] = []
        
        if let anyValue = json?["serviceUrls"], let serviceUrls = anyValue.value as? [String] {
            urls.append(contentsOf: serviceUrls)
        }

//        if let fallback = json["serviceUrl"] as? String {
//            urls.append(fallback) // fallback 放最后
//        }

        Logger.info("\(DTMeetingManager.shared.logTag) room urls \(urls)")
        self.allUrls = urls
        self.currentIndex = 0
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
