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
import LiveKit
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

    // 音频播放速度：1.0, 1.5, 2.0
    // 第一次使用全局设置，之后使用本地变量
    var audioPlaybackRate: Float {
        get {
            // 如果本地变量为 nil，从全局设置读取并缓存
            if viewState.currentAudioPlaybackRate == nil {
                viewState.currentAudioPlaybackRate = MediaSavePolicyManager.shared.getPlaybackSpeed()
            }
            return viewState.currentAudioPlaybackRate ?? 1.0
        }
        set {
            // 更新本地变量（不保存到全局设置）
            viewState.currentAudioPlaybackRate = newValue
            // 如果当前有正在播放的音频，更新其播放速度
            if let audioPlayer = audioPlayer {
                audioPlayer.setPlaybackRate(newValue)
            }
        }
    }

    // 切换播放速度：1.0 -> 1.5 -> 2.0 -> 1.0
    @objc func toggleAudioPlaybackRate() {
        let currentRate = audioPlaybackRate
        let newRate: Float
        if currentRate == 1.0 {
            newRate = 1.5
        } else if currentRate == 1.5 {
            newRate = 2.0
        } else {
            newRate = 1.0
        }
        audioPlaybackRate = newRate

        // 刷新所有音频 cell 的按钮显示
        collectionView.visibleCells.forEach { cell in
            if let outgoingCell = cell as? ConversationOutgoingMessageCell {
                outgoingCell.refreshAudioControlButton()
            } else if let incomingCell = cell as? ConversationIncomingMessageCell {
                incomingCell.refreshAudioControlButton()
            }
        }
    }
    
    func resumeAudioPlayer(viewItem: ConversationViewItem, attachmentStream: TSAttachmentStream) {
        playOrPauseAudioPlayer(viewItem: viewItem, attachmentStream: attachmentStream)
    }
    
    @objc func pauseAudioPlayer() {
        audioPlayer?.pause()
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
        // 设置播放速度
        audioPlayer?.setPlaybackRate(audioPlaybackRate)
        audioPlayer?.playWithPlaybackAudioCategory()
    }
}

// MARK: - Voice Memo Recorder
//
// Uses `DualCandidateVoiceRecorder` to produce N parallel candidates
// (default: `denoised` + `denoised+higher`) in a single recording pass.
// We auto-pick one (denoise+effect > denoise only > first non-nil) and send
// it through the existing `tryToSendAttachments` path — UX is identical to
// the previous single-file flow. A future preview UI can expose the
// candidates list to let the user choose among them.

extension ConversationViewController {
    private var voiceRecorder: DualCandidateVoiceRecorder? {
        get { viewState.voiceRecorder }
        set {
            // Handle every transition explicitly: nil→non-nil, non-nil→nil,
            // **and non-nil→non-nil** (replace). The original branchy form
            // had a latent bug — on a replace, the old recorder's sleep
            // block was never removed; ARC + DeviceSleepManager's weak
            // `blockObject` mopped it up eventually, but the block table
            // briefly carried a stale entry. Today no caller does a replace,
            // but any future "pending result" slot from review [H1] could
            // start one. Belt-and-suspenders correctness for ~3 extra lines.
            let oldValue = viewState.voiceRecorder
            if oldValue !== newValue {
                if let oldValue {
                    DeviceSleepManager.shared.removeBlock(blockObject: oldValue)
                }
                if let newValue {
                    DeviceSleepManager.shared.addBlock(blockObject: newValue)
                }
            }
            viewState.voiceRecorder = newValue
        }
    }

    private var voiceMessageUUID: UUID? {
        get { viewState.voiceMessageUUID }
        set { viewState.voiceMessageUUID = newValue }
    }

