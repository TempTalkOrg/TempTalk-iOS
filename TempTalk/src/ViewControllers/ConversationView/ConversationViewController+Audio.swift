//
//  ConversationViewController+Audio.swift
//  Signal
//
//  Created by Jaymin on 2024/1/23.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import AVFoundation
import CoreServices
import TTMessaging
import TTServiceKit

// MARK: - Audio Player

extension ConversationViewController {
    private var audioPlayer: OWSAudioPlayer? {
        get {
            viewState.audioPlayer
        }
        set {
            viewState.audioPlayer = newValue
        }
    }
    
    func resumeAudioPlayer(viewItem: ConversationViewItem, attachmentStream: TSAttachmentStream) {
        playOrPauseAudioPlayer(viewItem: viewItem, attachmentStream: attachmentStream)
    }
    
    @objc func stopAudioPlayer() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    private func playOrPauseAudioPlayer(viewItem: ConversationViewItem, attachmentStream: TSAttachmentStream) {
        AssertIsOnMainThread()
        
        // 选中的音频就是当前播放器正在使用的
        if let audioPlayer, let owner = audioPlayer.owner as? String, owner == viewItem.interaction.uniqueId {
            audioPlayer.togglePlayState()
            return
        }
        
        // 第一次播放，或者当前选中音频和播放器正在使用的不同
        let filePath = attachmentStream.filePath()
        guard let filePath, FileManager.default.fileExists(atPath: filePath) else {
            Logger.error("Missing audio file: \(filePath ?? "file path not found")")
            return
        }
        if let _ = audioPlayer {
            stopAudioPlayer()
        }
        guard let mediaURL = attachmentStream.mediaURL() else {
            return
        }
        audioPlayer = OWSAudioPlayer(mediaUrl: mediaURL, delegate: viewItem)
        // Associate the player with this media adapter.
        audioPlayer?.owner = viewItem.interaction.uniqueId as AnyObject
        audioPlayer?.playWithPlaybackAudioCategory()
    }
}

// MARK: - Audio Recorder

extension ConversationViewController {
    private var audioRecorder: DTAudioRecorder? {
        get { viewState.audioRecorder }
        set {
            if let newValue {
                DeviceSleepManager.shared.addBlock(blockObject: newValue)
            } else if let oldValue = viewState.audioRecorder {
                DeviceSleepManager.shared.removeBlock(blockObject: oldValue)
            }
            viewState.audioRecorder = newValue
        }
    }
    
    private var voiceMessageUUID: UUID? {
        get { viewState.voiceMessageUUID }
        set { viewState.voiceMessageUUID = newValue }
    }
    
    func requestRecordingVoiceMemo() {
        AssertIsOnMainThread()
        
        let voiceMessageUUID = UUID()
        self.voiceMessageUUID = voiceMessageUUID
        
        ows_ask(forMicrophonePermissions: { [weak self] isGranted in
            guard let self else { return }
            
            guard self.voiceMessageUUID == voiceMessageUUID else {
                // This voice message recording has been cancelled
                // before recording could begin.
                return
            }
            
            if isGranted {
                self.startRecordingVoiceMemo()
            } else {
                Logger.info("we do not have recording permission.")
                self.cancelVoiceMemo()
                self.ows_showNoMicrophonePermissionActionSheet()
            }
        })
    }
    
    func cancelVoiceMemo() {
        AssertIsOnMainThread()
        
        self.inputToolbar.hideVoiceMemoUI(animated: false)
        cancelRecordingVoiceMemo()
    }
    
    func startRecordingVoiceMemo() {
        AssertIsOnMainThread()
        
        // Cancel any ongoing audio playback.
        stopAudioPlayer()
        
        let temporaryDirectory = OWSTemporaryDirectory()
        let fileName = "\(Date.ows_millisecondTimestamp()).m4a"
        let fileURL = URL(fileURLWithPath: temporaryDirectory).appendingPathComponent(fileName)
                
        // Setup audio session
        let configuredAudio = self.audioSession.startRecordingAudioActivity(self.recordVoiceNoteAudioActivity)
        if !configuredAudio {
            owsFailDebug("Couldn't configure audio session")
            cancelVoiceMemo()
            return
        }
        
        let audioRecorder: DTAudioRecorder
        do {
            audioRecorder = try DTAudioRecorder(
                url: fileURL,
                settings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderBitRateKey: 128 * 1024
                ],
                mode: .avAudioRecorder
            )
            self.audioRecorder = audioRecorder
        } catch {
            owsFailDebug("Couldn't create audioRecorder: \(error)")
            cancelVoiceMemo()
            return
        }
        audioRecorder.isMeteringEnabled = true
        
        if !audioRecorder.prepareToRecord() {
            owsFailDebug("audioRecorder couldn't prepareToRecord.")
            cancelVoiceMemo()
            return
        }

        if !audioRecorder.record() {
            owsFailDebug("audioRecorder couldn't record.")
            cancelVoiceMemo()
            return
        }
}
    
    func endRecordingVoiceMemo() {
        AssertIsOnMainThread()
        
        self.voiceMessageUUID = nil
        
        guard let audioRecorder else {
            // No voice message recording is in progress.
            // We may be cancelling before the recording could begin.
            Logger.error("Missing audioRecorder")
            return
        }
        
        let durationSeconds = audioRecorder.currentTime
        
        stopRecording()
        
        let kMinimumRecordingTimeSeconds: TimeInterval = 1.0
        if durationSeconds < kMinimumRecordingTimeSeconds {
            Logger.info("Discarding voice message too short.")
            self.audioRecorder = nil
            
            dismissKeyBoard()
            
            OWSActionSheets.showActionSheet(
                title: Localized("VOICE_MESSAGE_TOO_SHORT_ALERT_TITLE"),
                message: Localized("VOICE_MESSAGE_TOO_SHORT_ALERT_MESSAGE")
            )
            
            return
        }
        
        let dataSource: DataSource
        do {
            dataSource = try DataSourcePath.dataSource(
                with: audioRecorder.url,
                shouldDeleteOnDeallocation: true
            )
            self.audioRecorder = nil
        } catch {
            owsFailDebug("Couldn't load audioRecorder data: \(error.localizedDescription)")
            self.audioRecorder = nil
            return
        }
        
        let fileName = Localized("VOICE_MESSAGE_FILE_NAME") + ".m4a"
        dataSource.sourceFilename = fileName
        
        let attachment = SignalAttachment.voiceMessageAttachment(
            dataSource: dataSource,
            dataUTI: kUTTypeMPEG4Audio as String
        )
        Logger.verbose("voice memo duration: \(durationSeconds), file size: \(dataSource.dataLength())")
        if attachment.hasError {
            Logger.warn("Invalid attachment: \(attachment.errorName ?? "Missing data").")
            showErrorAlert(forAttachment: attachment)
        } else {
            tryToSendAttachments(
                [attachment],
                preSendMessageCallBack: nil,
                messageText: nil,
                completion: nil
            )
        }
    }
    
    func cancelRecordingVoiceMemo() {
        AssertIsOnMainThread()
        
        stopRecording()
        self.audioRecorder = nil
        self.voiceMessageUUID = nil
    }
    
    private func stopRecording() {
        self.audioRecorder?.stop()
        self.audioSession.endAudioActivity(self.recordVoiceNoteAudioActivity)
    }
}
