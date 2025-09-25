//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

//import PromiseKit
import TTServiceKit

@objc(OWSSyncPushTokensJob)
class SyncPushTokensJob: NSObject {
    let TAG = "[SyncPushTokensJob]"

    @objc public static let PushTokensDidChange = Notification.Name("PushTokensDidChange")

    // MARK: Dependencies
    let accountManager: AccountManager
    let preferences: OWSPreferences
    var pushRegistrationManager: PushRegistrationManager {
        return PushRegistrationManager.shared
    }

    @objc var uploadOnlyIfStale = true

    @objc
    required init(accountManager: AccountManager, preferences: OWSPreferences) {
        self.accountManager = accountManager
        self.preferences = preferences
    }

    class func run(accountManager: AccountManager, preferences: OWSPreferences) -> Promise<Void> {
        let job = self.init(accountManager: accountManager, preferences: preferences)
        return job.run()
    }
    
    class func run(accountManager: AccountManager, preferences: OWSPreferences, uploadOnlyIfStale: Bool) -> Promise<Void> {
        let job = self.init(accountManager: accountManager, preferences: preferences)
        job.uploadOnlyIfStale = uploadOnlyIfStale
        return job.run()
    }

    func run() -> Promise<Void> {
        Logger.info("Starting.")

        return firstly {
            return self.pushRegistrationManager.requestPushTokens()
        }.then { (pushToken: String, voipToken: String) -> Promise<Void> in
            Logger.info("finished: requesting push tokens")
            var shouldUploadTokens = false

            if self.preferences.getPushToken() != pushToken || self.preferences.getVoipToken() != voipToken {
                Logger.debug("Push tokens changed.")
                shouldUploadTokens = true
            } else if !self.uploadOnlyIfStale {
                Logger.debug("Forced uploading, even though tokens didn't change.")
                shouldUploadTokens = true
            }

            if AppVersion.shared().lastAppVersion != AppVersion.shared().currentAppReleaseVersion {
                Logger.info("Uploading due to fresh install or app upgrade.")
                shouldUploadTokens = true
            }

            guard shouldUploadTokens else {
                Logger.info("No reason to upload pushToken: \(pushToken), voipToken: \(voipToken)")
                return Promise.value(())
            }

            Logger.warn("uploading tokens to account servers. pushToken: \(pushToken), voipToken: \(voipToken)")
            return firstly {
                self.accountManager.updatePushTokens(pushToken: pushToken, voipToken: voipToken)
            }.done(on: DispatchQueue.global()) { _ in
                self.recordPushTokensLocally(pushToken: pushToken, voipToken: voipToken)
            }
        }.done {
            Logger.info("completed successfully.")
        }
    }

    // MARK - objc wrappers, since objc can't use swift parameterized types

    @objc class func run(accountManager: AccountManager, preferences: OWSPreferences) -> AnyPromise {
        let promise: Promise<Void> = self.run(accountManager: accountManager, preferences: preferences)
        return AnyPromise(promise)
    }

    @objc func run() -> AnyPromise {
        let promise: Promise<Void> = self.run()
        return AnyPromise(promise)
    }

    private func recordPushTokensLocally(pushToken: String, voipToken: String) {
        Logger.warn("\(TAG) Recording push tokens locally. pushToken: \(pushToken), voipToken: \(voipToken)")

        var didTokensChange = false

        if (pushToken != self.preferences.getPushToken()) {
            Logger.info("\(TAG) Recording new plain push token")
            self.preferences.setPushToken(pushToken)
            didTokensChange = true
        }

        if (voipToken != self.preferences.getVoipToken()) {
            Logger.info("\(TAG) Recording new voip token")
            self.preferences.setVoipToken(voipToken)
            didTokensChange = true
        }

        if (didTokensChange) {
            NotificationCenter.default.postNotificationNameAsync(SyncPushTokensJob.PushTokensDidChange, object: nil)
        }
    }
}
