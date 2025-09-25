//
//  ATAppUpdater.swift
//  TTServiceKit
//
//  Created by Kris.s on 2025/4/30.
//

import Foundation

extension ATAppUpdater {
    
    private struct ATConstants {
        static let totalTimeout: TimeInterval = 20.0
        static let minSingleTimeout: TimeInterval = 5.0
        static let hostUrls = [
            "https://d1rx01ctrapt3y.cloudfront.net/version.json",
            "https://aly-tt-version-files.oss-accelerate.aliyuncs.com/version.json"
        ]
    }
    
    // MARK: - Public Interface
    @objc public func checkNewAppVersion(_ completion: @escaping (Bool, Bool, String?) -> Void) {
        guard let currentVersion = Bundle.main.shortVersion else {
            DispatchQueue.main.async { completion(false, false, nil) }
            return
        }
        
        let startTime = Date()
        let context = VersionCheckContext(startTime: startTime, currentVersion: currentVersion)
        
        tryNextURL(context: context, completion: completion)
    }
    
    // MARK: - Private Types
    private class VersionCheckContext {
        var currentIndex: Int = 0
        let startTime: Date
        let currentVersion: String
        
        init(startTime: Date, currentVersion: String) {
            self.startTime = startTime
            self.currentVersion = currentVersion
        }
    }
    
    // MARK: - Private Methods
    private func tryNextURL(context: VersionCheckContext, completion: @escaping (Bool, Bool, String?) -> Void) {
        // Termination check
        guard context.currentIndex < ATConstants.hostUrls.count,
              -context.startTime.timeIntervalSinceNow < ATConstants.totalTimeout else
        {
            DispatchQueue.main.async { completion(false, false, nil) }
            return
        }
        
        let urlString = ATConstants.hostUrls[context.currentIndex]
        context.currentIndex += 1
        
        guard let url = URL(string: urlString) else {
            DispatchQueue.global().async { [weak self] in
                self?.tryNextURL(context: context, completion: completion)
            }
            return
        }
        
        // Calculate dynamic timeout
        let elapsed = -context.startTime.timeIntervalSinceNow
        let remainingTimeout = ATConstants.totalTimeout - elapsed
        let singleTimeout = max(ATConstants.minSingleTimeout,
                               remainingTimeout / Double(ATConstants.hostUrls.count - context.currentIndex + 1))
        
        // Configure request
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = singleTimeout
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            
            if let data = data,
               let versionInfo = self.parseVersionData(data, currentVersion: context.currentVersion)
            {
                DispatchQueue.main.async {
                    completion(versionInfo.hasNewVersion,
                             versionInfo.needForceUpdate,
                             versionInfo.latestVersion)
                }
                return
            }
            
            // Try next URL on failure
            DispatchQueue.global().async { [weak self] in
                self?.tryNextURL(context: context, completion: completion)
            }
        }
        task.resume()
    }
    
    private func parseVersionData(_ data: Data, currentVersion: String) -> (hasNewVersion: Bool, needForceUpdate: Bool, latestVersion: String, appStoreURL: String)? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let appDetails = results.first else {
            return nil
        }
        
        let latestVersion = appDetails["version"] as? String ?? ""
        let availableVersion = appDetails["availableVersion"] as? String ?? ""
        let appStoreURL = (appDetails["trackViewUrl"] as? String)?.replacingOccurrences(of: "&uo=4", with: "") ?? ""
        
        var hasNewVersion = false
        var needForceUpdate = false
        
        if latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
            hasNewVersion = true
        }
        
        if availableVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
            hasNewVersion = true
            needForceUpdate = true
        }
        
        self.appStoreURL = appStoreURL
        
        return (hasNewVersion, needForceUpdate, latestVersion, appStoreURL)
    }
}

// MARK: - Bundle Extension
private extension Bundle {
    var shortVersion: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
