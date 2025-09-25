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
    var videoViewMode: VideoView.LayoutMode = .fit

    @State private var isRendering: Bool = false
    @State private var cachedIdentity: String?
    
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
        Logger.info("[swiftUI] participent identity component")
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
                
                // VideoView for the Participant
                if let publication = participant.firstCameraPublication,
                   !publication.isMuted,
                   let track = publication.track as? VideoTrack,
                   liveKitCtx.videoViewVisible
                {
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
                    let recipientId = recipientId(participant)
                    if is1on1 {
                        let participantName = DTLiveKitCallModel.getDisplayName(recipientId: recipientId)
                        VStack() {
                            AvatarImageViewRepresentable(recipientId: recipientId)
                                .frame(width: 120, height: 120)
                            
                            Text(participantName)
                                .font(.system(size: 17))
                                .foregroundColor(.white)
                                .padding(.top, 10)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .position(CGPoint(x: geometry.size.width / 2, y: geometry.size.height/2.5))
                    } else {
                        AvatarImageViewRepresentable(recipientId: recipientId)
                            .padding(EdgeInsets(top: 20, leading: 22, bottom: 24, trailing: 22))
                    }
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
                                // is remote
                                if let remotePub = publication as? RemoteTrackPublication {
                                    if case .subscribed = remotePub.subscriptionState {
                                        Image(uiImage: UIImage(named: "ic_call_unmuted")!)
                                            .frame(width: 16, height: 16)
                                            .onLongPressGesture {
                                                DTMeetingManager.shared.roomContext?.presentMuteActionSheet(participant)
                                            }
                                    } else {
                                        Image(uiImage: UIImage(named: "call_ic_muted")!)
                                            .frame(width: 16, height: 16)
                                    }
                                } else {
                                    // local
                                    Image(uiImage: UIImage(named: "ic_call_unmuted")!)
                                        .frame(width: 16, height: 16)
                                        .onLongPressGesture {
                                            DTMeetingManager.shared.roomContext?.presentMuteActionSheet(participant)
                                        }
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
            .overlay(
                // 解决mute后蓝框不及时消失问题
                !is1on1 ? Group {
                    if let publication = participant.firstAudioPublication, publication.isMuted {
                        EmptyView()
                    } else if participant.isSpeaking {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.lkBlue, lineWidth: 3)
                    } else {
                        EmptyView()
                    }
                } : nil
            ).onAppear {
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
        HStack(alignment: .top, spacing: 5) {
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

                // if let trackStats = viewModel.statistics {
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
}

extension Color {
    
    init(hex: Int, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
    
}
    


