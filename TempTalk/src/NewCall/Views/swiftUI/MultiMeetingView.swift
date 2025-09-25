//
//  MultiMeetingView.swift
//  Difft
//
//  Created by Henry on 2025/4/1.
//  Copyright © 2025 Difft. All rights reserved.
//

import SwiftUI
import Combine

struct MultiMeetingView: UIViewRepresentable {
    @EnvironmentObject var roomCtx: RoomContext

    func makeUIView(context: Context) -> DTMultiMeetingView {
        let view = DTMultiMeetingView.init(mode: .mini, isLiveStream: false)
        view.update(withBroadcasters: broadcastersItems(), handupAudiences: nil)
        context.coordinator.cancellable?.cancel()
        context.coordinator.cancellable = RoomDataManager.shared.raiseHandsPublisher
                .receive(on: RunLoop.main)
                .sink {_ in
                    view.udpateCollectionContents()
                }
        return view
    }
    
    func updateUIView(_ uiView: DTMultiMeetingView, context: Context) {
        // 更新视图逻辑（如果需要动态更新）
        RoomDataManager.shared.onMeetingUpdate = {
            DispatchMainThreadSafe {
                uiView.update(withBroadcasters: broadcastersItems(), handupAudiences: nil)
            }
        }
    }
    
    func broadcastersItems() -> [DTMultiChatItemModel] {
        let sortedParticipants = DTMeetingManager.shared.sortedParticipants()
        var items: [DTMultiChatItemModel] = []
        for participant in sortedParticipants.compactMap({ $0 }) {
            // 检查该用户是否有正在共享的屏幕视频流
            let chatModel = DTMultiChatItemModel()
            chatModel.recipientId = participant.identity?.stringValue
            chatModel.displayName = TextSecureKitEnv.shared().contactsManager.displayName(forPhoneIdentifier: chatModel.recipientId?.components(separatedBy: ".").first)
            if participant.videoTracks.contains(where: { $0.source == .screenShareVideo }) {
                chatModel.isSharing = true
            } else {
                chatModel.isSharing = false
            }
            chatModel.isSpeaking = participant.isSpeaking
            if participant.isSpeaking {
                chatModel.isMute = false
            } else {
                chatModel.isMute = participant.audioTracks.first?.isMuted ?? true
            }
            if let metadata = participant.metadata, metadata.contains("host") {
                chatModel.isHost = true
            } else {
                chatModel.isHost = false
            }

            items.append(chatModel)
        }
        return items
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
    
    class Coordinator: NSObject {
        var cancellable: AnyCancellable?
        
        deinit {
            cancellable?.cancel()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            Spacer()
            MultiMeetingView()
                .frame(maxHeight: .infinity)
            Spacer()
        }
    }
}
