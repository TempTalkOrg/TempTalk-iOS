//
//  UIApplication+Util.swift
//  Pods
//
//  Created by Henry on 2025/2/12.
//

import Foundation

@objc public extension UIApplication {
    func topViewController(base: UIViewController? = UIApplication.shared.compatibleKeyWindow?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        } else if let tab = base as? UITabBarController {
            return topViewController(base: tab.selectedViewController)
        } else if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
        
    var compatibleKeyWindow: UIWindow? {
        if #available(iOS 15.0, *) {
            return self.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }
        } else {
            return self.windows.first { $0.isKeyWindow }
        }
    }
}
