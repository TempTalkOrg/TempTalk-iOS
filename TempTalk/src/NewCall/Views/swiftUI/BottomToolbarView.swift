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
    
    let paddingSpacer = ((min(screenWidth, screenHeight) - 48 * 5) / 6) - 10
    
    public var body: some View {
        HStack {
            if isScreenSharing {
                Spacer().frame(width: max(screenWidth, screenHeight) * 0.25)
                
                HStack(spacing: 120) {   // 👈 控制间距
                    toolbarButtonGroup
                    endCallButton
                }
                
                Spacer().frame(width: 19)
                
            } else {
                Spacer()
                
                HStack(spacing: paddingSpacer) {   // 👈 控制间距
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
        VStack {
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
    }
    
    private var micButton: some View {
        let isMicEnabled = room.localParticipant.isMicrophoneEnabled()
        return toolbarCircleButton(
            image: Image(isMicEnabled ? "ic_call_microphone_enable" : "ic_call_microphone_disable")
        ) {
            Logger.info("\(logTag) mic pressed")
            barClickHandler()
            didTapMicrophone(isMicrophoneEnabled: isMicEnabled)
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

    private var speakerOrPickerButton: some View {
        Group {
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
                    DTRTCAudioSession.shared.switchToSpeaker(!speakerEnabled)
                    Logger.info("\(logTag) speaker pressed \(speakerEnabled ? "on" : "off")")
                }
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
    
    private var endCallButton: some View {
        VStack {
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
        
        Task {
            isMicrophonePublishingBusy = true
            defer { Task { @MainActor in isMicrophonePublishingBusy = false } }

            do {
                try await room.localParticipant.setMicrophone(enabled: !isMicrophoneEnabled)

                let portName = roomCtx.lastPortName ?? ""
                if !isMicrophoneEnabled, !hasTriggerCloseNoise, DTMeetingManager.shared.isInputAirPods(portName: portName) {
                    hasTriggerCloseNoise = true
                    DTMeetingManager.shared.roomContext?.setDenoiseFilter(enabled: false)
                }
                Logger.info("\(logTag) Successfully Microphone muted track \(isMicrophoneEnabled)")
            } catch {
                Logger.error("\(logTag) Failed to Microphone mute track: \(error)")
            }

            roomCtx.syncLocalMicrophoneStateToCallKit(muted: isMicrophoneEnabled)
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
        
        Task {
            isCameraPublishingBusy = true
            defer { Task { @MainActor in isCameraPublishingBusy = false } }
            if let track = room.localParticipant.firstCameraVideoTrack as? LocalVideoTrack,
               let cameraCapturer = track.capturer as? CameraCapturer,
               cameraCapturer.position != .front {
                try await cameraCapturer.switchCameraPosition()
            }
            
            let captureOptions = CameraCaptureOptions(
                dimensions: .h720_169,
                fps: 30
            )
            let publishOptions = VideoPublishOptions(
                encoding: VideoParameters.presetH1080_169.encoding
            )
            try await room.localParticipant.setCamera(enabled: !isCameraEnabled, captureOptions: captureOptions, publishOptions: publishOptions)
            
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

