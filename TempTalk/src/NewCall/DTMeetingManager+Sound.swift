//
//  DTMeetingManager+Sound.swift
//  Difft
//
//  Created by Henry on 2025/7/2.
//  Copyright © 2025 Difft. All rights reserved.
//

extension DTMeetingManager {
    func playSound(_ sound: OWSSound, isLoop: Bool = true, playMode: AudioPlayMode) {
        
        Logger.info("play sound: --\(OWSSounds.displayName(for: sound))")
        stopSound()

        let player = OWSSounds.audioPlayer(for: sound)
        player?.isLooping = isLoop
        
        if playMode == .playback {
            player?.playWithPlaybackAudioCategory()
        } else if playMode == .playAndRecord {
            player?.playWithPlayAndRecordAudioCategory()
        } else {
            player?.playWithCurrentAudioCategory()
        }
        
        self.audioPlayer = player
    }
        
    func stopSound() {
        DispatchMainThreadSafe { [self] in
            if let audioPlayer {
                audioPlayer.stop()
                self.audioPlayer = nil
            }
        }
    }
}
