//
//  BottomToolbarView.swift
//  TempTalk
//
//  Created by undefined on 22/1/25.
//  Copyright © 2025 Difft. All rights reserved.
//

import SwiftUI
import LiveKit
import TTServiceKit

public struct BottomToolbarView: View {
    
    let logTag: String = "[newcall][bottomControlView]"
    
    let isScreenSharing: Bool
    let containerSize: CGSize
    
    var cameraPublishHandler: (Bool) -> Void
    
    var barClickHandler: () -> Void
    
    var moreClickHandler: () -> Void
    
    @EnvironmentObject var appCtx: LiveKitContext
    @EnvironmentObject var roomCtx: RoomContext
    @EnvironmentObject var room: Room
    
    @State var isCameraPublishingBusy = false
    @State var isMicrophonePublishingBusy = false
    @State var isSpeakerPhoneChangingBusy = false
    
    @Binding var isGroupMembers: Bool
    @Binding var localRaiseHand: Bool
    
    @State private var hasTriggerCloseNoise = false
    @State private var voiceChangerPreset: String = DTMeetingManager.shared.roomContext?.currentVoicePreset() ?? "original"
    
    private var portraitWidth: CGFloat {
        min(containerSize.width, containerSize.height)
    }
    
    private var paddingSpacer: CGFloat {
        ((portraitWidth - 48 * 5) / 6) - 10
    }
    
    public var body: some View {
        HStack {
            if isScreenSharing {
                Spacer().frame(width: max(containerSize.width, containerSize.height) * 0.25)
                
                HStack(spacing: 120) {
                    toolbarButtonGroup
                    endCallButton
                }
                
                Spacer().frame(width: 19)
                
            } else {
                Spacer()
                
                HStack(spacing: paddingSpacer) {
                    toolbarButtonGroup
                    endCallButton
                }

                Spacer()
            }
        }
    }
    
    private var toolbarButtonGroup: some View {
        
        return HStack(spacing: paddingSpacer) {
            micButton
            cameraButton
            speakerOrPickerButton
            if isScreenSharing { memberButton }
            moreButton
        }
    }
    
    @ViewBuilder
    private func toolbarCircleButton(
        size: CGFloat = 48,
        image: Image,
        action: @escaping () -> Void
    ) -> some View {
        Circle()
            .fill(.clear)
            .frame(width: size, height: size)
            .overlay(
                Button(action: action) {
                    image
                        .resizable()
                        .scaledToFit()
                }
            )
    }
    
    private var isVoiceChangerActive: Bool {
        voiceChangerPreset != "original"
    }

    private var voiceChangerEmoji: String {
        DTUpdateNoiseController.voicePresets.first(where: { $0.key == voiceChangerPreset })?.emoji ?? ""
    }

    private var micButton: some View {
        let isMicEnabled = room.localParticipant.isMicrophoneEnabled()
        return ZStack(alignment: .topTrailing) {
            Circle()
                .fill(.clear)
                .frame(width: 48, height: 48)
                .overlay(
                    Button(action: {
                        Logger.info("\(logTag) mic pressed isMicEnabled \(isMicEnabled)")
                        barClickHandler()
                        didTapMicrophone(isMicrophoneEnabled: isMicEnabled)
                    }) {
                        Image(isMicEnabled ? "ic_call_microphone_enable" : "ic_call_microphone_disable")
                            .resizable()
                            .scaledToFit()
                    }
                )
                .overlay(
                    isVoiceChangerActive
                        ? Circle().stroke(
                            LinearGradient(
                                colors: [Color(hex: 0x328AFD), Color(hex: 0x0891B2)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 2
                        )
                        : nil
                )

            if isVoiceChangerActive, !voiceChangerEmoji.isEmpty {
                Text(voiceChangerEmoji)
                    .font(.system(size: 10))
                    .frame(width: 18, height: 18)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0x328AFD), Color(hex: 0x0891B2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .offset(x: 2, y: -2)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .voiceChangerPresetDidChange)) { _ in
            voiceChangerPreset = DTMeetingManager.shared.roomContext?.currentVoicePreset() ?? "original"
        }
        .onDisappear { hasTriggerCloseNoise = false }
    }

    private var cameraButton: some View {
        let isCameraEnabled = room.localParticipant.isCameraEnabled()
        return toolbarCircleButton(
            image: Image(isCameraEnabled ? "ic_call_camera_enable" : "ic_call_camera_disable")
        ) {
            Logger.info("\(logTag) camera pressed")
            barClickHandler()
            didTapCamera(isCameraEnabled: isCameraEnabled)
        }
    }

    @ViewBuilder
    private var speakerOrPickerButton: some View {
        if appCtx.isExternalConnected {
            RoutePickerView(portType: appCtx.portType)
                .frame(width: 48, height: 48)
        } else {
            let speakerEnabled = appCtx.portType == .builtInSpeaker
            toolbarCircleButton(
                image: speakerEnabled ? Image("ic_call_speaker") : Image("ic_call_phone")
            ) {
                barClickHandler()
                isSpeakerPhoneChangingBusy = true
                defer { Task { @MainActor in isSpeakerPhoneChangingBusy = false } }
                let newSpeakerState = !speakerEnabled
                Logger.info("\(logTag) pressed speaker: \(speakerEnabled) -> \(newSpeakerState)")
                DTRTCAudioSession.shared.switchToSpeaker(newSpeakerState)
            }
        }
    }

    private var memberButton: some View {
        ZStack {
            toolbarCircleButton(image: Image("ic_call_members")) {
                Logger.info("\(logTag) members pressed")
                barClickHandler()
                guard case .connected = room.connectionState else {
                    DTToastHelper.showCallToast("Invite others only after joining.")
                    return
                }
                isGroupMembers.toggle()
            }
            if isScreenSharing {
                BadgeView(room: _room).offset(x: 20, y: 15)
            }
        }
    }

    private var moreButton: some View {
        toolbarCircleButton(image: Image("ic_call_more")) {
            moreClickHandler()
        }
    }
    
    @ViewBuilder
    private var endCallButton: some View {
        if DTMeetingManager.shared.currentCall.callType == .private {
            toolbarCircleButton(image: Image("ic_call_hangup")) {
                Logger.info("\(logTag) End Call pressed")
                Task { await roomCtx.toolbarEndCallTaped() }
            }
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(rgbHex: 0x1E2329))
                    .frame(width: 78, height: 48)
                
                HStack {
                    toolbarCircleButton(
                        image: Image("ic_call_exit")) {
                        Logger.info("\(logTag) End Call pressed")
                        Task { await roomCtx.toolbarEndCallTaped() }
                    }
                    
                    Button(action: {
                        roomCtx.presentHangupActionSheet()
                    }) {
                        Image("tabler_chevron-right")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .padding(2)
                    }
                    .padding(.trailing, 6)
                }
            }
        }
    }
    
