//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation
import LocalAuthentication

public class ScreenLock: NSObject {

    public enum Outcome {
        case success
        case cancel
        case failure(error: String)
        case unexpectedFailure(error: String)
    }

    public static let screenLockTimeoutDefault = 15 * kMinuteInterval

   @objc public let screenLockTimeouts = [
        1 * kMinuteInterval,
        5 * kMinuteInterval,
        15 * kMinuteInterval,
        30 * kMinuteInterval,
        1 * kHourInterval,
        0
    ]

    @objc public static let ScreenLockDidChange = Notification.Name("ScreenLockDidChange")
    @objc public static let ScreenLockPatternDidChange = Notification.Name("ScreenLockPatternDidChange")
    
    @objc public static let ScreenLockBindEmail = Notification.Name("ScreenLockBindEmail")
    @objc public static let ScreenLockBindPhone = Notification.Name("ScreenLockBindPhone")

    private static let OWSScreenLock_Key_IsScreenLockEnabled = "OWSScreenLock_Key_IsScreenLockEnabled"
    private static let OWSScreenLock_Key_PasscodeEnable = "OWSScreenLock_Key_PasscodeEnable"
    private static let OWSScreenLock_Key_PasscodeContent = "OWSScreenLock_Key_PasscodeContent"
    private static let OWSScreenLock_Key_ScreenLockTimeoutSeconds = "OWSScreenLock_Key_ScreenLockTimeoutSeconds"
    private static let OWSScreenLock_Key_PasscodeAttempts = "OWSScreenLock_Key_PasscodeAttempts"
    
    private static let OWSScreenLock_Key_PatternEnable = "OWSScreenLock_Key_PatternEnable"
    private static let OWSScreenLock_Key_PatternContent = "OWSScreenLock_Key_PatternContent"
    private static let OWSScreenLock_Key_PatternPathEnable = "OWSScreenLock_Key_PatternPathEnable"
    private static let OWSScreenLock_Key_PatternAttempts = "OWSScreenLock_Key_PatternAttempts"

    // MARK - Singleton class

    @objc(sharedManager)
    public static let shared = ScreenLock()

    private override init() {
        super.init()

        SwiftSingletons.register(self)
    }
    
    // MARK: - KV Store
    
    @objc
    public let keyValueStore = SDSKeyValueStore(collection: "OWSScreenLock_Collection")

    // MARK: - Properties
    // 手势和密码开启一个就可以
    @objc public func isScreenLockOpened() -> Bool {
        return isScreenLockPasscodeEnabled() || isScreenLockPatternEnabled()
    }
}
// Passcode
extension ScreenLock {
    @objc public func isScreenLockPasscodeEnabled() -> Bool {
        AssertIsOnMainThread()

        if !AppReadiness.isAppReady {
            owsFailDebug("\(logTag) accessed screen lock state before storage is ready.")
            return false
        }

        return databaseStorage.read { transaction in
            return self.keyValueStore.getBool(ScreenLock.OWSScreenLock_Key_PasscodeEnable,
                                              defaultValue: false,
                                              transaction: transaction)
        }
    }
    
    @objc public func old_isScreenLockEnabled() -> Bool {
        AssertIsOnMainThread()

        if !AppReadiness.isAppReady {
            owsFailDebug("\(logTag) accessed screen lock state before storage is ready.")
            return false
        }

        return databaseStorage.read { transaction in
            return self.keyValueStore.getBool(ScreenLock.OWSScreenLock_Key_IsScreenLockEnabled,
                                              defaultValue: false,
                                              transaction: transaction)
        }
    }
    
    @objc public func passcode() -> String {

        if !AppReadiness.isAppReady {
            owsFailDebug("\(logTag) accessed screen lock state before storage is ready.")
            return ""
        }
        
        return databaseStorage.read { transaction in
            return self.keyValueStore.getString(ScreenLock.OWSScreenLock_Key_PasscodeContent,
                                                transaction: transaction) ?? ""
        }
    }

    @objc
    public func setPasscode(_ value: String) {
        assert(AppReadiness.isAppReady)
        
        databaseStorage.write { transaction in
            self.keyValueStore.setString(value,
                                         key: ScreenLock.OWSScreenLock_Key_PasscodeContent,
                                         transaction: transaction)
            self.keyValueStore.setBool(true,
                                       key: ScreenLock.OWSScreenLock_Key_PasscodeEnable,
                                       transaction: transaction)
        }
        NotificationCenter.default.postNotificationNameAsync(ScreenLock.ScreenLockDidChange, object: nil)
    }
    
    @objc
    public func removePasscode() {
        assert(AppReadiness.isAppReady)

        DispatchQueue.main.async {
            self.databaseStorage.write { transaction in
                self.keyValueStore.removeValue(forKey: ScreenLock.OWSScreenLock_Key_PasscodeContent, transaction: transaction)
                self.keyValueStore.setBool(false,
                                           key: ScreenLock.OWSScreenLock_Key_PasscodeEnable,
                                           transaction: transaction)
            }
            NotificationCenter.default.postNotificationNameAsync(ScreenLock.ScreenLockDidChange, object: nil)
        }
    }
    
    @objc
    public func setPasscodeAttempts(_ value: Int) {
        assert(AppReadiness.isAppReady)
        databaseStorage.write { transaction in
            self.keyValueStore.setInt(value,
                                      key: ScreenLock.OWSScreenLock_Key_PasscodeAttempts,
                                      transaction: transaction)
        }
    }
    
    @objc
    public func passcodeAttempts() -> Int {
        assert(AppReadiness.isAppReady)
        return databaseStorage.read { transaction in
            return self.keyValueStore.getInt(ScreenLock.OWSScreenLock_Key_PasscodeAttempts,
                                             transaction: transaction) ?? 0
        }
    }
    
