//
//  ConversationViewController+Dependencies.swift
//  Signal
//
//  Created by Jaymin on 2024/1/17.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit

@objc
extension ConversationViewController {
    var audioSession: OWSAudioSession {
        OWSAudioSession.shared
    }
    
    var contactsManager: OWSContactsManager {
        Environment.shared.contactsManager
    }
}
