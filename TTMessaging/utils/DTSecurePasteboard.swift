//
//  DTSecurePasteboard.swift
//  TTMessaging
//
//  Secure pasteboard with localOnly and 5-minute expiration
//

import Foundation
import UIKit

/// Secure pasteboard utility
/// - localOnly: Prevents iCloud sync
/// - 5-minute expiration
@objc
public class DTSecurePasteboard: NSObject {

    /// Expiration time: 5 minutes
    private static let expirationInterval: TimeInterval = 5 * 60

    // MARK: - Public Methods

    /// Copy string securely (local only, 5-min expiration)
    @objc
    public static func setString(_ string: String) {
        guard !string.isEmpty else { return }

        let pasteboard = UIPasteboard.general
        let expirationDate = Date().addingTimeInterval(expirationInterval)

        pasteboard.setItems(
            [[UIPasteboard.typeAutomatic: string]],
            options: [
                .localOnly: true,
                .expirationDate: expirationDate
            ]
        )
    }

    /// Copy multiple strings securely (for messages with mentions)
    /// strings[0]: message text, strings[1]: mention JSON
    @objc
    public static func setStrings(_ strings: [String]) {
        guard !strings.isEmpty else { return }

        let pasteboard = UIPasteboard.general
        let expirationDate = Date().addingTimeInterval(expirationInterval)

        let items = strings.map { [UIPasteboard.typeAutomatic: $0] }
        pasteboard.setItems(
            items,
            options: [
                .localOnly: true,
                .expirationDate: expirationDate
            ]
        )
    }

    /// Clear pasteboard immediately
    @objc
    public static func clear() {
        UIPasteboard.general.setItems([], options: [:])
    }
}
