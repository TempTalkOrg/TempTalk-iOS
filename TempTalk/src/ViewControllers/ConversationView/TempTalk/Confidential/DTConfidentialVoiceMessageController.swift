//
//  DTConfidentialVoiceMessageController.swift
//  TempTalk
//
//  Created by henry on 2026/01/27.
//  Copyright © 2026 Difft. All rights reserved.
//

import UIKit
import TTServiceKit
import TTMessaging

/// 机密语音消息播放控制器
@objc class DTConfidentialVoiceMessageController: OWSViewController {

    // MARK: - Properties

    private let message: TSMessage
    private let viewItem: ConversationViewItem
    private var attachmentStream: TSAttachmentStream?
    private var haveRead: Bool = false

    // Audio player
    private var audioPlayer: OWSAudioPlayer?
    private var audioMessageView: OWSAudioMessageView?

    // Timer for updating audio progress
    private var audioUpdateTimer: Timer?

    // Cached audio data to survive message deletion
    private var cachedAudioData: Data?
    private var cachedAudioURL: URL?

    // UI Components
    private let containerView = UIView()
    private let playButton = UIButton(type: .custom)

    // MARK: - Initialization

    @available(*, unavailable, message:"use other constructor instead.")
    required init?(coder aDecoder: NSCoder) {
        fatalError("\(#function) is unimplemented.")
    }

    @objc required init(message: TSMessage, viewItem: ConversationViewItem) {
        self.message = message
        self.viewItem = viewItem
        self.attachmentStream = viewItem.attachmentStream()
        super.init()
    }

    deinit {
        stopAudioUpdateTimer()
        cleanupCachedAudio()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNav()
        setupUI()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopAudioUpdateTimer()
    }

    override func applyTheme() {
        super.applyTheme()
        view.backgroundColor = Theme.bg1Color
        containerView.backgroundColor = Theme.bg2Color
    }

    // MARK: - Setup