    /// True iff `DualCandidateVoiceRecorder` is currently recording or about
    /// to record (mic-permission round-trip still in flight). Single source
    /// of truth used by `applicationWillResignActive` (Notifications ext) and
    /// `viewDidDisappear` (main VC) to decide whether to cancel — keep them
    /// reading the same expression so future state additions (e.g. a
    /// "pending result" slot from review [H1] expansion) only need one edit.
    ///
    /// Cheaper than asking the recorder directly (which would `recorderQueue.sync`
    /// against any in-flight file write — see review [M1]).
    var voiceMemoIsActive: Bool {
        return viewState.voiceRecorder != nil || viewState.voiceMessageUUID != nil
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

        // Setup audio session (no-op while in a LiveKit call — the call
        // already owns the session; see OWSAudioSession.startRecordingAudioActivity).
        let configuredAudio = self.audioSession.startRecordingAudioActivity(self.recordVoiceNoteAudioActivity)
        if !configuredAudio {
            Logger.warn("Couldn't configure audio session for voice memo recording")
            cancelVoiceMemo()
            return
        }

        // One subdir per recording attempt so cancel-cleanup never sweeps a
        // sibling attempt's tmp files. Picker / send path operates on the
        // chosen candidate's URL; the rest are removed when the recorder
        // wraps up.
        let stamp = Date.ows_millisecondTimestamp()
        let recordingDir = URL(fileURLWithPath: OWSTemporaryDirectory())
            .appendingPathComponent("voice-msg-\(stamp)", isDirectory: true)

        let recorder = DualCandidateVoiceRecorder(
            outputDirectory: recordingDir,
            recipes: VoiceMessageRecipes.recipes(for: inputToolbar.voiceMemoEffect),
            denoiseModel: VoiceMessageRecipes.defaultDenoiseModel,
            delegate: self
        )
        // While muted inside a LiveKit call, the SDK mutes the shared mic input,
        // so our own AVAudioEngine tap would capture silence. Force LiveKit to
        // capture locally (without publishing to the room) so the tap picks up
        // audio; `endRecordingSession` stops it again.
        guard beginInCallLocalRecordingIfNeeded() else {
            DTToastHelper.toast(withText: Localized("VOICE_MESSAGE_IN_CALL_TOAST"))
            cancelVoiceMemo()
            return
        }

        self.voiceRecorder = recorder
        recorder.start()

        DTMeetingManager.isVoiceRecordingActive = true
    }

    /// True when we're inside a LiveKit call whose local mic is muted — the one
    /// case where our own recorder tap would otherwise capture silence.
    private var shouldForceInCallLocalRecording: Bool {
        guard OWSAudioSession.shared.inCalling else { return false }
        guard let room = DTMeetingManager.shared.roomContext?.room else { return false }
        return room.localParticipant.isMicrophoneEnabled() == false
    }

    private var hasLiveKitMicrophonePublication: Bool {
        DTMeetingManager.shared.roomContext?.room
            .localParticipant.localAudioTracks.isEmpty == false
    }

    private func beginInCallLocalRecordingIfNeeded() -> Bool {
        guard shouldForceInCallLocalRecording else { return true }
        viewState.inCallVoiceMemoAudioOwnership.begin(
            hasMicrophonePublication: hasLiveKitMicrophonePublication
        )
        // startLocalRecording activates the VPIO mic; iOS mirrors that into
        // CallKit as performSetMutedCallAction(muted:0). Suppress those echoes
        // for the whole recording so they don't unmute LiveKit (开麦). Set the
        // flag BEFORE starting so the very first echo is caught.
        DTMeetingManager.shared.setInCallLocalRecordingActive(true)
        do {
            try AudioManager.shared.startLocalRecording()
            viewState.didStartInCallLocalRecording = true
            Logger.info("voice memo: startLocalRecording to capture while call mic is muted")
            return true
        } catch {
            viewState.inCallVoiceMemoAudioOwnership.reset()
            DTMeetingManager.shared.setInCallLocalRecordingActive(false)
            Logger.error("voice memo: startLocalRecording failed: \(error)")
            return false
        }
    }

    private func endInCallLocalRecordingIfNeeded() {
        guard viewState.didStartInCallLocalRecording else { return }
        viewState.didStartInCallLocalRecording = false

        let endAction = viewState.inCallVoiceMemoAudioOwnership.finish(
            hasCurrentMicrophonePublication: hasLiveKitMicrophonePublication
        )

        switch endAction {
        case .preserveRecording:
            // WebRTC still owns this ADM input. Stopping it directly would leave
            // WebRTC's sender state out of sync and a later unmute would capture no PCM.
            AudioManager.shared.isMicrophoneMuted = true
            Logger.info("voice memo: preserve LiveKit recording, restore call mic muted state")
        case .stopRecording:
            do {
                try AudioManager.shared.stopLocalRecording()
                Logger.info("voice memo: stopLocalRecording, restore call mic muted state")
            } catch {
                Logger.error("voice memo: stopLocalRecording failed: \(error)")
            }
            AudioManager.shared.isMicrophoneMuted = true
        }
        // Keep suppressing briefly: restoring VPIO mute (or stopping local recording)
        // can be mirrored back as performSetMutedCallAction(muted:1).
        DTMeetingManager.shared.beginCallKitMuteSuppression(1.5)
        DTMeetingManager.shared.setInCallLocalRecordingActive(false)
    }

