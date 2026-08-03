//
//  Room1on1ContentView.swift
//  TempTalk
//
//  Created by undefined on 15/1/25.
//  Copyright © 2025 Difft. All rights reserved.
//

import SwiftUI
import LiveKit

struct Room1on1ContentView: View {
    
    let logTag: String = "[newcall][view]"
    
    @EnvironmentObject var appCtx: LiveKitContext
    @EnvironmentObject var roomCtx: RoomContext
    @EnvironmentObject var room: Room
    
    var currentCall: DTLiveKitCallModel { roomCtx.currentCall }
    
    @State var videoPositionExchange: Bool = false
    /// Last participant shown; kept so an empty room shows their avatar instead of a blank screen.
    @State private var lastShownRecipientId: String?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Render live participants throughout, including during reconnect. The SDK keeps
                // the remote roster across reconnect (Route B) and VideoView freezes the last frame
                // via keepLastFrameOnTrackChange, so there is no avatar swap / no reconnect branch.
                let local = roomCtx.room.localParticipant
                let remote = fetch1on1OthersideParticipant()
                let isLocalCameraOn = local.isCameraEnabled()

                ZStack {
                    if let remote {
                        // Main view: remote by default, local after swap.
                        ParticipantView(
                            participant: videoPositionExchange ? local : remote,
                            is1on1: true,
                            videoViewMode: .fill
                        )
                        // Fill to physical screen edges (under status bar / home indicator), no letterbox.
                        .ignoresSafeArea()
                    } else if let lastId = lastShownRecipientId ?? nonEmptyOtherSideId() {
                        // Peer left — keep their avatar instead of a blank screen until teardown.
                        lastParticipantAvatar(recipientId: lastId, geometry: geometry)
                    }

                    // Floating preview: only when local camera is on; tap swaps content with the main view.
                    if isLocalCameraOn, let remote {
                        FloatingPreviewWindow(
                            participant: videoPositionExchange ? remote : local,
                            // Compact avatar info when the swapped-in remote has its camera off.
                            compact: videoPositionExchange,
                            containerSize: geometry.size,
                            // Insets let the drag range reach the physical screen edges.
                            safeAreaInsets: geometry.safeAreaInsets,
                            onTap: { videoPositionExchange.toggle() }
                        )
                    }
                }
                // Cache the current remote so an empty room can keep showing their avatar.
                .onChange(of: liveRemoteRecipientId()) { newId in
                    if let newId, !newId.isEmpty { lastShownRecipientId = newId }
                }
                // Reset swap when the floating window disappears (camera off) so the main view isn't blank.
                .onChange(of: isLocalCameraOn) { isOn in
                    if !isOn { videoPositionExchange = false }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            // Also reset on reconnect so the main view returns to the remote.
            .onChange(of: roomCtx.isRoomReconnecting) { isReconnecting in
                if isReconnecting { videoPositionExchange = false }
            }
        }
    }
}

extension Room1on1ContentView {

    /// The intended 1v1 peer id (callee for the caller, caller for the callee); nil when empty.
    func nonEmptyOtherSideId() -> String? {
        let id = currentCall.isCaller ? (currentCall.callees?.first ?? "") : (currentCall.caller ?? "")
        return id.isEmpty ? nil : id
    }

    func fetch1on1OthersideParticipant() -> Participant? {
        let otherSideId = currentCall.isCaller ? (currentCall.callees?.first ?? "") : (currentCall.caller ?? "")

        let otherside = room.allParticipants.first(where: { (key: Participant.Identity, value: Participant) in
            let stringIdentity = key.stringValue
            let recipientId = stringIdentity.components(separatedBy: ".").first ?? stringIdentity
            return recipientId == otherSideId
        })

        if let otherside { return otherside.value }

        // Fallback: expected peer not in room (e.g. multi-party where they left) — show the actual remote.
        return room.remoteParticipants.values.first
    }

