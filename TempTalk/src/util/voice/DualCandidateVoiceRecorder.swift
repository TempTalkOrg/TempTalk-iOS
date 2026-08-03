//
//  DualCandidateVoiceRecorder.swift
//  TempTalk
//
//  Production voice-message recorder that captures a single mic stream and
//  fans it out into N parallel AAC m4a candidates via the SDK's multi-tap
//  `OfflineAudioPipeline` (default: `denoised` and `denoised+higher`,
//  matching chative-desktop / TempTalk-Android default).
//
//  Adapted from the SDK demo at:
//      denoise-plugin/denoise-plugin-swift/Example/VoiceMsgDemoViewController.swift
//  — keep the two in mind when fixing audio bugs; this class is the
//  production path with stricter lifecycle / threading guarantees.
//
//  Mirrors the Kotlin `DualCandidateVoiceRecorder.kt` API surface and
//  threading model.
//

import AVFoundation
import AudioPipelineProcessor
import Foundation

/// Pure-Swift delegate (intentionally NOT `@objc`). The protocol carries
/// `[VoiceMessageRecordingCandidate]` which is an array of Swift structs and
/// can't cross the Objective-C bridge. Both the delegate (typically a Swift
/// `UIViewController`) and the recorder are Swift, so the bridge isn't
/// needed.
public protocol DualCandidateVoiceRecorderDelegate: AnyObject {
    func voiceRecorderDidStart(_ recorder: DualCandidateVoiceRecorder)
    /// Mic capture stopped; AAC files may still be finalising in the background.
    /// UIs can show a "Saving…" indicator here. The result still flows through
    /// `voiceRecorder(_:didFinish:)`.
    func voiceRecorderDidRequestStop(_ recorder: DualCandidateVoiceRecorder)
    /// All candidate files are fully written. Some entries' `fileURL` may be
    /// `nil` if that recipe failed (pipeline init / encoder error). When ALL
    /// candidates are nil, treat it as a failed recording.
    func voiceRecorder(_ recorder: DualCandidateVoiceRecorder,
                       didFinish candidates: [VoiceMessageRecordingCandidate])
    func voiceRecorderDidCancel(_ recorder: DualCandidateVoiceRecorder)
    func voiceRecorder(_ recorder: DualCandidateVoiceRecorder, didFailWith error: Error)
}

/// Production voice-message recorder. Replaces the legacy single-file
/// voice-memo recorder — see `ConversationViewController+Audio` for the
/// integration glue.
public final class DualCandidateVoiceRecorder: NSObject {

    public enum RecorderError: LocalizedError {
        case alreadyRunning
        case pipelineInitFailed
        case audioEngineFailed(underlying: Error)
        case noConverter
        case invalidInputFormat(sampleRate: Double, channelCount: AVAudioChannelCount)
        case allCandidatesFailed
        /// Couldn't `createDirectory` the per-recording `outputDirectory`
        /// (disk full, NSFileProtection blocking access while device is
        /// locked, parent dir missing, …). Distinct from `audioEngineFailed`
        /// because mis-classifying disk failures as audio failures sends
        /// triage straight to mic / AVAudioSession dead ends.
        case outputDirectoryUnavailable(underlying: Error)

        public var errorDescription: String? {
            switch self {
            case .alreadyRunning:        return "DualCandidateVoiceRecorder is already running."
            case .pipelineInitFailed:    return "Failed to initialise the audio pipeline."
            case .audioEngineFailed(let e): return "AVAudioEngine failed: \(e.localizedDescription)"
            case .noConverter:           return "Failed to build AVAudioConverter for mic → 48 kHz mono."
            case .invalidInputFormat(let sampleRate, let channelCount):
                return "AVAudioEngine input format is not recordable: sampleRate=\(sampleRate), channels=\(channelCount)."
            case .allCandidatesFailed:   return "Every voice-message candidate failed to produce a file."
            case .outputDirectoryUnavailable(let e):
                return "Couldn't create voice-message output directory: \(e.localizedDescription)"
            }
        }
    }