    func endRecordingVoiceMemo() {
        AssertIsOnMainThread()

        self.voiceMessageUUID = nil

        guard let recorder = voiceRecorder else {
            Logger.error("Missing voiceRecorder")
            return
        }

        let durationSeconds = recorder.currentTime
        let kMinimumRecordingTimeSeconds: TimeInterval = 1.0
        if durationSeconds < kMinimumRecordingTimeSeconds {
            Logger.info("Discarding voice message too short.")
            // Stop the recorder via cancel() so it deletes all candidate
            // files itself; we DON'T want a partial 0.x-second file to
            // leak through the send path.
            recorder.cancel()
            // Tear down the recorder ref + session here rather than waiting
            // for the delegate so the too-short alert is consistent with
            // the legacy behaviour.
            self.voiceRecorder = nil
            viewState.pendingVoiceMessageSendMode = .original
            endRecordingSession()

            dismissKeyBoard()
            OWSActionSheets.showActionSheet(
                title: Localized("VOICE_MESSAGE_TOO_SHORT_ALERT_TITLE"),
                message: Localized("VOICE_MESSAGE_TOO_SHORT_ALERT_MESSAGE")
            )
            return
        }

        // Normal stop — delegate `voiceRecorder(_:didFinish:)` will pick a
        // candidate and call `tryToSendAttachments`.
        recorder.stop()
    }

    func cancelRecordingVoiceMemo() {
        AssertIsOnMainThread()

        if let recorder = voiceRecorder {
            recorder.cancel()
        }
        self.voiceRecorder = nil
        self.voiceMessageUUID = nil
        viewState.pendingVoiceMessageSendMode = .original
        endRecordingSession()
    }

    /// Tear down the AudioActivity + post the "recording-ended" notification.
    /// Always called whether the recording succeeded, was cancelled, or was
    /// too short.
    private func endRecordingSession() {
        endInCallLocalRecordingIfNeeded()
        self.audioSession.endAudioActivity(self.recordVoiceNoteAudioActivity)
        if DTMeetingManager.isVoiceRecordingActive {
            DTMeetingManager.isVoiceRecordingActive = false
            NotificationCenter.default.post(name: .voiceRecordingDidEnd, object: nil)
        }
    }

    /// `.original` → denoised; `.effected` → denoised+effect. Fallbacks logged.
    fileprivate func pickPrimaryCandidate(
        _ candidates: [VoiceMessageRecordingCandidate],
        preferredMode: VoiceMessageSendMode
    ) -> VoiceMessageRecordingCandidate? {
        switch preferredMode {
        case .effected:
            if let pick = candidates.first(where: {
                $0.fileURL != nil && $0.recipe.denoise && $0.recipe.effect != nil
            }) {
                return pick
            }
            if let pick = candidates.first(where: {
                $0.fileURL != nil && $0.recipe.denoise
            }) {
                if candidates.contains(where: {
                    $0.recipe.denoise && $0.recipe.effect != nil && $0.fileURL == nil
                }) {
                    Logger.warn("voice memo voice-changer tap failed; falling back to plain denoised. candidates: \(candidatesDebugString(candidates))")
                }
                return pick
            }
            if let pick = candidates.first(where: { $0.fileURL != nil }) {
                Logger.warn("voice memo denoise tap failed; falling back to raw. candidates: \(candidatesDebugString(candidates))")
                return pick
            }
            return nil

        case .original:
            if let pick = candidates.first(where: {
                $0.fileURL != nil && $0.recipe.denoise && $0.recipe.effect == nil
            }) {
                return pick
            }
            // Send pitched audio rather than nothing.
            if let pick = candidates.first(where: { $0.fileURL != nil }) {
                Logger.warn("voice memo plain-denoised tap failed for original mode; falling back to next available. candidates: \(candidatesDebugString(candidates))")
                return pick
            }
            return nil
        }
    }

    /// Compact diagnostic string for picker fallback logging:
    /// `denoised=true,denoised+higher=false`.
    private func candidatesDebugString(_ candidates: [VoiceMessageRecordingCandidate]) -> String {
        candidates.map { "\($0.recipe.id)=\($0.fileURL != nil)" }.joined(separator: ",")
    }