    /// recipientId of the currently resolved live remote, if any.
    func liveRemoteRecipientId() -> String? {
        guard let identity = fetch1on1OthersideParticipant()?.identity else { return nil }
        let stringIdentity = identity.stringValue
        return stringIdentity.components(separatedBy: ".").first ?? stringIdentity
    }

    /// Static avatar + name for the last-shown peer, used when the room is empty.
    @ViewBuilder
    func lastParticipantAvatar(recipientId: String, geometry: GeometryProxy) -> some View {
        let name = DTLiveKitCallModel.getDisplayName(recipientId: recipientId)
        VStack {
            AvatarImageViewRepresentable(recipientId: recipientId)
                .frame(width: 120, height: 120)
            Text(name)
                .font(.system(size: 17))
                .foregroundColor(.white)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .position(CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2.5))
    }
}

/// 1v1 floating preview: fixed 120×214, corner 8, draggable within the screen.
/// A tap (movement < slop) swaps main/floating content; a drag only moves it.
struct FloatingPreviewWindow: View {

    @ObservedObject var participant: Participant
    var compact: Bool = false
    let containerSize: CGSize
    /// Safe-area insets, used to extend the drag range to the physical screen edges.
    var safeAreaInsets: EdgeInsets = EdgeInsets()
    let onTap: () -> Void

    private let windowSize = CGSize(width: 120, height: 214)
    private let edgeInset: CGFloat = 12
    private let topInset: CGFloat = 40
    /// Tap vs drag threshold: movement below this counts as a tap.
    private let tapSlop: CGFloat = 10

    /// Committed center; nil means use the default top-right position.
    @State private var committedCenter: CGPoint? = nil
    /// Live drag translation.
    @State private var dragTranslation: CGSize = .zero

    var body: some View {
        let baseCenter = committedCenter ?? defaultCenter()
        // Clamp live during drag so the window stops at the edge instead of going off-screen.
        let displayedCenter = clamp(
            CGPoint(
                x: baseCenter.x + dragTranslation.width,
                y: baseCenter.y + dragTranslation.height
            )
        )
        ParticipantView(
            participant: participant,
            is1on1: true,
            compact: compact,
            videoViewMode: .fill
        )
        .frame(width: windowSize.width, height: windowSize.height)
        .position(x: displayedCenter.x, y: displayedCenter.y)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    dragTranslation = value.translation
                }
                .onEnded { value in
                    let moved = hypot(value.translation.width, value.translation.height)
                    if moved < tapSlop {
                        // Tap is consumed here; it won't fall through to the layer below.
                        dragTranslation = .zero
                        onTap()
                    } else {
                        committedCenter = clamp(
                            CGPoint(
                                x: baseCenter.x + value.translation.width,
                                y: baseCenter.y + value.translation.height
                            )
                        )
                        dragTranslation = .zero
                    }
                }
        )
    }

    /// Default position: top-right, edgeInset from the right, topInset below the top.
    private func defaultCenter() -> CGPoint {
        CGPoint(
            x: containerSize.width - windowSize.width / 2 - edgeInset,
            y: topInset + windowSize.height / 2
        )
    }

    /// Clamp the center within the screen (edgeInset margin per side) so the window stays fully visible.
    /// Origin is the safe-area top-left, so insets extend the range to the physical edges — letting it
    /// reach top/bottom like left/right (into the full-screen video under status bar / home indicator).
    private func clamp(_ point: CGPoint) -> CGPoint {
        let halfW = windowSize.width / 2
        let halfH = windowSize.height / 2
        let minX = -safeAreaInsets.leading + halfW + edgeInset
        let maxX = containerSize.width + safeAreaInsets.trailing - halfW - edgeInset
        let minY = -safeAreaInsets.top + halfH + edgeInset
        let maxY = containerSize.height + safeAreaInsets.bottom - halfH - edgeInset
        // max(min, max) guards against range inversion on an unusually small container.
        return CGPoint(
            x: min(max(point.x, minX), max(minX, maxX)),
            y: min(max(point.y, minY), max(minY, maxY))
        )
    }
}