    func didTapMicrophone(isMicrophoneEnabled: Bool) {
        if !isMicrophoneEnabled {
            if let metadata = RoomDataProcessor.parseMetadata(from: room),
               !metadata.canPublishAudio {
                if room.localParticipant.localAudioTracks.isEmpty {
                    DTToastHelper.showCallToast(Localized("TTCALL_STREAM_LIMIT"))
                    return
                }
            }
        }
        
        let localParticipant = room.localParticipant
        let portName = roomCtx.lastPortName ?? ""
        Task {
            isMicrophonePublishingBusy = true
            defer { Task { @MainActor in isMicrophonePublishingBusy = false } }

            do {
                try await localParticipant.setMicrophone(enabled: !isMicrophoneEnabled)

                if !isMicrophoneEnabled, !hasTriggerCloseNoise, DTMeetingManager.shared.isInputAirPods(portName: portName) {
                    hasTriggerCloseNoise = true
                    DTMeetingManager.shared.roomContext?.setDenoiseFilter(enabled: false)
                }
                Logger.info("\(logTag) Successfully Microphone muted track \(isMicrophoneEnabled)")
                RoomDataManager.shared.updateSeakingParticipant()
            } catch {
                Logger.error("\(logTag) Failed to Microphone mute track: \(error)")
            }

            DTMeetingManager.shared.roomContext?.syncLocalMicrophoneStateToCallKit(muted: isMicrophoneEnabled)
        }
    }
    
    func didTapCamera(isCameraEnabled: Bool) {
        if !isCameraEnabled {
            if let metadata = RoomDataProcessor.parseMetadata(from: room),
                !metadata.canPublishVideo {
                if room.localParticipant.localVideoTracks.isEmpty {
                    DTToastHelper.showCallToast(Localized("TTCALL_STREAM_LIMIT"))
                    return
                }
            }
        }
        
        DTMeetingManager.shared.openCallCamera = !isCameraEnabled
        
        let localParticipant = room.localParticipant
        Task {
            isCameraPublishingBusy = true
            defer { Task { @MainActor in isCameraPublishingBusy = false } }
            if let track = localParticipant.firstCameraVideoTrack as? LocalVideoTrack,
               let cameraCapturer = track.capturer as? CameraCapturer,
               cameraCapturer.position != .front {
                try await cameraCapturer.switchCameraPosition()
            }
            
            try await localParticipant.setCamera(enabled: !isCameraEnabled)
            
            cameraPublishHandler(!isCameraEnabled)
        }
    }
}

struct BadgeView: View {
    
    @EnvironmentObject var room: Room

    var body: some View {
        Text("\(room.allParticipants.keys.count)")
            .font(.caption)
            .fontWeight(.bold)
            .padding(6)
            .background(Color.init(hex: 0x5e6673))
            .foregroundColor(.white)
            .clipShape(Circle())
            .padding(4)
    }
}