    /// Move the picked candidate out of its `voice-msg-<stamp>/` subdir into
    /// a flat tmp file, then nuke the subdir (which takes the un-picked
    /// siblings and the empty parent with it). Returns the new URL on
    /// success, or `nil` if the move failed — callers should fall back to
    /// the original URL and do a best-effort sibling sweep.
    ///
    /// Why move-then-nuke instead of letting `DataSourcePath`'s
    /// delete-on-dealloc handle it: `DataSource` only deletes a single
    /// `path` it owns. The recorder writes N candidate files into a per-
    /// recording subdir; the picker hands one of those files to
    /// `DataSourcePath`, which leaves the other N-1 candidates AND the
    /// subdir itself on disk for the rest of the process's lifetime. See
    /// review `[H2]`.
    fileprivate func relocatePickedCandidate(
        from pickedURL: URL,
        candidates: [VoiceMessageRecordingCandidate]
    ) -> URL? {
        let recordingDir = pickedURL.deletingLastPathComponent()
        let finalURL = URL(fileURLWithPath: OWSTemporaryDirectory())
            .appendingPathComponent("voice-msg-\(Date.ows_millisecondTimestamp()).m4a")
        do {
            try FileManager.default.moveItem(at: pickedURL, to: finalURL)
            // Picked file is gone from recordingDir — safe to wipe the rest.
            try? FileManager.default.removeItem(at: recordingDir)
            return finalURL
        } catch {
            // Move failed (disk full, permissions, …). Picked file is still
            // in recordingDir → can't nuke the dir wholesale or we'd lose
            // the data we're about to send. Sweep siblings explicitly so
            // they at least don't leak; recordingDir parent will linger
            // until the next app launch but the data files are gone.
            Logger.warn("voice message: couldn't relocate picked candidate (\(error.localizedDescription)); sending in place")
            cleanupCandidateFiles(candidates: candidates, pickedURL: pickedURL)
            return nil
        }
    }

