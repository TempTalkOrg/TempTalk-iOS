//
//  Copyright (c) 2026 Difft. All rights reserved.
//

import UIKit

/// Alerts the user when a pinned TLS connection fails certificate validation,
/// i.e. a possible man-in-the-middle attack. This mirrors the desktop client's
/// `badSelfSignedCert` warning. Only pinned-policy failures are routed here, so
/// noisier system-default failures (captive portals, corporate proxies) are
/// excluded. Product-approved user-facing copy describes this as a network security
/// warning without removing the underlying possible-MITM semantics. The alert is
/// shown once per process session; choosing "Continue" suppresses further warnings,
/// while "Exit" terminates the app.
@objc
public class DTNetworkRiskWarning: NSObject {

    @objc
    public static let shared = DTNetworkRiskWarning()

    // Confined to the main thread; no locking needed.
    private var isPresenting = false
    private var didIgnore = false

    private override init() {
        super.init()
    }

    @objc
    public func warnPossibleMITM() {
        guard CurrentAppContext().isMainApp else { return }

        DispatchMainThreadSafe {
            guard !self.isPresenting, !self.didIgnore else { return }
            guard CurrentAppContext().isMainAppAndActive else { return }
            guard let topVC = UIApplication.shared.topViewController() else {
                Logger.error("topViewController was nil, skip MITM warning.")
                return
            }

            self.isPresenting = true

            let alert = UIAlertController(
                title: Localized("net_risk_warning_title"),
                message: Localized("net_risk_warning_message"),
                preferredStyle: .alert)

            alert.addAction(UIAlertAction(
                title: Localized("net_risk_warning_ignore"),
                style: .cancel) { _ in
                    self.isPresenting = false
                    self.didIgnore = true
                })

            alert.addAction(UIAlertAction(
                title: Localized("net_risk_warning_quit"),
                style: .destructive) { _ in
                    Logger.error("User chose to quit due to possible MITM.")
                    Logger.flush()
                    exit(0)
                })

            topVC.present(alert, animated: true, completion: nil)

            // If UIKit rejected the presentation (e.g. another modal is mid-transition),
            // reset the guard so a later failure can still surface the warning.
            if topVC.presentedViewController !== alert {
                Logger.error("MITM warning presentation was rejected, reset guard.")
                self.isPresenting = false
            }
        }
    }
}
