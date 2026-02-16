//
//  DTBulletChatControlViewRepresentable.swift
//  Difft
//
//  Created by Henry on 2025/4/9.
//  Copyright © 2025 Difft. All rights reserved.
//

import SwiftUI
import TTServiceKit
import TTMessaging
import LiveKit
import Combine

struct DTBulletChatViewRepresentable: UIViewRepresentable {
    @EnvironmentObject var roomCtx: RoomContext

    func makeUIView(context: Context) -> DTBulletChatView {
        let buttetChatView = DTBulletChatView()
        context.coordinator.setupSubscription(for: buttetChatView)
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
        private var cancellables = Set<AnyCancellable>()

        func setupSubscription(for bulletChatView: DTBulletChatView) {
            Logger.info("[BulletChat] DTBulletChatViewRepresentable - setting up subscription")

            RoomDataManager.shared.bulletMessagePublisher
                .sink { [weak bulletChatView] _ in
                    Logger.info("[BulletChat] DTBulletChatViewRepresentable - bulletMessagePublisher received")

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

                        bulletChatView?.insertBulletChat(chatModel)
                    }
                }
                .store(in: &cancellables)
        }
    }
}

struct DTEmojiFlyingViewRepresentable: UIViewRepresentable {
    @EnvironmentObject var roomCtx: RoomContext
    let containerSize: CGSize

    func makeUIView(context: Context) -> DTEmojiFlyingView {
        let orientation = determineOrientation()
        let emojiView = DTEmojiFlyingView(orientation: orientation)
        emojiView.updateContainerSize(containerSize)
        context.coordinator.setupSubscription(for: emojiView)
        return emojiView
    }

    func updateUIView(_ uiView: DTEmojiFlyingView, context: Context) {
        let newOrientation = determineOrientation()
        uiView.updateOrientation(newOrientation)
        uiView.updateContainerSize(containerSize)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject {
        private var cancellables = Set<AnyCancellable>()

        func setupSubscription(for emojiView: DTEmojiFlyingView) {
            Logger.info("[BulletChat] DTEmojiFlyingViewRepresentable - setting up subscription")

            RoomDataManager.shared.bubbleMessagePublisher
                .sink { [weak emojiView] _ in
                    Logger.info("[BulletChat] DTEmojiFlyingViewRepresentable - bubbleMessagePublisher received")

                    DispatchMainThreadSafe {
                        let manager = RoomDataManager.shared
                        let chatModel: DTBulletChatModel

                        if !manager.bubbleEmoji.isEmpty {
                            chatModel = DTBulletChatModel.generate(
                                withMessage: manager.bubbleEmoji,
                                type: BulletMessageType.text.rawValue,
                                receiptId: manager.bubbleParticipantId,
                                senderName: manager.bubbleText
                            )
                        } else {
                            chatModel = DTBulletChatModel.generate(
                                withMessage: manager.bubbleMessage,
                                type: BulletMessageType.text.rawValue,
                                receiptId: manager.bubbleParticipantId
                            )
                        }
                        emojiView?.addFlyingEmoji(chatModel)
                    }
                }
                .store(in: &cancellables)
        }
    }

    private func determineOrientation() -> DTMeetingUIOrientation {
        let screenSize = UIScreen.main.bounds.size
        return screenSize.width > screenSize.height ? .landscape : .portrait
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
