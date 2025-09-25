//
//  MediaSavePolicyManager .swift
//  Pods
//
//  Created by Henry on 2025/6/14.
//

import Photos

@objcMembers
public class MediaSavePolicyManager: NSObject {
    public static let shared = MediaSavePolicyManager()

    private override init() {}
    private let keyValueStore = SDSKeyValueStore(collection: "DTSettingsKeyValueCollection")
    static let kSettingsStorageGlobalNotificationKey = "kSettingsStorageGlobalNotificationKey"
    
    public func updateSaveToPhoto(needSave: Bool)  {
        self.databaseStorage.asyncWrite { transaction in
            self.keyValueStore.setBool(needSave, key: MediaSavePolicyManager.kSettingsStorageGlobalNotificationKey, transaction: transaction)
            Logger.info("update sync Save Photo status \(needSave)")
        }
    }
    
    public func getSaveToPhotoStatus() -> Bool {
        var needSave = true
        self.databaseStorage.read { transaction in
            needSave = self.keyValueStore.getBool(MediaSavePolicyManager.kSettingsStorageGlobalNotificationKey, transaction: transaction) ?? false
            Logger.info("get sync Save Photo info \(needSave)")
        }
        return needSave
    }


    public func saveImageIfNeeded(_ image: UIImage) {
        guard getSaveToPhotoStatus() else {
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }) { success, error in
            if success {
                Logger.info("camera image save success")
            } else {
                Logger.info("camera image save failed error: \(error?.localizedDescription)")
            }
        }
    }

    public func saveVideoIfNeeded(_ url: URL) {
        guard getSaveToPhotoStatus() else {
            return
        }
        
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }) { success, error in
            if success {
                Logger.info("camera video save success")
            } else {
                Logger.info("camera video save failed error: \(error?.localizedDescription)")
            }
        }
    }
}

