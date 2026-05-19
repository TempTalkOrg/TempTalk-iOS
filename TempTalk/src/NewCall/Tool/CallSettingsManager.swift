//
//  CallSettingsManager.swift
//  Difft
//
//  Created by Henry on 2026/3/24.
//  Copyright © 2026 Difft. All rights reserved.
//

import TTServiceKit

extension NSNotification.Name {
    static let denoiseModeDidChange = NSNotification.Name("DenoiseModeDidChange")
    static let voiceChangerPresetDidChange = NSNotification.Name("VoiceChangerPresetDidChange")
}

@objcMembers
class CallSettingsManager: NSObject {
    static let shared = CallSettingsManager()

    private override init() {}
    private let keyValueStore = SDSKeyValueStore(collection: "DTCallSettingsKeyValueCollection")

    private static let kDenoiseModeKey = "denoiseMode"
    private static let kVoicePresetKey = "voicePreset"

    // 变声预设的默认值，未配置或读取失败时回退到此值。
    static let defaultVoicePreset: String = "original"

    // MARK: - Denoise Mode

    func updateDenoiseMode(_ mode: String) {
        databaseStorage.asyncWrite { transaction in
            self.keyValueStore.setString(mode, key: CallSettingsManager.kDenoiseModeKey, transaction: transaction)
        }
    }

    func getDenoiseMode() -> String? {
        var mode: String?
        databaseStorage.read { transaction in
            mode = self.keyValueStore.getString(CallSettingsManager.kDenoiseModeKey, transaction: transaction)
        }
        return mode
    }

    // MARK: - Voice Changer Preset

    // 内存缓存，避免 asyncWrite 尚未落库时读到旧值（UI 勾选错位、进会默认值回退）。
    // 所有读写点均在主线程，不需要额外同步。
    private var _cachedVoicePreset: String?

    func updateVoicePreset(_ preset: String) {
        _cachedVoicePreset = preset
        databaseStorage.asyncWrite { transaction in
            self.keyValueStore.setString(preset, key: CallSettingsManager.kVoicePresetKey, transaction: transaction)
        }
    }

    func getVoicePreset() -> String? {
        if let cached = _cachedVoicePreset { return cached }
        var preset: String?
        databaseStorage.read { transaction in
            preset = self.keyValueStore.getString(CallSettingsManager.kVoicePresetKey, transaction: transaction)
        }
        _cachedVoicePreset = preset
        return preset
    }
}
