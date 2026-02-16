//
//  DTConfidentialMessageAlertController.swift
//  TempTalk
//
//  Created by henry on 2026/01/23.
//  Copyright © 2026 Difft. All rights reserved.
//

import UIKit
import TTMessaging

/// 机密消息提示控制器（使用 FloatingConversationViewController）
@objc
public class DTConfidentialMessageAlertController: NSObject {

    // MARK: - Public API

    @objc
    static func present(from conversationVC: ConversationViewController?, confirm: (() -> Void)? = nil) {
        guard let conversationVC = conversationVC else {
            Logger.warn("ConversationVC is nil, cannot present alert")
            return
        }

        // 创建内容视图控制器
        let contentVC = DTConfidentialMessageContentViewController()
        contentVC.confirmHandler = confirm

        // 使用 FloatingConversationViewController 包装，使用预设的 confidentialAlert 配置
        let floatingVC = FloatingConversationViewController(
            viewController: contentVC,
            configuration: .confidentialAlert,
            wrapInNavigationController: false
        )

        conversationVC.present(floatingVC, animated: true)
    }
}
