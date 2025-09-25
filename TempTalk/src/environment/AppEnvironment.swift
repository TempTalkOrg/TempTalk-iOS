//
// Copyright 2018 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import TTServiceKit
import TTMessaging

public class AppEnvironment: NSObject {

    private static var _shared: AppEnvironment = AppEnvironment()

    @objc
    public class var shared: AppEnvironment {
        get {
            return _shared
        }
        set {
            guard CurrentAppContext().isRunningTests else {
                owsFailDebug("Can only switch environments in tests.")
                return
            }

            _shared = newValue
        }
    }

 

    // A temporary hack until `.shared` goes away and this can be provided to `init`.
    static let sharedNotificationPresenter = NotificationPresenter()

    public var notificationPresenterRef: NotificationPresenter

    public var pushRegistrationManagerRef: PushRegistrationManager
    
    @objc
    let deviceTransferServiceRef = DeviceTransferService()

    private override init() {
      
        self.notificationPresenterRef = Self.sharedNotificationPresenter
        self.pushRegistrationManagerRef = PushRegistrationManager.shared

        super.init()

        SwiftSingletons.register(self)
    }

    func setup() {
        
    }
}