    @objc
    public func increasePasscodeAttempts() {
        assert(AppReadiness.isAppReady)
        let currentAttempts = self.passcodeAttempts()
        self.setPasscodeAttempts(currentAttempts + 1)
    }
    
    @objc
    public func clearPasscodeAttempts() {
        assert(AppReadiness.isAppReady)
        self.setPasscodeAttempts(0)
    }
}

// Pattern
extension ScreenLock {
    // MARK: - Pattern
    @objc
    public func setScreenLockPattern(_ value: String) {
        assert(AppReadiness.isAppReady)
        
        databaseStorage.write { transaction in
            self.keyValueStore.setString(value,
                                         key: ScreenLock.OWSScreenLock_Key_PatternContent,
                                         transaction: transaction)
            self.keyValueStore.setBool(true,
                                       key: ScreenLock.OWSScreenLock_Key_PatternEnable,
                                       transaction: transaction)
        }
        NotificationCenter.default.postNotificationNameAsync(ScreenLock.ScreenLockPatternDidChange, object: nil)
    }
    
    @objc
    public func isScreenLockPatternEnabled() -> Bool {
        assert(AppReadiness.isAppReady)
        
        return databaseStorage.read { transaction in
            return self.keyValueStore.getBool(ScreenLock.OWSScreenLock_Key_PatternEnable,
                                              defaultValue: false,
                                              transaction: transaction)
        }
    }
    
    @objc public func screenLockPattern() -> String {

        if !AppReadiness.isAppReady {
            owsFailDebug("\(logTag) accessed screen lock state before storage is ready.")
            return ""
        }
        
        return databaseStorage.read { transaction in
            return self.keyValueStore.getString(ScreenLock.OWSScreenLock_Key_PatternContent,
                                                transaction: transaction) ?? ""
        }
    }
    
    @objc
    public func removePattern() {
        assert(AppReadiness.isAppReady)

        DispatchQueue.main.async {
            self.databaseStorage.write { transaction in
                self.keyValueStore.removeValue(forKey: ScreenLock.OWSScreenLock_Key_PatternContent, transaction: transaction)
                self.keyValueStore.setBool(false,
                                           key: ScreenLock.OWSScreenLock_Key_PatternEnable,
                                           transaction: transaction)
                self.keyValueStore.setBool(true,
                                           key: ScreenLock.OWSScreenLock_Key_PatternPathEnable,
                                           transaction: transaction)
            }
            NotificationCenter.default.postNotificationNameAsync(ScreenLock.ScreenLockPatternDidChange, object: nil)
        }
    }

    // MARK: - Pattern Path
    @objc public func isScreenLockPatternPathEnabled() -> Bool {
        AssertIsOnMainThread()

        if !AppReadiness.isAppReady {
            owsFailDebug("\(logTag) accessed screen lock state before storage is ready.")
            return false
        }

        // 默认是要有路径的
        return databaseStorage.read { transaction in
            return self.keyValueStore.getBool(ScreenLock.OWSScreenLock_Key_PatternPathEnable,
                                              defaultValue: true,
                                              transaction: transaction)
        }
    }
    
    @objc
    public func screenLockPatternPathEnabled(_ value: Bool) {
        assert(AppReadiness.isAppReady)
        
        databaseStorage.write { transaction in
            self.keyValueStore.setBool(value,
                                       key: ScreenLock.OWSScreenLock_Key_PatternPathEnable,
                                       transaction: transaction)
        }
    }
    
    @objc
    public func setPatternAttempts(_ value: Int) {
        assert(AppReadiness.isAppReady)
        databaseStorage.write { transaction in
            self.keyValueStore.setInt(value,
                                      key: ScreenLock.OWSScreenLock_Key_PatternAttempts,
                                      transaction: transaction)
        }
    }
    
    @objc
    public func patternAttempts() -> Int {
        assert(AppReadiness.isAppReady)
        return databaseStorage.read { transaction in
            return self.keyValueStore.getInt(ScreenLock.OWSScreenLock_Key_PatternAttempts,
                                             transaction: transaction) ?? 0
        }
    }
    
    @objc
    public func increasePatternAttempts() {
        assert(AppReadiness.isAppReady)
        let currentAttempts = self.patternAttempts()
        self.setPatternAttempts(currentAttempts + 1)
    }
    
    @objc
    public func clearPatternAttempts() {
        assert(AppReadiness.isAppReady)
        self.setPatternAttempts(0)
    }
}

// Timeout
extension ScreenLock {
    @objc public func screenLockTimeout() -> TimeInterval {
        AssertIsOnMainThread()

        if !AppReadiness.isAppReady {
            owsFailDebug("accessed screen lock state before storage is ready.")
            return 0
        }

        return databaseStorage.read { transaction in
            return self.keyValueStore.getDouble(ScreenLock.OWSScreenLock_Key_ScreenLockTimeoutSeconds,
                                                defaultValue: ScreenLock.screenLockTimeoutDefault,
                                                transaction: transaction)
        }
    }

    @objc public func setScreenLockTimeout(_ value: TimeInterval) {
        AssertIsOnMainThread()
        assert(AppReadiness.isAppReady)

        databaseStorage.write { transaction in
            self.keyValueStore.setDouble(value,
                                         key: ScreenLock.OWSScreenLock_Key_ScreenLockTimeoutSeconds,
                                         transaction: transaction)
        }

        NotificationCenter.default.postNotificationNameAsync(ScreenLock.ScreenLockDidChange, object: nil)
    }
}
