//
//  MediaSavePolicyManager .swift
//  Pods
//
//  Created by Henry on 2025/6/14.
//

import Photos

// 保存到相册的策略枚举
@objc public enum MediaSavePolicy: Int {
    case defaultPolicy = 0  // 使用全局设置
    case always = 1         // 总是保存
    case never = 2          // 从不保存
}

@objcMembers
public class MediaSavePolicyManager: NSObject {
    public static let shared = MediaSavePolicyManager()

    private override init() {}
    private let keyValueStore = SDSKeyValueStore(collection: "DTSettingsKeyValueCollection")
    static let kSettingsStorageGlobalNotificationKey = "kSettingsStorageGlobalNotificationKey"
    static let kVoicePlaybackSpeedKey = "kVoicePlaybackSpeedKey"

    // MARK: - Save to Photo

    // 全局设置：保存到相册的开关
    public func updateSaveToPhoto(needSave: Bool)  {
        self.databaseStorage.asyncWrite { transaction in
            self.keyValueStore.setBool(needSave, key: MediaSavePolicyManager.kSettingsStorageGlobalNotificationKey, transaction: transaction)
            Logger.info("update sync Save Photo status \(needSave)")
        }
    }

    public func getSaveToPhotoStatus() -> Bool {
        var needSave = false
        self.databaseStorage.read { transaction in
            needSave = self.keyValueStore.getBool(MediaSavePolicyManager.kSettingsStorageGlobalNotificationKey, transaction: transaction) ?? false
            Logger.info("get sync Save Photo info \(needSave)")
        }
        return needSave
    }

    // MARK: - Voice Playback Speed

    // 更新播放速度
    public func updatePlaybackSpeed(_ speed: Float) {
        self.databaseStorage.asyncWrite { transaction in
            self.keyValueStore.setDouble(Double(speed), key: MediaSavePolicyManager.kVoicePlaybackSpeedKey, transaction: transaction)
            Logger.info("update voice playback speed to \(speed)")
        }
    }

    // 获取播放速度
    public func getPlaybackSpeed() -> Float {
        var speed: Float = 1.0
        self.databaseStorage.read { transaction in
            let doubleValue = self.keyValueStore.getDouble(MediaSavePolicyManager.kVoicePlaybackSpeedKey, defaultValue: 1.0, transaction: transaction)
            speed = Float(doubleValue)
            Logger.info("get voice playback speed: \(speed)")
        }
        return speed
    }

    // MARK: - Conversation Save Policy

    // 会话级别设置：保存策略
    public func updateConversationSavePolicy(threadId: String, policy: MediaSavePolicy) {
        self.databaseStorage.asyncWrite { transaction in
            let key = "conversation_save_policy_\(threadId)"
            self.keyValueStore.setInt(policy.rawValue, key: key, transaction: transaction)
            Logger.info("update conversation \(threadId) save policy to \(policy.rawValue)")
        }
    }

    public func getConversationSavePolicy(threadId: String) -> MediaSavePolicy {
        var policyValue = MediaSavePolicy.defaultPolicy.rawValue
        self.databaseStorage.read { transaction in
            let key = "conversation_save_policy_\(threadId)"
            policyValue = self.keyValueStore.getInt(key, transaction: transaction) ?? MediaSavePolicy.defaultPolicy.rawValue
            Logger.info("get conversation \(threadId) save policy: \(policyValue)")
        }
        return MediaSavePolicy(rawValue: policyValue) ?? .defaultPolicy
    }

    // 判断是否应该保存（考虑优先级）
    public func shouldSaveForConversation(threadId: String) -> Bool {
        let policy = getConversationSavePolicy(threadId: threadId)

        switch policy {
        case .always:
            return true
        case .never:
            return false
        case .defaultPolicy:
            return getSaveToPhotoStatus()
        }
    }

    /// Checks auto-save policy without reading attachment bytes.
    @objc(shouldSaveMediaForThreadId:)
    public func shouldSaveMedia(threadId: String?) -> Bool {
        guard let threadId else {
            return getSaveToPhotoStatus()
        }
        return shouldSaveForConversation(threadId: threadId)
    }

    public func saveImageIfNeeded(_ image: UIImage, threadId: String? = nil) {
        guard shouldSaveMedia(threadId: threadId) else {
            return
        }

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            if !success {
                Logger.error("camera image save failed error: \(String(describing: error))")
            }
        }
    }

    public func saveVideoIfNeeded(_ url: URL, threadId: String? = nil) {
        guard shouldSaveMedia(threadId: threadId) else {
            return
        }

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) { success, error in
            if !success {
                Logger.error("camera video save failed error: \(String(describing: error))")
            }
        }
    }

    /// Saves decrypted video data directly to PhotoKit.
    public func saveVideoDataIfNeeded(_ data: Data, contentType: String, threadId: String? = nil) {
        guard shouldSaveMedia(threadId: threadId) else { return }

        PHPhotoLibrary.shared().performChanges({
            let request = PHAssetCreationRequest.forAsset()
            let options = PHAssetResourceCreationOptions()
            options.uniformTypeIdentifier = MIMETypeUtil.utiType(forMIMEType: contentType)
            request.addResource(with: .video, data: data, options: options)
        }) { success, error in
            if !success {
                Logger.error("camera video data save failed error: \(String(describing: error))")
            }
        }
    }
}
