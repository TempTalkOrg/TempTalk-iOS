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
        configuration: FloatingConversationConfiguration = .default,
        addFriendSource: AddFriendSource = .unspecified
    ) {
        let floatingVC = FloatingConversationViewController(
            thread: thread,
            configuration: configuration,
            addFriendSource: addFriendSource
        )
        present(floatingVC, animated: true)
    }

    /// Objective-C entry point. It carries no provenance, so a friend request sent from the
    /// resulting chat reports none — call the Swift overload when the caller knows the source.
    @objc func showFloatingConversation(with thread: TSThread) {
        let floatingVC = FloatingConversationViewController(
            thread: thread,
            configuration: .default,
            addFriendSource: .unspecified
        )
        present(floatingVC, animated: true)
    }
}