    // MARK: - Constants

    private static let sampleRate: Double = 48_000
    private static let channelCount: AVAudioChannelCount = 1
    private static let aacBitrate: Int = 128_000
    /// AVAudioEngine tap buffer size. Apple internally clamps this to a value
    /// the route supports (typically 256–4096), so anything in range is fine.
    private static let tapBufferSize: AVAudioFrameCount = 4096

    private static let processingFormat: AVAudioFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: sampleRate,
        channels: channelCount,
        interleaved: false
    )!
    /// AAC writer settings. Sample rate / channel count are **derived from
    /// `processingFormat`** rather than reading the same constants twice —
    /// if `processingFormat` ever changes (e.g. stereo support), the AAC
    /// container moves with it automatically. Otherwise AVAudioFile would
    /// silently resample the writer-buffer-format buffer to whatever the
    /// settings asked for, hiding the drift behind quiet quality loss.
    private static let writerFormatSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: processingFormat.sampleRate,
        AVNumberOfChannelsKey: Int(processingFormat.channelCount),
        AVEncoderBitRateKey: aacBitrate,
    ]

    // MARK: - Construction

    public weak var delegate: DualCandidateVoiceRecorderDelegate?
    private let outputDirectory: URL
    private let recipes: [VoiceMessageRecipe]
    private let denoiseModel: AudioModule

    /// - Parameters:
    ///   - outputDirectory: A directory **owned exclusively by this single
    ///     recording**. The recorder writes one
    ///     `vm-<timestamp>-<recipeId>.m4a` per recipe directly into it and
    ///     on cancel / start-failure paths nukes the whole directory
    ///     (`removeItem(at: outputDirectory)`) to take siblings + the empty
    ///     parent down in one shot. Pass `OWSTemporaryDirectory()` here
    ///     and you'll wipe unrelated tmp files. Callers should create a
    ///     fresh subdir per recording — see
    ///     `ConversationViewController+Audio.startRecordingVoiceMemo` for
    ///     the canonical `voice-msg-<stamp>/` pattern.
    ///   - recipes: One tap per recipe; non-empty, ids unique.
    ///   - denoiseModel: Shared across every `denoise: true` recipe; pay
    ///     the DFN cold-start cost once even when N recipes are configured.
    ///   - delegate: Lifecycle callbacks; held weakly.
    public init(
        outputDirectory: URL,
        recipes: [VoiceMessageRecipe] = VoiceMessageRecipes.default,
        denoiseModel: AudioModule = VoiceMessageRecipes.defaultDenoiseModel,
        delegate: DualCandidateVoiceRecorderDelegate? = nil
    ) {
        precondition(!recipes.isEmpty, "DualCandidateVoiceRecorder requires at least one recipe")
        // Single-pass duplicate id check.
        var seen: Set<String> = []
        for r in recipes {
            precondition(seen.insert(r.id).inserted,
                         "DualCandidateVoiceRecorder recipe ids must be unique (dup: '\(r.id)')")
        }
        self.outputDirectory = outputDirectory
        self.recipes = recipes
        self.denoiseModel = denoiseModel
        self.delegate = delegate
    }

    // MARK: - State

    /// Serial background queue that owns *all* SDK calls, AVAudioFile writes,
    /// chunk buffers, and lifecycle transitions. The audio-thread tap callback
    /// is the only entry point that crosses thread boundaries — it copies the
    /// PCM out and `async`-dispatches onto this queue. Everything else stays
    /// here so we never need a lock.
    private let recorderQueue = DispatchQueue(label: "voiceRecorder.serial", qos: .userInitiated)

    private var engine: AVAudioEngine?
    /// Set inside `start()` and read inside the tap callback (audio thread).
    /// Tap is removed before `engine = nil`, so once the tap stops firing the
    /// converter reference is safe to drop on `recorderQueue`.
    private var inputConverter: AVAudioConverter?

    private var pipeline: OfflineAudioPipeline?
    private var isRunningInternal: Bool = false        // serial-queue protected

    /// Latched terminal-state flags **and** `startedAtMs`. All written from
    /// `stop()` / `cancel()` / `startOnQueue` on whatever thread the
    /// caller used, read from `recorderQueue` (cancel flags) or **any**
    /// thread (`currentTime` reads `_startedAtMs`).
    ///
    /// NSLock rather than queue-confined because the cancel flags' whole
    /// point is that `cancel()` must be visible to a `stopOnQueue` already
    /// executing — dispatching the flag write onto the queue would
    /// deadlock behind the in-flight `stopOnQueue`'s file write (which is
    /// what we want to interrupt). `_startedAtMs` shares the lock because
    /// `currentTime` is called by `RecordingLimitProcessor` polling at
    /// ~1 Hz; bare `Int64` reads have no memory-ordering guarantee in
    /// Swift, and on the (now-extinct) 32-bit ARM build would tear.
    private let stateLock = NSLock()
    private var _cancelRequested: Bool = false
    private var _stopRequested: Bool = false
    private var _startedAtMs: Int64 = 0

    private var cancelRequested: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return _cancelRequested
    }
    private var stopRequested: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return _stopRequested
    }
    private var startedAtMsLocked: Int64 {
        stateLock.lock(); defer { stateLock.unlock() }
        return _startedAtMs
    }
    private func markCancelRequested() {
        stateLock.lock(); _cancelRequested = true; stateLock.unlock()
    }
    private func markStopRequested() {
        stateLock.lock(); _stopRequested = true; stateLock.unlock()
    }
    private func setStartedAtMs(_ value: Int64) {
        stateLock.lock(); _startedAtMs = value; stateLock.unlock()
    }
    private func clearRequestFlagsOnQueue() {
        // Only called from `startOnQueue` — `recorderQueue` is serial so we
        // know no concurrent reader is mid-flight, but we still take the
        // lock for happens-before consistency with `cancel()` callers.
        stateLock.lock()
        _cancelRequested = false
        _stopRequested = false
        _startedAtMs = 0
        stateLock.unlock()
    }

    /// recipe.id → in-memory PCM chunks. Written to disk at stop time so
    /// AVAudioFile.write never blocks the audio thread. Worst case 3 min × 2
    /// candidates × 34 MB = ~70 MB; recorder.queue serialised → no atomics.
    private var perTapChunks: [String: [[Float]]] = [:]
    /// recipe.id → URL slot allocated up front (filename embeds recipe id so
    /// it's debuggable on disk; recipient-visible filename is overridden at
    /// send time — see `ConversationViewController+Audio`).
    private var perTapURLs: [String: URL] = [:]
    /// recipe.id → encoder failure marker. Failed taps stay nil in the final
    /// candidates list.
    private var failedTaps: Set<String> = []

    /// `currentTime`-style API for `RecordingLimitProcessor`. Reads
    /// `startedAtMs` under `stateLock` so callers polling from main thread
    /// always observe the value committed in `startOnQueue`'s tail. Zero
    /// is returned both pre-start and post-stop; consumers should pair
    /// `currentTime` reads with the delegate lifecycle.
    public var currentTime: TimeInterval {
        let start = startedAtMsLocked
        if start == 0 { return 0 }
        return TimeInterval(Date.ows_millisecondTimestamp() - UInt64(start)) / 1000
    }

    public var isRunning: Bool { recorderQueue.sync { isRunningInternal } }

    // MARK: - Public API (call from any thread)

    public func start() {
        recorderQueue.async { [weak self] in
            self?.startOnQueue()
        }
    }

    public func stop() {
        // Latch the request flag synchronously so a `cancel()` arriving
        // before the queue dequeues this `stopOnQueue` still sees the right
        // intent ordering. The slow path inside `stopOnQueue` polls
        // `cancelRequested` to honour late cancels mid-finalize.
        markStopRequested()
        recorderQueue.async { [weak self] in
            self?.stopOnQueue(deleteFiles: false)
        }
    }

    public func cancel() {
        // CRITICAL: must be set BEFORE the dispatch_async. A `stop()` that
        // already started its slow `finalizeAndWriteOnQueue` is BLOCKING the
        // queue — our enqueue won't run until the stop is done. By the time
        // our `stopOnQueue` runs, the stop has already delivered didFinish
        // and the message is being sent. Setting `cancelRequested = true`
        // synchronously lets the in-flight `stopOnQueue` notice the cancel
        // between finalize and deliver-didFinish, route to cleanup, and
        // deliver didCancel instead. See `stopOnQueue` for the read sites.
        markCancelRequested()
        recorderQueue.async { [weak self] in
            self?.stopOnQueue(deleteFiles: true)
        }
    }

    // MARK: - Queue-bound implementation

    private func startOnQueue() {
        guard !isRunningInternal else {
            deliver { d, me in d.voiceRecorder(me, didFailWith: RecorderError.alreadyRunning) }
            return
        }
        isRunningInternal = true
        clearRequestFlagsOnQueue()
        perTapChunks.removeAll(keepingCapacity: true)
        perTapURLs.removeAll(keepingCapacity: true)
        failedTaps.removeAll(keepingCapacity: true)

        // Allocate per-tap chunk buffers + output URLs first so the audio
        // thread tap callback can `perTapChunks[id]!.append` without an
        // optional dance.
        do {
            try FileManager.default.createDirectory(at: outputDirectory,
                                                    withIntermediateDirectories: true)
        } catch {
            // Filesystem failure — NOT an audio-engine failure. Use the
            // dedicated `outputDirectoryUnavailable` case so logs / Sentry
            // route disk-full / NSFileProtection blocks to filesystem
            // triage instead of mic / AVAudioSession dead ends.
            isRunningInternal = false
            deliver { d, me in d.voiceRecorder(me, didFailWith: RecorderError.outputDirectoryUnavailable(underlying: error)) }
            return
        }
        let stamp = Int64(Date().timeIntervalSince1970 * 1000)
        for r in recipes {
            perTapChunks[r.id] = []
            // Embed the recipe id for debug-only correlation; the recipient
            // never sees this filename — `ConversationViewController+Audio`
            // re-wraps the picked URL with a neutral `<timestamp>.m4a` name
            // before attaching it. Matches the Android `prepareSendAttachmentPush`
            // override that strips the recipe id from the visible name.
            perTapURLs[r.id] = outputDirectory.appendingPathComponent("vm-\(stamp)-\(r.id).m4a")
        }

        // SDK init. This can take ~100–600 ms (DFN cold start), so call it
        // BEFORE installing the audio tap; the user-visible start latency
        // already accounts for the long-press gesture activation.
        let tapEntries: [(id: String, config: PipelineTapConfig)] =
            recipes.map { (id: $0.id, config: $0.sdkTapConfig) }
        pipeline = OfflineAudioPipeline(
            taps: tapEntries,
            initialModule: denoiseModel
        )

        // Build the AVAudioEngine + tap. The session category is whatever the
        // caller / call stack last set — we deliberately do NOT touch
        // `AVAudioSession` here. Production rules in
        // `OWSAudioSession.startRecordingAudioActivity` already handle the
        // "in a LiveKit call → don't switch category" case; we trust that.
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        // With no usable input route (e.g. `.playback` category during a
        // call's connecting / just-hung-up window) the format is 0 Hz / 0 ch;
        // `installTap` would throw an uncatchable NSException.
        // Crashlytics: 43c609123de74e96cfb27e36c5402942
        guard Self.isRecordableInputFormat(inputFormat) else {
            logInvalidInputFormat(inputFormat)
            failStartOnQueue(error: RecorderError.invalidInputFormat(
                sampleRate: inputFormat.sampleRate,
                channelCount: inputFormat.channelCount
            ))
            return
        }
        guard let converter = AVAudioConverter(from: inputFormat, to: Self.processingFormat) else {
            failStartOnQueue(error: RecorderError.noConverter)
            return
        }
        self.engine = engine
        self.inputConverter = converter

        input.installTap(onBus: 0, bufferSize: Self.tapBufferSize, format: inputFormat) { [weak self] buffer, _ in
            // AUDIO THREAD. Copy + dispatch onto the serial queue. The buffer
            // we receive is owned by AVAudioEngine and reused, so we have to
            // copy the float data out before the closure returns.
            guard let self = self else { return }
            guard let copy = Self.cloneBuffer(buffer) else { return }
            // Inner closure also captures self weakly. Audio thread can
            // burst-dispatch many buffers (route changes, main hogged); a
            // strong capture here would pin the recorder + DFN context +
            // engine alive past `voiceRecorder = nil` until the queue
            // drained. Weak makes teardown immediate once the strong path
            // (engine.stop + tap remove) completes.
            self.recorderQueue.async { [weak self] in
                self?.consumeOnQueue(buffer: copy)
            }
        }

        do {
            try engine.start()
        } catch {
            failStartOnQueue(error: RecorderError.audioEngineFailed(underlying: error))
            return
        }

        setStartedAtMs(Int64(Date.ows_millisecondTimestamp()))
        deliver { d, me in d.voiceRecorderDidStart(me) }
    }

    /// Common rollback for any failure during `startOnQueue` AFTER the
    /// per-recording `outputDirectory` was created. Drops the pipeline,
    /// tears down the engine if it got built, and removes the empty
    /// recordingDir so we don't leak a fresh tmp subdir for every failed
    /// start. Mirrors the cancel-path cleanup in `finishCancelPathOnQueue`.
    private func failStartOnQueue(error: RecorderError) {
        isRunningInternal = false
        tearDownEngine()
        pipeline?.release()
        pipeline = nil
        try? FileManager.default.removeItem(at: outputDirectory)
        resetSessionStateOnQueue()
        deliver { d, me in d.voiceRecorder(me, didFailWith: error) }
    }

    /// Consume one mic buffer: convert 44.1k→48k mono float32, run multi-tap
    /// processing, append to per-tap chunk buffers. Runs on `recorderQueue`.
    private func consumeOnQueue(buffer: AVAudioPCMBuffer) {
        guard isRunningInternal, !cancelRequested, !stopRequested else { return }
        guard let pipeline = pipeline, let converter = inputConverter else { return }

        // Convert into a temporary 48 kHz mono buffer.
        let outCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * (Self.sampleRate / buffer.format.sampleRate) + 16
        )
        guard let mono = AVAudioPCMBuffer(pcmFormat: Self.processingFormat,
                                          frameCapacity: max(outCapacity, 1)) else { return }
        var fed = false
        let status = converter.convert(to: mono, error: nil) { _, outStatus in
            if fed { outStatus.pointee = .noDataNow; return nil }
            fed = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, mono.frameLength > 0,
              let chPtr = mono.floatChannelData?[0] else { return }

        let input = Array(UnsafeBufferPointer(start: chPtr, count: Int(mono.frameLength)))
        let outs = pipeline.processTaps(input)
        for r in recipes {
            if failedTaps.contains(r.id) { continue }
            if let chunk = outs[r.id], !chunk.isEmpty {
                perTapChunks[r.id, default: []].append(chunk)
            }
        }
    }

    private func stopOnQueue(deleteFiles: Bool) {
        guard isRunningInternal else {
            // A previous stop/cancel already ran the terminal path. If an
            // in-flight `stopOnQueue` is still writing files but cancel
            // arrived afterwards, IT will see `cancelRequested` flip in its
            // own post-finalize check (see below) and route to didCancel.
            // Nothing for this enqueue to do.
            return
        }

        // Decide cancel-vs-stop intent. A cancel flag latched BEFORE this
        // method ran (e.g. cancel() executed between stop() and stop's
        // dispatch arriving here) wins over the stop. The same logic at
        // post-finalize handles cancels arriving DURING the slow write.
        let isCancel = deleteFiles || cancelRequested

        isRunningInternal = false

        // Tell the UI the user has lifted their finger ASAP; the actual file
        // write below can take a moment.
        deliver { d, me in d.voiceRecorderDidRequestStop(me) }
        tearDownEngine()

        if isCancel {
            finishCancelPathOnQueue()
            return
        }

        // Normal stop path: flush + write all candidates.
        let candidates = finalizeAndWriteOnQueue()

        // **Late-cancel detection.** If `cancelRequested` flipped during the
        // (potentially multi-second) write — typical trigger: user pressed
        // Home / navigated away / a call came in while we were saving —
        // throw the written files away and deliver didCancel instead of
        // didFinish. Without this check, the recorder would deliver
        // didFinish anyway and the caller's `tryToSendAttachments` would
        // ship a voice memo the user thought they had cancelled.
        if cancelRequested {
            for c in candidates {
                if let url = c.fileURL { try? FileManager.default.removeItem(at: url) }
            }
            finishCancelPathOnQueue()
            return
        }

        let startMs = startedAtMsLocked
        let durationMs: Int64 = startMs == 0
            ? 0
            : Int64(Date.ows_millisecondTimestamp()) - startMs
        resetSessionStateOnQueue()

        let withDuration = candidates.map { c in
            VoiceMessageRecordingCandidate(
                recipe: c.recipe,
                fileURL: c.fileURL,
                durationMs: durationMs
            )
        }
        deliver { d, me in d.voiceRecorder(me, didFinish: withDuration) }
    }

    /// Release pipeline + delete any candidate slots + reset per-session
    /// state + deliver `didCancel`. Used by both the explicit `cancel()`
    /// path and the late-cancel detection inside the stop path.
    private func finishCancelPathOnQueue() {
        pipeline?.release()
        pipeline = nil
        for url in perTapURLs.values {
            try? FileManager.default.removeItem(at: url)
        }
        // Best-effort: drop the per-recording subdir we created in
        // `startOnQueue` so we don't leave dangling tmp dirs after every
        // cancelled recording. (Picked-candidate sibling cleanup on the
        // happy path is tracked separately as [H2].)
        try? FileManager.default.removeItem(at: outputDirectory)
        resetSessionStateOnQueue()
        deliver { d, me in d.voiceRecorderDidCancel(me) }
    }

    /// Clear all per-recording in-memory state. Called at the end of every
    /// terminal path (didFinish, didCancel, didFailWith — when applicable).
    /// `_startedAtMs` reset goes through the lock so a stray late-arrival
    /// `currentTime` read on main snaps back to 0 immediately.
    private func resetSessionStateOnQueue() {
        setStartedAtMs(0)
        perTapChunks.removeAll()
        perTapURLs.removeAll()
        failedTaps.removeAll()
    }

    /// Flush the pipeline tail, write every candidate's chunks to disk via
    /// AVAudioFile, and return the candidate list.
    private func finalizeAndWriteOnQueue() -> [VoiceMessageRecordingCandidate] {
        if let pipeline = pipeline {
            let tails = pipeline.flushTaps()
            for r in recipes {
                if let tail = tails[r.id], !tail.isEmpty {
                    perTapChunks[r.id, default: []].append(tail)
                }
            }
        }
        pipeline?.release()
        pipeline = nil

        var result: [VoiceMessageRecordingCandidate] = []
        result.reserveCapacity(recipes.count)
        for r in recipes {
            guard let url = perTapURLs[r.id] else {
                result.append(VoiceMessageRecordingCandidate(recipe: r, fileURL: nil, durationMs: 0))
                continue
            }
            let chunks = perTapChunks[r.id] ?? []
            let ok = writeChunksToFile(chunks, at: url)
            if !ok {
                try? FileManager.default.removeItem(at: url)
                result.append(VoiceMessageRecordingCandidate(recipe: r, fileURL: nil, durationMs: 0))
                continue
            }
            // Guard against zero-byte writes that somehow report success —
            // matches the Android picker-hardening fix.
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size]) as? Int ?? 0
            if size <= 0 {
                try? FileManager.default.removeItem(at: url)
                result.append(VoiceMessageRecordingCandidate(recipe: r, fileURL: nil, durationMs: 0))
            } else {
                result.append(VoiceMessageRecordingCandidate(recipe: r, fileURL: url, durationMs: 0))
            }
        }
        return result
    }

    private func writeChunksToFile(_ chunks: [[Float]], at url: URL) -> Bool {
        guard !chunks.isEmpty else { return false }
        do {
            let file = try AVAudioFile(
                forWriting: url,
                settings: Self.writerFormatSettings,
                commonFormat: .pcmFormatFloat32,
                interleaved: false
            )
            for chunk in chunks where !chunk.isEmpty {
                guard let buf = AVAudioPCMBuffer(pcmFormat: Self.processingFormat,
                                                 frameCapacity: AVAudioFrameCount(chunk.count)),
                      let channel = buf.floatChannelData?[0] else { continue }
                buf.frameLength = AVAudioFrameCount(chunk.count)
                chunk.withUnsafeBufferPointer { src in
                    if let base = src.baseAddress {
                        channel.update(from: base, count: chunk.count)
                    }
                }
                try file.write(from: buf)
            }
            return true
        } catch {
            return false
        }
    }

    private func tearDownEngine() {
        guard let engine = engine else { return }
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        engine.reset()
        self.engine = nil
        self.inputConverter = nil
    }

    // MARK: - Helpers

    private static func isRecordableInputFormat(_ format: AVAudioFormat) -> Bool {
        format.sampleRate > 0 && format.channelCount > 0
    }

    private func logInvalidInputFormat(_ format: AVAudioFormat) {
        let session = AVAudioSession.sharedInstance()
        let route = session.currentRoute
        let inputs = route.inputs.map { "\($0.portType.rawValue):\($0.portName)" }.joined(separator: ",")
        let outputs = route.outputs.map { "\($0.portType.rawValue):\($0.portName)" }.joined(separator: ",")
        Logger.warn(
            "voice recorder input format is not recordable: " +
                "sampleRate=\(format.sampleRate), channels=\(format.channelCount), " +
                "category=\(session.category.rawValue), mode=\(session.mode.rawValue), " +
                "inputs=[\(inputs)], outputs=[\(outputs)]"
        )
    }

    /// Deep-copy an AVAudioPCMBuffer's float data so the audio thread can
    /// hand it off to another queue safely. AVAudioEngine reuses the
    /// underlying storage across tap callbacks, so a shallow reference would
    /// race with subsequent callbacks.
    private static func cloneBuffer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format,
                                          frameCapacity: buffer.frameLength) else { return nil }
        copy.frameLength = buffer.frameLength
        let channels = Int(buffer.format.channelCount)
        if buffer.format.commonFormat == .pcmFormatFloat32,
           let srcPtrs = buffer.floatChannelData,
           let dstPtrs = copy.floatChannelData {
            for ch in 0..<channels {
                dstPtrs[ch].update(from: srcPtrs[ch], count: Int(buffer.frameLength))
            }
        }
        return copy
    }

    /// Hop delegate callbacks to the main thread. The recorder's public
    /// `start/stop/cancel` API doesn't promise threading, but historically
    /// every delegate callback in TempTalk runs on main, and `RecordingLimitProcessor`
    /// + UI updates require it.
    private func deliver(_ block: @escaping (DualCandidateVoiceRecorderDelegate, DualCandidateVoiceRecorder) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let d = self.delegate else { return }
            block(d, self)
        }
    }
}
