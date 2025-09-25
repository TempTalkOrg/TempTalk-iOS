//
//  NSEContext.swift
//  NSE
//
//  Created by Felix on 2022/1/14.
//

import Foundation
import TTServiceKit
import TTMessaging

class NSEContext: NSObject, AppContext {
    func keychainStorage() -> SSKKeychainStorage {
        return SSKDefaultKeychainStorage.shared
    }
    func setColdStart(_ isColdStart: Bool) {
        self.isColdStart = isColdStart
    }
    
    var hasUI: Bool { false }
    
    let isMainApp = false
    let isMainAppAndActive = false
    let isNSE = true
    var isInMeeting = false
    
    let isRTL = false
    let isRunningTests = false
    
    var isColdStart = false
        
    let memoryPressureSource = DispatchSource.makeMemoryPressureSource(
        eventMask: .all,
        queue: .global()
    )
    
    override init() {
        super.init()
        
        memoryPressureSource.setEventHandler { [weak self] in
            if let self = self {
                Logger.warn("Memory pressure event: \(self.memoryPressureSource.memoryEventDescription)")
            } else {
                Logger.warn("Memory pressure event.")
            }
            Logger.warn("Current memory usage: \(LocalDevice.memoryUsageString)")
            Logger.flush()
        }
        memoryPressureSource.resume()
    }
    
    var mainWindow: UIWindow?
    let frame: CGRect = .zero
    let interfaceOrientation: UIInterfaceOrientation = .unknown
    let reportedApplicationState: UIApplication.State = .background
    let statusBarHeight: CGFloat = .zero
    
    func isInBackground() -> Bool { true }
    func isAppForegroundAndActive() -> Bool { false }
    
    func beginBackgroundTask(expirationHandler: @escaping BackgroundTaskExpirationHandler) -> UIBackgroundTaskIdentifier { .invalid }
    func endBackgroundTask(_ backgroundTaskIdentifier: UIBackgroundTaskIdentifier) {}
    
//    func ensureSleepBlocking(_ shouldBeBlocking: Bool, blockingObjects: [Any]) {}
    func ensureSleepBlocking(_ shouldBeBlocking: Bool, blockingObjectsDescription: String) {}
    
    // The NSE can't update UIApplication directly, so instead we cache our last desired badge number
    // and use it to update the modified notification content
    var desiredBadgeNumber: AtomicOptional<Int> = .init(nil, lock: .sharedGlobal)
    func setMainAppBadgeNumber(_ value: Int) {
        desiredBadgeNumber.set(value)
    }
    
    func setStatusBarHidden(_ isHidden: Bool, animated isAnimated: Bool) {}
        
    func frontmostViewController() -> UIViewController? { nil }
    
    var openSystemSettingsAction: UIAlertAction?
    
    func openSystemSettingsAction(completion: (() -> Void)? = nil) -> ActionSheetAction? {
        return nil
    }
    
    func doMultiDeviceUpdate(withProfileKey profileKey: SSKAES256Key) {}
    
    func setNetworkActivityIndicatorVisible(_ value: Bool) {}
    
    let appLaunchTime = Date()
    
    var shouldProcessIncomingMessages: Bool { true }
    
    func mainApplicationStateOnLaunch() -> UIApplication.State { .inactive }
    func canPresentNotifications() -> Bool { true }
    
    func appDocumentDirectoryPath() -> String {
        guard let documentDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last else {
            owsFail("failed to query document directory")
        }
        return documentDirectoryURL.path
    }
    
    func appSharedDataDirectoryPath() -> String {
        guard let groupContainerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: TSConstants.applicationGroup) else {
            owsFail("failed to query group container")
        }
        return groupContainerURL.path
    }
    
    func appDatabaseBaseDirectoryPath() -> String {
        return appSharedDataDirectoryPath()
    }
    
    func appUserDefaults() -> UserDefaults {
        guard let userDefaults = UserDefaults(suiteName: TSConstants.applicationGroup) else {
            owsFail("failed to initialize user defaults")
        }
        return userDefaults
    }
    
    var debugLogsDirPath: String {
        DebugLogger.nseDebugLogsDirPath
    }
}


fileprivate extension DispatchSourceMemoryPressure {
    var memoryEvent: DispatchSource.MemoryPressureEvent {
        DispatchSource.MemoryPressureEvent(rawValue: data)
    }
    
    var memoryEventDescription: String {
        switch memoryEvent {
        case .normal: return "Normal"
        case .warning: return "Warning!"
        case .critical: return "Critical!!"
        default: return "Unknown value: \(memoryEvent.rawValue)"
        }
    }
}
