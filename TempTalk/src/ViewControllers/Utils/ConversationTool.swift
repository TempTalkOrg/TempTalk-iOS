//
//  ConversationTool.swift
//  Difft
//
//  Created by Henry on 2025/2/26.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import Photos
import ZLPhotoBrowser
import TTMessaging
import TTServiceKit

class ConversationTool {
    
    static let shared = ConversationTool()

    private init() {}
    
    private let maxFileSize: Int64 = 200 * 1024 * 1024
    
    func checkAssetSize(asset: PHAsset) -> Bool {
        // Get resources for the asset
        let resources = PHAssetResource.assetResources(for: asset)
        guard !resources.isEmpty else {
            // If we can't determine the size, allow selection (fallback)
            return true
        }
        
        // Find the primary resource based on asset type
        var targetResource: PHAssetResource?
        if asset.mediaType == .image {
            // For images, prefer the full resolution photo resource
            targetResource = resources.first { $0.type == .photo } ?? resources.first
        } else if asset.mediaType == .video {
            // For videos, prefer the full resolution video resource
            targetResource = resources.first { $0.type == .video } ?? resources.first
        } else {
            // For other types, use the first resource
            targetResource = resources.first
        }
        
        guard let resource = targetResource else {
            return true
        }
        
        // Get file size from resource using KVC (private API, but commonly used)
        // Try fileSize first, then estimatedDataLength as fallback
        var fileSize: Int64?
        
        if let size = resource.value(forKey: "fileSize") as? Int64 {
            fileSize = size
        } else if let estimatedSize = resource.value(forKey: "estimatedDataLength") as? Int64 {
            fileSize = estimatedSize
        }
        
        if let size = fileSize, size > maxFileSize {
            // Show toast on main thread
            DispatchQueue.main.async { [weak self] in
                self?.showFileSizeTooLargeToast()
            }
            return false
        }
        
        return true
    }
    
    func checkAttachmentSize(from info: [UIImagePickerController.InfoKey : Any]) -> Bool {

        // 1) 视频处理
        if let videoURL = info[.mediaURL] as? URL {
            if let fileSize = try? videoURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                if fileSize > maxFileSize {
                    // Show toast on main thread
                    DispatchQueue.main.async { [weak self] in
                        self?.showFileSizeTooLargeToast()
                    }
                    return false
                }
            }
            return true
        }

        // 2) 相册照片（有 PHAsset）
        if let asset = info[.phAsset] as? PHAsset {
            let resources = PHAssetResource.assetResources(for: asset)
            if let resource = resources.first,
               let size = resource.value(forKey: "fileSize") as? CLong {
                if size > maxFileSize {
                    // Show toast on main thread
                    DispatchQueue.main.async { [weak self] in
                        self?.showFileSizeTooLargeToast()
                    }
                    return false
                }
            }
            return true
        }

        // 3) 相机拍摄图片（只有 UIImage）
        if let image = info[.originalImage] as? UIImage,
           let data = image.jpegData(compressionQuality: 1.0) {
            if data.count > maxFileSize {
                // Show toast on main thread
                DispatchQueue.main.async { [weak self] in
                    self?.showFileSizeTooLargeToast()
                }
                return false
            }
        }

        return true
    }

    private func showFileSizeTooLargeToast() {
        let message = Localized("ATTACHMENT_ERROR_FILE_SIZE_TOO_LARGE_TIPS")
        DTToastHelper.toast(withText: message)
    }
}