    private func setupNav() {
        if #available(iOS 13.0, *) {
            let rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .close,
                target: self,
                action: #selector(closeButtonPressed)
            )
            navigationItem.rightBarButtonItem = rightBarButtonItem
        }
    }

    private func setupUI() {
        view.backgroundColor = Theme.bg1Color

        // Container View (similar to message bubble)
        containerView.backgroundColor = Theme.bg2Color
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = true
        view.addSubview(containerView)

        // Create audio message view (same as in conversation)
        if let attachmentStream = attachmentStream {
            var thread: TSThread?
            databaseStorage.read { transaction in
                thread = self.message.thread(with: transaction)
            }
            let conversationStyle = ConversationStyle(thread: thread ?? TSThread())
            let isIncoming = message.interactionType() == .incomingMessage

            let audioView = OWSAudioMessageView(
                attachment: attachmentStream,
                isIncoming: isIncoming,
                viewItem: viewItem,
                conversationStyle: conversationStyle
            )
            audioView.createContents()
            self.audioMessageView = audioView

            // Add a custom play button overlay to intercept taps
            playButton.backgroundColor = .clear
            playButton.addTarget(self, action: #selector(playButtonPressed), for: .touchUpInside)
            audioView.addSubview(playButton)

            // Make the play button cover the audio view's play button area
            playButton.autoPinEdge(toSuperviewEdge: .leading)
            playButton.autoPinEdge(toSuperviewEdge: .top)
            playButton.autoPinEdge(toSuperviewEdge: .bottom)
            playButton.autoSetDimension(.width, toSize: 44) // Cover the play button area

            containerView.addSubview(audioView)

            // Layout
            audioView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        }

        // Layout - pin to top with 32px margin
        containerView.autoPinEdge(toSuperviewSafeArea: .top, withInset: 32)
        containerView.autoPinEdge(toSuperviewEdge: .leading, withInset: 20)
        containerView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 20)
    }

    // MARK: - Actions

    @objc private func closeButtonPressed() {
        stopAudioPlayer()
        dismiss(animated: true)
    }

    @objc private func playButtonPressed() {
        guard let attachmentStream = attachmentStream else {
            return
        }

        // On first play: decrypt, cache audio data, then delete message
        if !haveRead {
            haveRead = true

            // Decrypt the voice message first
            if attachmentStream.isVoiceMessage() {
                OWSAttachmentsProcessor.decryptVoiceAttachment(attachmentStream)
            }

            // Cache the decrypted audio data BEFORE deletion
            cacheAudioData(from: attachmentStream)

            // Now safe to delete the message
            markAsReadAndDelete()
        }

        // Play audio (will use cached data if available)
        playOrPauseAudioPlayer(attachmentStream: attachmentStream)
    }

    private func playOrPauseAudioPlayer(attachmentStream: TSAttachmentStream) {
        AssertIsOnMainThread()

        // Check if we're toggling the same audio
        if let audioPlayer = audioPlayer,
           let owner = audioPlayer.owner as? String,
           owner == viewItem.interaction.uniqueId {

            // Get current state before toggling
            let wasPlaying = viewItem.audioPlaybackState() == .playing

            // Toggle the playback state
            audioPlayer.togglePlayState()

            // Update UI immediately
            audioMessageView?.updateContents()

            // Start or stop timer based on the NEW state (opposite of wasPlaying)
            if wasPlaying {
                // Was playing, now paused
                stopAudioUpdateTimer()
            } else {
                // Was paused, now playing
                startAudioUpdateTimer()
            }
            return
        }

        // Stop any existing player
        if audioPlayer != nil {
            stopAudioPlayer()
        }

        // Try to get media URL - use cached URL if original file is gone
        var mediaURL: URL?

        // First try the original file path
        if let filePath = attachmentStream.filePath(), FileManager.default.fileExists(atPath: filePath) {
            mediaURL = attachmentStream.mediaURL()
        } else if let cachedURL = cachedAudioURL, FileManager.default.fileExists(atPath: cachedURL.path) {
            // Original file deleted, use cached copy
            Logger.info("Using cached audio file for playback")
            mediaURL = cachedURL
        } else {
            Logger.error("Missing audio file - neither original nor cached version available")
            return
        }

        guard let finalMediaURL = mediaURL else {
            Logger.error("Could not get media URL")
            return
        }

        // Create new player
        audioPlayer = OWSAudioPlayer(mediaUrl: finalMediaURL, delegate: viewItem)
        audioPlayer?.owner = viewItem.interaction.uniqueId as AnyObject
        audioPlayer?.playWithPlaybackAudioCategory()

        // Start update timer
        startAudioUpdateTimer()
    }

    private func stopAudioPlayer() {
        audioPlayer?.stop()
        audioPlayer = nil
        stopAudioUpdateTimer()
    }

    // MARK: - Audio Update Timer

    private func startAudioUpdateTimer() {
        stopAudioUpdateTimer()

        // Use 30ms interval for smooth progress updates (same as OWSAudioPlayer)
        audioUpdateTimer = Timer.scheduledTimer(
            timeInterval: 0.03,
            target: self,
            selector: #selector(updateAudioProgress),
            userInfo: nil,
            repeats: true
        )
    }

    private func stopAudioUpdateTimer() {
        audioUpdateTimer?.invalidate()
        audioUpdateTimer = nil
    }

    @objc private func updateAudioProgress() {
        // Update the audio message view to reflect current progress
        audioMessageView?.updateContents()

        // Check if playback has finished
        let playbackState = viewItem.audioPlaybackState()
        if playbackState != .playing {
            stopAudioUpdateTimer()
        }
    }

    // MARK: - Audio Caching

    private func cacheAudioData(from attachmentStream: TSAttachmentStream) {
        guard let filePath = attachmentStream.filePath(),
              FileManager.default.fileExists(atPath: filePath) else {
            Logger.error("Cannot cache audio - file does not exist")
            return
        }

        do {
            // Read the decrypted audio data into memory
            let audioData = try Data(contentsOf: URL(fileURLWithPath: filePath))
            self.cachedAudioData = audioData

            // Create a temporary file to store the cached audio
            let tempDir = NSTemporaryDirectory()
            let tempFileName = "confidential_audio_\(UUID().uuidString).m4a"
            let tempURL = URL(fileURLWithPath: tempDir).appendingPathComponent(tempFileName)

            // Write cached data to temp file
            try audioData.write(to: tempURL)
            self.cachedAudioURL = tempURL

            Logger.info("Successfully cached audio data: \(audioData.count) bytes at \(tempURL.path)")
        } catch {
            Logger.error("Failed to cache audio data: \(error)")
        }
    }

    private func cleanupCachedAudio() {
        // Clean up temporary cached audio file
        if let cachedURL = cachedAudioURL {
            try? FileManager.default.removeItem(at: cachedURL)
            Logger.info("Cleaned up cached audio file")
        }
        cachedAudioData = nil
        cachedAudioURL = nil
    }

    // MARK: - Mark as Read

    private func markAsReadAndDelete() {
        guard let incomingMessage = message as? TSIncomingMessage else {
            return
        }

        // Mark as read
        OWSReadReceiptManager.shared().confidentialMessageWasReadLocally(incomingMessage)

        // Delete the message (read-once behavior)
        databaseStorage.asyncWrite { transaction in
            incomingMessage.anyRemove(transaction: transaction)
        }
    }
}
