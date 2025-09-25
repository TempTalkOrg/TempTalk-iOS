//
//  DTBulletChatControlViewRepresentable.swift
//  Difft
//
//  Created by Henry on 2025/4/9.
//  Copyright © 2025 Difft. All rights reserved.
//

import SwiftUI

struct DTBulletChatViewRepresentable: UIViewRepresentable {
    @EnvironmentObject var roomCtx: RoomContext
    
    func makeUIView(context: Context) -> DTBulletChatView {
        let buttetChatView = DTBulletChatView()
        RoomDataManager.shared.onBulletMessageUpdate = {
            DispatchMainThreadSafe {
            var chatModel: DTBulletChatModel = DTBulletChatModel()
            switch RoomDataManager.shared.bulletType {
            case .localPartConnect, .remotePartConnect:
                chatModel = DTBulletChatModel.generate(withMessage: "", type: BulletMessageType.join.rawValue, receiptId: RoomDataManager.shared.participantId)
            case .startScreenShare:
                chatModel = DTBulletChatModel.generate(withMessage: "", type: BulletMessageType.start_screen.rawValue, receiptId: RoomDataManager.shared.participantId)
            case .remoteMute:
                chatModel = DTBulletChatModel.generate(withMessage: "",
                                                       type: RoomDataManager.shared.isMuted ? BulletMessageType.mic_off.rawValue : BulletMessageType.mic_on.rawValue,
                                                       receiptId: RoomDataManager.shared.participantId)
            case .RTMBarrage:
                chatModel = DTBulletChatModel.generate(withMessage: RoomDataManager.shared.message,
                                                       type: BulletMessageType.text.rawValue,
                                                       receiptId: RoomDataManager.shared.participantId)
            case .roomDefault: break
            }
            
            buttetChatView.insertBulletChat(chatModel)
        }
        }
        return buttetChatView
    }

    func updateUIView(_ uiView: DTBulletChatView, context: Context) {
        for participant in roomCtx.room.remoteParticipants.values.compactMap({ $0 }) {
            if participant.videoTracks.contains(where: { $0.source == .screenShareVideo }) {
                let defaultChatModel = DTBulletChatModel.generate(withMessage: "", type: BulletMessageType.start_screen.rawValue, receiptId: participant.identity?.stringValue.components(separatedBy: ".").first ?? "")
                uiView.insertBulletChat(defaultChatModel)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        
    }
}

struct DTBulletChatControlViewRepresentable: UIViewRepresentable {
    @EnvironmentObject var roomCtx: RoomContext
    @Binding var showQuickPanel: Bool
    var onClickInput: (() -> Void)?
    
    func makeUIView(context: Context) -> DTBulletChatControlView {
        let inputView = DTBulletChatControlView()
        inputView.delegate = context.coordinator
        return inputView
    }

    func updateUIView(_ uiView: DTBulletChatControlView, context: Context) {
        
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(showQuickPanel: $showQuickPanel, onClickInput: onClickInput)
    }

    class Coordinator: NSObject, DTBulletChatControlDelegate {
        @Binding var showQuickPanel: Bool
        var onClickInput: (() -> Void)?

        init(showQuickPanel: Binding<Bool>, onClickInput: (() -> Void)?) {
            _showQuickPanel = showQuickPanel
            self.onClickInput = onClickInput
        }
        
        func bulletChatControlDidClickInput(draft: String?) {
            showQuickPanel.toggle()
            onClickInput?()
        }
    }
}
