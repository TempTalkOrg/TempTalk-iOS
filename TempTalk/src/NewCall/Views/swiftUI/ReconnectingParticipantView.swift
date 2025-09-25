//
//  ReconnectingParticipantView.swift
//  Difft
//
//  Created by Henry on 2025/6/17.
//  Copyright © 2025 Difft. All rights reserved.
//

import LiveKit
import SFSafeSymbols
import SwiftUI
import Lottie
import TTServiceKit

struct ParticipantVideoView: View {
    let snapshot: ParticipantSnapshot
    let is1on1: Bool
    let videoViewMode: VideoView.LayoutMode
    let geometry: GeometryProxy
    @EnvironmentObject var liveKitCtx: LiveKitContext
    @Binding var isRendering: Bool

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            backgroundView

            if isLocalParticipant {
                renderLocalParticipant()
            } else {
                renderRemoteParticipant()
            }
        }
        .cornerRadius(8)
    }

    private var isLocalParticipant: Bool {
        TSAccountManager.localNumber() == snapshot.identity
    }

    private var recipientId: String {
        snapshot.identity
    }

    private var participantName: String {
        DTLiveKitCallModel.getDisplayName(recipientId: recipientId)
    }

    @ViewBuilder
    private var backgroundView: some View {
        if is1on1 {
            Color.dtBackground
        } else {
            Color.lkGray1
        }
    }

    @ViewBuilder
    private func renderLocalParticipant() -> some View {
        if let participant = DTMeetingManager.shared.roomContext?.room.localParticipant,
           let publication = participant.firstCameraPublication,
           !publication.isMuted,
           let track = publication.track as? VideoTrack,
           liveKitCtx.videoViewVisible {

            ZStack(alignment: .topLeading) {
                SwiftUIVideoView(
                    track,
                    layoutMode: videoViewMode,
                    mirrorMode: liveKitCtx.videoViewMirrored ? .mirror : .auto,
                    renderMode: liveKitCtx.preferSampleBufferRendering ? .sampleBuffer : .auto,
                    pinchToZoomOptions: liveKitCtx.videoViewPinchToZoomOptions,
                    isDebugMode: liveKitCtx.showInformationOverlay,
                    isRendering: $isRendering
                )
                .ignoresSafeArea()

                if !isRendering {
                    ProgressView().progressViewStyle(CircularProgressViewStyle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
        } else {
            avatarAndNameView()
        }

        if !is1on1 {
            userInfoBar()
        }
    }

    @ViewBuilder
    private func renderRemoteParticipant() -> some View {
        avatarAndNameView()

        if !is1on1 {
            userInfoBar()
        }
    }

    @ViewBuilder
    private func avatarAndNameView() -> some View {
        if is1on1 {
            VStack {
                AvatarImageViewRepresentable(recipientId: recipientId)
                    .frame(width: 120, height: 120)

                Text(participantName)
                    .font(.system(size: 17))
                    .foregroundColor(.white)
                    .padding(.top, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .position(CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2.5))
        } else {
            AvatarImageViewRepresentable(recipientId: recipientId)
                .padding(EdgeInsets(top: 20, leading: 22, bottom: 24, trailing: 22))
        }
    }

    @ViewBuilder
    private func userInfoBar() -> some View {
        HStack(spacing: 4) {
            Image(uiImage: UIImage(named: "call_ic_muted") ?? UIImage())
                .frame(width: 16, height: 16)

            Text(participantName)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(6)
        .background(Color.dtBackground.opacity(0.8).cornerRadius(4))
        .padding(.leading, 5)
        .padding(.bottom, 5)
        .frame(maxWidth: geometry.size.width - 10, alignment: .leading)
    }
}

struct ReconnectingParticipantView: View {
    @EnvironmentObject var liveKitCtx: LiveKitContext
    @ObservedObject var snapshot: ParticipantSnapshot

    var is1on1: Bool = false
    var videoViewMode: VideoView.LayoutMode = .fit
    
    @State private var isRendering: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            ParticipantVideoView(
                snapshot: snapshot,
                is1on1: is1on1,
                videoViewMode: videoViewMode,
                geometry: geometry,
                isRendering: $isRendering
            )
            .environmentObject(liveKitCtx)
        }
    }
}
