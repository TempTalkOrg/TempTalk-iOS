//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import AVFoundation
import Foundation

@objc(OWSAudioActivity)
public class AudioActivity: NSObject {
    let audioDescription: String

    override public var description: String {
        "<\(logTag) audioDescription: \"\(audioDescription)\">"
    }

    @objc
    public init(audioDescription: String) {
        self.audioDescription = audioDescription
    }

    deinit {
        OWSAudioSession.shared.ensureAudioSessionActivationStateAfterDelay()
    }
}

@objc
public class OWSAudioSession: NSObject {
    // Force singleton access
    @objc public static let shared = OWSAudioSession()

    private let avAudioSession = AVAudioSession.sharedInstance()

    private var currentActivities = NSHashTable<AnyObject>.weakObjects()

    @objc public var inCalling = false

    public let rtcCategory: AVAudioSession.Category = .playAndRecord
    public let rtcCategoryPlayBack: AVAudioSession.Category = .playback
    #if swift(>=6.2)
    public let rtcCategoryOptions: AVAudioSession.CategoryOptions = [.mixWithOthers, .allowBluetoothHFP, .allowBluetoothA2DP, .allowAirPlay]
    #else
    public let rtcCategoryOptions: AVAudioSession.CategoryOptions = [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP, .allowAirPlay]
    #endif
    // Options for Playback category used during in-call "mic-off speakerphone" listening.
    //
    // IMPORTANT: do NOT add .allowBluetoothA2DP / .allowAirPlay / .allowBluetoothHFP here.
    // Those options are valid ONLY on the playAndRecord category — setting them on Playback
    // makes iOS reject the configuration with AVAudioSessionErrorCodeUnspecified ('what',
    // OSStatus 2003329396).
    //
    // Bluetooth A2DP and AirPlay output are implicitly supported by the Playback category
    // (per Apple docs), so once an A2DP profile is actually established (e.g. user takes
    // AirPods out of the case), it shows up in currentRoute.outputs automatically — no
    // option needed.
    public let rtcCategoryPlaybackOptions: AVAudioSession.CategoryOptions = [.mixWithOthers]

    public let rtcModeVoice: AVAudioSession.Mode = .voiceChat
    public let rtcModeVideo: AVAudioSession.Mode = .videoChat
    public let rtcModeSpoken: AVAudioSession.Mode = .spokenAudio

    public static func inCallSessionSupportsRecording(
        category: AVAudioSession.Category,
        isInputAvailable: Bool
    ) -> Bool {
        return category == .playAndRecord && isInputAvailable
    }

    // Ignores hardware mute switch, plays through external speaker
    @objc
    public func startPlaybackAudioActivity(_ audioActivity: AudioActivity) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        Logger.debug("inCalling: \(inCalling)")

        insertActivity(audioActivity)

        if inCalling {
            return
        }

        do {
            try avAudioSession.setCategory(.playback)
            // try avAudioSession.setActive(true)
        } catch {
            owsFailDebug("failed with error: \(error)")
        }
    }

    @objc
    public func startPlayAndRecordAudioActivity(_ audioActivity: AudioActivity) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        Logger.debug("inCalling: \(inCalling)")

        insertActivity(audioActivity)

        if inCalling {
            return
        }

        do {
            try avAudioSession.setCategory(rtcCategory, options: rtcCategoryOptions)
            // try avAudioSession.setActive(true)
        } catch {
            owsFailDebug("failed with error: \(error)")
        }
    }

    @objc
    public func startRecordingAudioActivity(_ audioActivity: AudioActivity) -> Bool {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        Logger.debug("inCalling: \(inCalling)")

        assert(avAudioSession.recordPermission == .granted)

        insertActivity(audioActivity)

        if inCalling {
            if Self.inCallSessionSupportsRecording(
                category: avAudioSession.category,
                isInputAvailable: avAudioSession.isInputAvailable
            ) {
                return true
            }

            do {
                Logger.warn("repair recording activity while inCalling with non-recording audio session: category=\(avAudioSession.category.rawValue), mode=\(avAudioSession.mode.rawValue), inputs=\(avAudioSession.currentRoute.inputs.count)")
                try avAudioSession.setCategory(rtcCategory, options: rtcCategoryOptions)
                return true
            } catch {
                Logger.error("failed to repair in-call recording audio session: \(error)")
                return false
            }
        }

        do {
            try avAudioSession.setCategory(.record)
            try avAudioSession.setActive(true)

            return true
        } catch {
            owsFailDebug("failed with error: \(error)")
            return false
        }
    }

    @objc
    public func startAudioActivity(_ audioActivity: AudioActivity) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        Logger.debug("inCalling: \(inCalling)")

        insertActivity(audioActivity)
    }

    @objc
    public func endAudioActivity(_ audioActivity: AudioActivity, force: Bool = false) {
        objc_sync_enter(self)
        defer { objc_sync_exit(self) }

        let hasActivity = currentActivities.contains(audioActivity)

        Logger.debug("inCalling: \(inCalling), hasActivity: \(hasActivity), audioActivity: \(audioActivity.description)")

        if hasActivity {
            currentActivities.remove(audioActivity)
            ensureAudioSessionActivationState(force)
        }
    }

    fileprivate func ensureAudioSessionActivationStateAfterDelay() {
        // Without this delay, we sometimes error when deactivating the audio session with:
        //     Error Domain=NSOSStatusErrorDomain Code=560030580 “The operation couldn’t be completed. (OSStatus error 560030580.)”
        // aka "AVAudioSessionErrorCodeIsBusy"
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            objc_sync_enter(self)
            defer { objc_sync_exit(self) }

            Logger.debug("")

            self.ensureAudioSessionActivationState(false)
        }
    }

    private func ensureAudioSessionActivationState(_ force: Bool) {
        guard currentActivities.count == 0 || force else {
            Logger.debug("ignore deactivating: force: \(force), currentActivities: \(currentActivities)")
            return
        }

        guard !inCalling || force else {
            Logger.debug("ignore inCalling deactivating: force: \(force), inCalling: \(inCalling), currentActivities: \(currentActivities)")
            return
        }

        do {
            Logger.debug("deactive: inCalling: \(inCalling), force; \(force)")

            // When playing audio in Signal, other apps audio (e.g. Music) is paused.
            // By notifying when we deactivate, the other app can resume playback.
            try avAudioSession.setCategory(.soloAmbient, mode: .default, options: [])
            try avAudioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Logger.error("failed with error: \(error)")
        }
    }

    private func insertActivity(_ audioActivity: AudioActivity) {
        let hasActivity = currentActivities.contains(audioActivity)

        Logger.debug("hasActivity; \(hasActivity), insert: \(audioActivity.description)")

        if !hasActivity {
            currentActivities.add(audioActivity)
        }
    }
}
