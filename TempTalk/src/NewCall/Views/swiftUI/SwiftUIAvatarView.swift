//
//  SwiftUIAvatarView.swift
//  Signal
//
//  Created by Ethan on 28/11/2024.
//  Copyright © 2024 Difft. All rights reserved.
//

import SwiftUI
import TTMessaging

struct AvatarImageViewRepresentable: UIViewRepresentable {
    var recipientId: String
    
    func makeUIView(context: Context) -> AvatarImageView {
        let imageView = AvatarImageView()
        imageView.setContentHuggingLow()
        imageView.setCompressionResistanceLow()
        
        return imageView
    }

    func updateUIView(_ uiView: AvatarImageView, context: Context) {
        let displayName = Environment.shared.contactsManager.displayName(forPhoneIdentifier: recipientId)
        uiView.setImageWithRecipientId(recipientId, displayName: displayName)
    }
    
}
