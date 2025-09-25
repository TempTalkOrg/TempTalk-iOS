//
//  LiveKitContext.swift
//  Difft
//
//  Created by Henry on 2025/5/20.
//  Copyright © 2025 Difft. All rights reserved.
//

import LiveKit
import SwiftUI
import TTMessaging
import AVFAudio
import DenoisePluginFilter

// This class contains the logic to control behavior of the whole app.
public
final class LiveKitContext: ObservableObject {
    
    private let logTag: String = "[newcall][LiveKitContext]"

    @Published var videoViewVisible: Bool = true
    @Published var showInformationOverlay: Bool = false
    @Published var preferSampleBufferRendering: Bool = false
    @Published var videoViewMode: VideoView.LayoutMode = .fit
    @Published var videoViewMirrored: Bool = false

    @Published var videoViewPinchToZoomOptions: VideoView.PinchToZoomOptions = []

    #if os(iOS) || os(visionOS) || os(tvOS)
    // audio session current router output type
    @Published var portType: AVAudioSession.Port = DTRTCAudioSession.shared.currentOutputType() {
        didSet {
            AudioManager.shared.isSpeakerOutputPreferred = (portType == .builtInSpeaker)
        }
    }
    #endif
    // is external audio device connected
    @Published var isExternalConnected: Bool = DTRTCAudioSession.shared.isExternalConnected()

    func setPortTypeAndExternal(_ portType: AVAudioSession.Port, isExternalConnected: Bool) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.setPortTypeAndExternal(portType, isExternalConnected:isExternalConnected) }
            return
        }
        
        self.isExternalConnected = isExternalConnected
        self.portType = portType
    }

    public init() {
        Logger.debug("\(logTag) LiveKitContext init")
    }
}
