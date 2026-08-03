//
//  VoiceMessageRecipe.swift
//  TempTalk
//
//  App-side types describing parallel voice-message candidates produced by a
//  single multi-tap recording pass via `DualCandidateVoiceRecorder`.
//
//  Mirrors the Kotlin / TypeScript counterparts so cross-platform integration
//  and tap-id naming stay identical:
//   - Kotlin:    chat/src/main/java/com/difft/android/chat/voice/VoiceMessageRecipe.kt
//   - TS / web:  ts/components/conversation/voiceMessageEffectProcessor.ts
//

import AudioPipelineProcessor
import Foundation

/// App-friendly voice preset name. Maps to the SDK's underlying SoundTouch
/// preset — kept name-aligned with the RTC call voice changer so the same
/// "higher" / "deeper" buttons across call and voice message sound identical.
///
///   .higher → SDK "goddess" (+4 semitones)
///   .deeper → SDK "uncle"   (-4 semitones)
///
/// Closed enum on purpose: adding a preset should require touching both the
/// call and voice-message UIs at the same time so they stay aligned.
public enum VoiceMessageEffect: String, CaseIterable, Sendable {
    case higher
    case deeper

    internal var sdkPreset: String {
        switch self {
        case .higher: return "goddess"
        case .deeper: return "uncle"
        }
    }

    /// Mirrors `DTUpdateNoiseController.voicePresets` icons.
    public var buttonEmoji: String {
        switch self {
        case .higher: return "🐿️"
        case .deeper: return "🐻"
        }
    }

    /// A fresh random effect for one voice-message recording, independent of
    /// the call voice-changer setting. Each read returns a new random pick, so
    /// call once per recording (at gesture `.began`) and reuse the value for
    /// both the UI label and the recorder recipes — otherwise the shown emoji
    /// and the sent sound can disagree.
    public static var randomForRecording: VoiceMessageEffect {
        Bool.random() ? .higher : .deeper
    }
}

/// One parallel candidate the ``DualCandidateVoiceRecorder`` should produce.
///
/// Each recipe becomes a tap of the underlying multi-tap audio pipeline
/// (shared denoise inference, per-tap voice changer). Mirrors the JS SDK's
/// `VoiceMessageRecipe` shape so cross-platform integration code stays
/// familiar.
public struct VoiceMessageRecipe: Sendable, Equatable {
    /// UI uses this to find the right candidate URL after recording.
    public let id: String
    /// Take the shared denoise output as the tap base.
    public let denoise: Bool
    /// Apply a voice changer preset on top of denoise / raw. `nil` skips it.
    public let effect: VoiceMessageEffect?

    public init(id: String, denoise: Bool = false, effect: VoiceMessageEffect? = nil) {
        self.id = id
        self.denoise = denoise
        self.effect = effect
    }

    /// Convert to the SDK tap config the pipeline is built from. `internal`
    /// because the SDK type shouldn't leak into UI / business code; recipes
    /// flow in, candidates flow out.
    internal var sdkTapConfig: PipelineTapConfig {
        let st = effect.flatMap { SoundTouchConfig.presets[$0.sdkPreset] }
        return PipelineTapConfig(denoise: denoise, soundTouch: st)
    }
}

/// A produced candidate file. `fileURL == nil` means that recipe failed
/// (pipeline init failure, encoder failure, etc.). Callers should fall
/// back gracefully — e.g. pick the first non-nil candidate, or surface
/// "processing failed" to the user.
public struct VoiceMessageRecordingCandidate: Sendable {
    public let recipe: VoiceMessageRecipe
    public let fileURL: URL?
    public let durationMs: Int64

    public init(recipe: VoiceMessageRecipe, fileURL: URL?, durationMs: Int64) {
        self.recipe = recipe
        self.fileURL = fileURL
        self.durationMs = durationMs
    }
}

public enum VoiceMessageRecipes {
    /// Cross-platform default (denoised + denoised+higher).
    public static let `default`: [VoiceMessageRecipe] = recipes(for: .higher)

    /// `[denoised, denoised+<effect>]`. Middle / Add-effect picks 1st / 2nd.
    public static func recipes(for effect: VoiceMessageEffect) -> [VoiceMessageRecipe] {
        [
            VoiceMessageRecipe(id: "denoised", denoise: true),
            VoiceMessageRecipe(id: "denoised+\(effect.rawValue)", denoise: true, effect: effect),
        ]
    }

    /// Default denoise backend used when caller doesn't specify.
    ///
    /// DeepFilterNet ships with a stronger model than RNNoise and matches the
    /// default JS / chative-desktop / TempTalk-Android voice-message build.
    /// Cold-start cost (`df_create_default` on the ~16 MB model) is in the
    /// 100–600 ms range and the recorder hides it behind the
    /// connect-first-then-init pattern: mic capture starts immediately and
    /// pre-init chunks are queued.
    public static let defaultDenoiseModel: AudioModule = .deepfilternet
}
