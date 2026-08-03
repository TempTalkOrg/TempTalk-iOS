/*
 * Copyright 2024 LiveKit
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import LiveKit
import SFSafeSymbols
import SwiftUI
import Lottie
import TTServiceKit

struct ParticipantView: View {
    @ObservedObject var participant: Participant
    @EnvironmentObject var liveKitCtx: LiveKitContext

    var is1on1: Bool = false
    /// Compact avatar info for the 1v1 floating window.
    var compact: Bool = false
    var videoViewMode: VideoView.LayoutMode = .fit

    @State private var isRendering: Bool = false
    @State private var didRenderFirstFrame: Bool = false
    @State private var cachedIdentity: String?
    @State private var cameraUnmuteCounter: Int = 0
    @State private var previousCameraMuted: Bool? = nil
    
    func recipientId(_ participant: Participant) -> String {
        guard let identity = participant.identity else {
            Logger.info("[swiftUI] participent identity is Empty")
            return cachedIdentity ?? ""
        }
        
        let stringIdentity = identity.stringValue
        guard let recipientId = stringIdentity.components(separatedBy: ".").first else {
            Logger.info("[swiftUI] participent identity")
            return stringIdentity
        }
        return recipientId
    }
    
    var body: some View {
        GeometryReader { geometry in

            ZStack(alignment: .bottomLeading) {
                // Background color
                if is1on1 {
                    Color.dtBackground
                } else {
                    Color(hex:0x181A20)
                }
                
                if let publication = participant.firstCameraPublication,
                   let track = publication.track as? VideoTrack,
                   liveKitCtx.videoViewVisible
                {
                    ZStack {
                        SwiftUIVideoView(
                            track,
                            layoutMode: videoViewMode,
                            mirrorMode: liveKitCtx.videoViewMirrored ? .mirror : .auto,
                            renderMode: liveKitCtx.preferSampleBufferRendering ? .sampleBuffer : .auto,
                            pinchToZoomOptions: liveKitCtx.videoViewPinchToZoomOptions,
                            isDebugMode: liveKitCtx.showInformationOverlay,
                            keepLastFrameOnTrackChange: true,
                            isRendering: $isRendering,
                            didRenderFirstFrame: $didRenderFirstFrame
                        )
                        .id(cameraUnmuteCounter)
                        .ignoresSafeArea()

                        // Only show the loading spinner before the very first frame.
                        // After the first frame, weak-network stalls/reconnect keep the last
                        // frame frozen (no spinner).
                        if !didRenderFirstFrame && !publication.isMuted {
                            ProgressView().progressViewStyle(CircularProgressViewStyle())
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }

                        // Opaque avatar overlay when muted (renderer stays alive underneath)
                        if publication.isMuted {
                            mutedAvatarOverlay(geometry: geometry)
                        }
                    }
                } else {
                    noTrackAvatarView(geometry: geometry)
                }

                if liveKitCtx.showInformationOverlay {
                    VStack(alignment: .leading, spacing: 5) {
                        // Video stats
                        if let publication = participant.mainVideoPublication,
                           !publication.isMuted,
                           let track = publication.track as? VideoTrack
                        {
                            StatsView(track: track)
                        }
                        // Audio stats
                        if let publication = participant.firstAudioPublication,
                           !publication.isMuted,
                           let track = publication.track as? AudioTrack
                        {
                            StatsView(track: track)
                        }
                    }
                    .padding(8)
                    .frame(
                        minWidth: 0,
                        maxWidth: .infinity,
                        minHeight: 0,
                        maxHeight: .infinity,
                        alignment: .topLeading
                    )
                }
                
                if !is1on1 {
                    // Bottom user info bar
                    HStack(spacing: 4) {
                        if let publication = participant.firstAudioPublication,
                           !publication.isMuted {
                            if participant.isSpeaking {
                                LottieView(animation: .named("Meeting_audio")
                                )
                                .playing(loopMode: .loop)
                                .frame(width: 16, height: 16)
                                .onLongPressGesture {
                                    DTMeetingManager.shared.roomContext?.presentMuteActionSheet(participant)
                                }
                            } else {
                                Image(uiImage: UIImage(named: "ic_call_unmuted")!)
                                    .frame(width: 16, height: 16)
                                    .onLongPressGesture {
                                        DTMeetingManager.shared.roomContext?.presentMuteActionSheet(participant)
                                    }
                            }
                        } else {
                            Image(uiImage: UIImage(named: "call_ic_muted")!)
                                .frame(width: 16, height: 16)
                        }
                        
                        let recipientId = recipientId(participant)
                        let participantName = DTLiveKitCallModel.getDisplayName(recipientId: recipientId)
                        Text(String(describing: participantName))
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .padding(6)
                    .background(
                        Color.dtBackground.opacity(0.8)
                            .cornerRadius(4)
                    )
                    .padding(.leading, 5)
                    .padding(.bottom, 5)
                    .frame(maxWidth: geometry.size.width - 10, alignment: .leading)
                }
            }
            .cornerRadius(8)
            .overlay(speakingBorderOverlay)
            .onAppear {
                if cachedIdentity == nil, let id = participant.identity {
                    cachedIdentity = id.stringValue.components(separatedBy: ".").first
                }
            }
            .onChange(of: participant.identity) { newValue in
                if let newValue = newValue {
                    cachedIdentity = newValue.stringValue.components(separatedBy: ".").first
                }
                // 如果变成 nil，什么都不做，保留旧值
            }
            .onChange(of: participant.firstCameraPublication?.isMuted) { isMuted in
                defer { previousCameraMuted = isMuted }
                guard previousCameraMuted == true, isMuted == false else { return }
                cameraUnmuteCounter += 1
            }
        }
    }
    
    @ViewBuilder
    private func mutedAvatarOverlay(geometry: GeometryProxy) -> some View {
        let recipientId = recipientId(participant)
        if is1on1 {
            // Opaque background over the live renderer, then avatar info.
            Color.dtBackground
            avatar1on1Column(geometry: geometry)
        } else {
            Color(hex: 0x181A20)
            AvatarImageViewRepresentable(recipientId: recipientId)
                .padding(EdgeInsets(top: 20, leading: 22, bottom: 24, trailing: 22))
        }
    }

    @ViewBuilder
    private func noTrackAvatarView(geometry: GeometryProxy) -> some View {
        let recipientId = recipientId(participant)
        if is1on1 {
            avatar1on1Column(geometry: geometry)
        } else {
            AvatarImageViewRepresentable(recipientId: recipientId)
                .padding(EdgeInsets(top: 20, leading: 22, bottom: 24, trailing: 22))
        }
    }

    /// 1v1 avatar column: full-size by default, scaled down + mic status when compact.
    @ViewBuilder
    private func avatar1on1Column(geometry: GeometryProxy) -> some View {
        let recipientId = recipientId(participant)
        let participantName = DTLiveKitCallModel.getDisplayName(recipientId: recipientId)
        if compact {
            VStack(spacing: 4) {
                AvatarImageViewRepresentable(recipientId: recipientId)
                    .frame(width: 48, height: 48)

                HStack(spacing: 2) {
                    micStatusIcon(size: 10)

                    Text(truncatedName(participantName, maxChars: 8))
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
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
        }
    }

    /// Mic status icon: muted / silent / speaking.
    @ViewBuilder
    private func micStatusIcon(size: CGFloat) -> some View {
        if let publication = participant.firstAudioPublication, !publication.isMuted {
            if participant.isSpeaking {
                LottieView(animation: .named("Meeting_audio"))
                    .playing(loopMode: .loop)
                    .frame(width: size, height: size)
                    .padding(1)
            } else {
                Image(uiImage: UIImage(named: "ic_call_unmuted") ?? UIImage())
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .padding(1)
            }
        } else {
            Image(uiImage: UIImage(named: "call_ic_muted") ?? UIImage())
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .padding(1)
        }
    }

    /// Truncate name to maxChars with a trailing ellipsis.
    private func truncatedName(_ name: String, maxChars: Int) -> String {
        guard name.count > maxChars else { return name }
        return String(name.prefix(maxChars)) + "…"
    }

    @ViewBuilder
    private var speakingBorderOverlay: some View {
        if !is1on1, let publication = participant.firstAudioPublication, !publication.isMuted, participant.isSpeaking {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.lkBlue, lineWidth: 3)
        }
    }
}

struct StatsView: View {
    private let track: Track
    @ObservedObject private var observer: TrackDelegateObserver

    init(track: Track) {
        self.track = track
        observer = TrackDelegateObserver(track: track)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if track is VideoTrack {
                HStack(spacing: 3) {
                    Image(systemSymbol: .videoFill)
                    Text("Video").fontWeight(.bold)
                    if let dimensions = observer.dimensions {
                        Text("\(dimensions.width)×\(dimensions.height)")
                    }
                }
            } else if track is AudioTrack {
                HStack(spacing: 3) {
                    Image(systemSymbol: .micFill)
                    Text("Audio").fontWeight(.bold)
                }
            } else {
                Text("Unknown").fontWeight(.bold)
            }

            ForEach(observer.allStatisticts, id: \.self) { trackStats in
                ForEach(trackStats.outboundRtpStream.sortedByRidIndex()) { stream in
                    HStack(spacing: 3) {
                        Image(systemSymbol: .arrowUp)

                        if let codec = trackStats.codec.first(where: { $0.id == stream.codecId }) {
                            Text(codec.mimeType ?? "?")
                        }

                        if let rid = stream.rid, !rid.isEmpty {
                            Text(rid.uppercased())
                        }

                        Text(stream.formattedBps())

                        if let reason = stream.qualityLimitationReason, reason != QualityLimitationReason.none {
                            Image(systemSymbol: .exclamationmarkTriangleFill)
                            Text(reason.rawValue.capitalized)
                        }
                    }
                }
                ForEach(trackStats.inboundRtpStream) { stream in
                    HStack(spacing: 3) {
                        Image(systemSymbol: .arrowDown)

                        if let codec = trackStats.codec.first(where: { $0.id == stream.codecId }) {
                            Text(codec.mimeType ?? "?")
                        }

                        Text(stream.formattedBps())
                    }
                }
            }
        }
        .font(.system(size: 10))
        .foregroundColor(Color.white)
        .padding(5)
        .background(Color.black.opacity(0.5))
        .cornerRadius(8)
    }
}

extension Color {
    
    init(hex: Int, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
    
}
    