    /// Delete every candidate file whose URL is non-nil and not equal to
    /// `pickedURL`. Pass `pickedURL = nil` to delete ALL candidates (used in
    /// abort / picker-failed paths).
    fileprivate func cleanupCandidateFiles(
        candidates: [VoiceMessageRecordingCandidate],
        pickedURL: URL?
    ) {
        for c in candidates {
            guard let url = c.fileURL else { continue }
            if let pickedURL, url == pickedURL { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }
}

// MARK: - DualCandidateVoiceRecorderDelegate

extension ConversationViewController: DualCandidateVoiceRecorderDelegate {
    public func voiceRecorderDidStart(_ recorder: DualCandidateVoiceRecorder) {
        // The toolbar already showed the voice-memo UI in
        // `voiceMemoGestureDidStart` — nothing else to do here today.
    }

    public func voiceRecorderDidRequestStop(_ recorder: DualCandidateVoiceRecorder) {
        // Mic capture stopped. Files may still be finalising; the result
        // arrives via `voiceRecorder(_:didFinish:)`.
    }

    public func voiceRecorder(_ recorder: DualCandidateVoiceRecorder,
                              didFinish candidates: [VoiceMessageRecordingCandidate]) {
        AssertIsOnMainThread()

        // Defense in depth for the stop→cancel race.
        //
        // The recorder already drops late cancels on the floor in its
        // serial queue (`finishCancelPathOnQueue` swaps didFinish for
        // didCancel when `cancelRequested` flips during file write). But
        // there's a residual one-frame race: didFinish was deliver()'d to
        // main BEFORE cancel() landed; main is processing the cancel right
        // now and nils out `voiceRecorder`; THEN main runs this didFinish
        // closure. If we sent the message here, we'd ship a "cancelled"
        // voice memo anyway. Identity check catches that: if `voiceRecorder`
        // is no longer this recorder, the VC has moved on — discard the
        // result and clean up its files so they don't leak.
        guard self.voiceRecorder === recorder else {
            Logger.info("voiceRecorder didFinish ignored — recorder no longer current (cancelled / replaced)")
            cleanupCandidateFiles(candidates: candidates, pickedURL: nil)
            return
        }

        // Snapshot + reset so a crash mid-send doesn't leak into next recording.
        let preferredMode = viewState.pendingVoiceMessageSendMode
        viewState.pendingVoiceMessageSendMode = .original

        defer {
            self.voiceRecorder = nil
            endRecordingSession()
        }

        guard let pick = pickPrimaryCandidate(candidates, preferredMode: preferredMode),
              let url = pick.fileURL else {
            Logger.warn("voice recorder finished with no usable candidate; skipping send")
            cleanupCandidateFiles(candidates: candidates, pickedURL: nil)
            // TODO(voice-message): review [H4] — "candidates all failed" ≠
            // "user lifted finger too fast", but we reuse the TOO_SHORT
            // alert string for both right now. Add a dedicated
            // `VOICE_MESSAGE_FAILED_ALERT_TITLE` / `_MESSAGE` localised
            // string set and route SDK / encoder / disk failures through
            // it instead. Same TODO applies to `voiceRecorder(_:didFailWith:)`
            // which currently only logs without alerting the user.
            OWSActionSheets.showActionSheet(
                title: Localized("VOICE_MESSAGE_TOO_SHORT_ALERT_TITLE"),
                message: Localized("VOICE_MESSAGE_TOO_SHORT_ALERT_MESSAGE")
            )
            return
        }

        // Move the picked file out of the recorder's per-recording
        // `voice-msg-<stamp>/` subdir into a standalone file under tmp/, then
        // delete the subdir wholesale. This kills three sources of disk leak
        // in one shot: the un-picked sibling candidate (DataSource only
        // deletes the picked file on dealloc), the now-empty parent dir
        // (DataSource never touches parent), and any partially-written tap
        // that failed mid-flush. The recorder allocates the subdir lazily
        // in `startRecordingVoiceMemo`, so cleaning it here closes the loop.
        let sendURL = relocatePickedCandidate(from: url, candidates: candidates) ?? url

        let dataSource: DataSource
        do {
            dataSource = try DataSourcePath.dataSource(
                with: sendURL,
                shouldDeleteOnDeallocation: true
            )
        } catch {
            // Review [H6]: previously this was a silent owsFailDebug-only
            // path — release builds emitted a log line and the user saw
            // **nothing happen**. Three things must run here:
            //   1. file cleanup — DataSource didn't take ownership, so
            //      dealloc-delete won't fire; wipe sendURL ourselves.
            //      (Siblings + recording dir were already deleted in
            //      `relocatePickedCandidate`, so this is the last orphan.)
            //   2. user-visible alert — without it the user thinks the
            //      message was sent silently, retries, and may double-press
            //      record. Reuse TOO_SHORT alert until [H4] adds a
            //      dedicated VOICE_MESSAGE_FAILED_ALERT_* string.
            //   3. logging — keep owsFailDebug so debug builds still trap
            //      on this rare path; in release it routes through Logger.
            owsFailDebug("Couldn't load voice recorder data: \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: sendURL)
            // TODO(voice-message): see [H4] — needs dedicated
            // `VOICE_MESSAGE_FAILED_ALERT_*` localised strings.
            OWSActionSheets.showActionSheet(
                title: Localized("VOICE_MESSAGE_TOO_SHORT_ALERT_TITLE"),
                message: Localized("VOICE_MESSAGE_TOO_SHORT_ALERT_MESSAGE")
            )
            return
        }

        // Recipient-visible filename: always the localised generic name with
        // a .m4a extension — never leak the recipe id (`denoised+higher` etc.)
        // to the other side. Matches the Android `prepareSendAttachmentPush`
        // override.
        let fileName = Localized("VOICE_MESSAGE_FILE_NAME") + ".m4a"
        dataSource.sourceFilename = fileName

        let attachment = SignalAttachment.voiceMessageAttachment(
            dataSource: dataSource,
            dataUTI: kUTTypeMPEG4Audio as String
        )
        Logger.verbose("voice memo pickedRecipe=\(pick.recipe.id) mode=\(preferredMode) durationMs=\(pick.durationMs) file size: \(dataSource.dataLength())")
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

    public func voiceRecorderDidCancel(_ recorder: DualCandidateVoiceRecorder) {
        AssertIsOnMainThread()
        // Two arrival paths:
        // 1. The VC initiated the cancel (cancelRecordingVoiceMemo or its
        //    callers in resignActive / viewDidDisappear /
        //    voiceMemoGestureWasInterrupted): voiceRecorder was already
        //    nil'd synchronously, so the identity check fails and we just
        //    log. Nothing further to do — caller already ran endRecordingSession.
        // 2. The SDK auto-converted a stop into a cancel because the user
        //    pressed Home / navigated away DURING file finalize: VC didn't
        //    yet know to tear down, so we have to do the cleanup here.
        guard self.voiceRecorder === recorder else { return }
        self.voiceRecorder = nil
        viewState.pendingVoiceMessageSendMode = .original
        endRecordingSession()
    }

    public func voiceRecorder(_ recorder: DualCandidateVoiceRecorder, didFailWith error: Error) {
        AssertIsOnMainThread()
        Logger.error("DualCandidateVoiceRecorder failed: \(error.localizedDescription)")
        // Same identity discipline as didFinish / didCancel — if the VC has
        // already moved past this recorder, don't stomp the current state.
        guard self.voiceRecorder === recorder else { return }
        self.voiceRecorder = nil
        viewState.pendingVoiceMessageSendMode = .original
        endRecordingSession()
    }
}
