//
//  UIViewController+FloatingConversation.swift
//  TempTalk
//
//  Created by henry on 2025-12-26.
//  Copyright © 2025 Difft Inc. All rights reserved.
//

import Foundation
import UIKit

extension UIViewController {

    @nonobjc func showFloatingConversation(
        with thread: TSThread,
        configuration: FloatingConversationConfiguration = .default
    ) {
        let floatingVC = FloatingConversationViewController(
            thread: thread,
            configuration: configuration
        )
        present(floatingVC, animated: true)
    }

    @objc func showFloatingConversation(with thread: TSThread) {
        let floatingVC = FloatingConversationViewController(
            thread: thread,
            configuration: .default
        )
        present(floatingVC, animated: true)
    }
}
