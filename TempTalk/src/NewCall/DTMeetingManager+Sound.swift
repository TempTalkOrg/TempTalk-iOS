//
//  DTMeetingManager+Sound.swift
//  Difft
//
//  Created by Henry on 2025/7/2.
//  Copyright © 2025 Difft. All rights reserved.
//

extension DTMeetingManager {
    func playSound(_ sound: OWSSound, isLoop: Bool = true, playMode: AudioPlayMode) {
        // OWSAudioPlayer 的 play 系列方法内部有 OWSAssertIsOnMainThread，
        // async/await continuation 回到非主线程 executor 调用会触发断言崩溃。
        DispatchMainThreadSafe { [self] in
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
