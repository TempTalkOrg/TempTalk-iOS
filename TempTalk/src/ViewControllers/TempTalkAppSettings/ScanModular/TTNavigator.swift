//
//  TTNavigator.swift
//  TempTalk
//
//  Created by Kris.s on 2025/1/8.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

@objc
class TTNavigator: NSObject {
    
    @objc
    public static func goToHomePage() {
        
        guard let window = CurrentAppContext().mainWindow else {
            return
        }
        
        // 获取当前的 rootViewController
        guard let tabBarController = window.rootViewController as? DFTabbarController else {
            return
        }
        
        // 1. 如果当前页面是通过 push 操作进入的，我们尝试 pop 到根视图控制器
        if let navigationController = tabBarController.selectedViewController as? OWSNavigationController {
            navigationController.popToRootViewController(animated: true)
        }
        
        // 2. 如果当前页面是通过 present 方式打开的，我们需要 dismiss
        if let presentedViewController = tabBarController.presentedViewController {
            presentedViewController.dismiss(animated: true, completion: nil)
        }
        
        // 3. 设置 TabBarController 的 selectedIndex 为 0，回到首页
        tabBarController.selectedIndex = 0
    }
    
}
