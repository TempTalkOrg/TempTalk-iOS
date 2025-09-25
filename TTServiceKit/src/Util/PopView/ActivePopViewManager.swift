//
//  ActivePopViewManager.swift
//  Pods
//
//  Created by Henry on 2025/2/11.
//


import UIKit

@objc
public class ActivePopViewManager: NSObject {
    static let shared = ActivePopViewManager()
    var hasPoped = false
    
    let activeDeviceApi = DTInactiveAPI()
    
    func showPopView () {
        guard !self.hasPoped else {
            Logger.info("OWSWebsocket popView hasPoped")
            return
        }
        DispatchMainThreadSafe {
            guard let topVC = UIApplication.shared.topViewController() else {
                Logger.warn("OWSWebsocket getTopViewController failed")
                return
            }
            let alertController = UIAlertController(title: Localized("DEVICE_INACTIVE_POPVIEW_TITLE"), message: Localized("DEVICE_INACTIVE_POPVIEW_CONTENT"), preferredStyle: .alert)
            // 添加一个按钮
            let action = UIAlertAction(title: Localized("DEVICE_INACTIVE_POPVIEW_BUTTON"), style: .default) { _ in
                //发起链接
                Logger.info("The alert has tapped")
                DTToastHelper.showHud(in: topVC.view)
                self.activeDeviceApi.activeDeviceRequest { enity in
                    DTToastHelper.hide()
                    self.hasPoped = false
                    DTToastHelper.toast(withText: Localized("DEVICE_INACTIVE_POPVIEW_SUCCESS_TOAST"))
                    Logger.info("OWSWebsocket active Device Success")
                } failure: { error in
                    DTToastHelper.hide()
                    self.hasPoped = false
                    DTToastHelper.toast(withText: error.localizedDescription)
                    Logger.error("OWSWebsocket active Device Failed")
                }
            }
            alertController.addAction(action)
            topVC.present(alertController, animated: true, completion: nil)
            self.hasPoped = true
        }
    }
}
