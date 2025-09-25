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

    private static let OWSScreenLock_Key_IsScreenLockEnabled = "OWSScreenLock_Key_IsScreenLockEnabled"
    private static let OWSScreenLock_Key_PasscodeEnable = "OWSScreenLock_Key_PasscodeEnable"
    private static let OWSScreenLock_Key_PasscodeContent = "OWSScreenLock_Key_PasscodeContent"
    private static let OWSScreenLock_Key_ScreenLockTimeoutSeconds = "OWSScreenLock_Key_ScreenLockTimeoutSeconds"
    private static let OWSScreenLock_Key_Attempts = "OWSScreenLock_Key_Attempts"

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

    @objc public func isScreenLockEnabled() -> Bool {
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
    public func setAttempts(_ value: Int) {
        assert(AppReadiness.isAppReady)
        databaseStorage.write { transaction in
            self.keyValueStore.setInt(value,
                                      key: ScreenLock.OWSScreenLock_Key_Attempts,
                                      transaction: transaction)
        }
    }
    
    @objc
    public func attempts() -> Int {
        assert(AppReadiness.isAppReady)
        return databaseStorage.read { transaction in
            return self.keyValueStore.getInt(ScreenLock.OWSScreenLock_Key_Attempts,
                                             transaction: transaction) ?? 0
        }
    }
    
    @objc
    public func increaseAttempts() {
        assert(AppReadiness.isAppReady)
        let currentAttempts = self.attempts()
        self.setAttempts(currentAttempts + 1)
    }
    
    @objc
    public func clearAttempts() {
        assert(AppReadiness.isAppReady)
        self.setAttempts(0)
    }

}
