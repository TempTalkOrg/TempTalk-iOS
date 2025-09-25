//
//  ConversationViewController+PhotoBrowser.swift
//  Signal
//
//  Created by Jaymin on 2024/2/1.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import Photos
import Dispatch
import CoreServices
import TTServiceKit

// MARK: - Public

extension ConversationViewController {
    func chooseFromLibraryAsMedia() {
        AssertIsOnMainThread()
        self.photoBrowser.showLibrary()
    }
}

// MARK: - Private

private extension ConversationViewController {
    enum TSAttachmentError: Error {
        case missData
        case invalidAttachment(attachment: SignalAttachment)
    }
    
    var photoBrowser: DTPhotoBrowserHelper {
        get {
            if let browser = viewState.photoBrowser {
                return browser
            }
            let newBrowser = DTPhotoBrowserHelper(
                viewController: self,
                maxSelectCount: 9
            ) { [weak self] assets, isFullImage in
                guard let self else { return }
                guard !assets.isEmpty else { return }
                self.createAttacments(assets: assets, isFullImage: isFullImage)
            }
            viewState.photoBrowser = newBrowser
            return newBrowser
        }
    }
    
    var loadingView: UIActivityIndicatorView {
        get {
            if let view = viewState.loadingView {
                return view
            }
            let newView = UIActivityIndicatorView()
            newView.style = .medium
            newView.hidesWhenStopped = true
            self.view.addSubview(newView)
            newView.autoCenterInSuperview()
            
            viewState.loadingView = newView
            return newView
        }
    }
    
    var videoDirectoryPath: String {
        let documentPath = OWSFileSystem.appDocumentDirectoryPath()
        return documentPath + "/wea_photo_video/"
    }
    
    func createAttacments(assets: [PHAsset], isFullImage: Bool) {
        self.loadingView.startAnimating()
        var attachments: [SignalAttachment?] = Array(repeating: nil, count: assets.count)
        
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        func showError(_ error: TSAttachmentError) {
            switch error {
            case .missData:
                showErrorAlert(forAttachment: nil)
            case .invalidAttachment(let attachment):
                showErrorAlert(forAttachment: attachment)
            }
        }
        
        assets.enumerated().forEach { index, asset in
            queue.async(group: group) { [weak self] in
                guard let self else { return }
                
                group.enter()
                let mediaType = asset.mediaType
                Logger.debug("Picked mediaType \(mediaType) for file: \(asset.value(forKey: "filename") ?? "")")
                
                switch mediaType {
                case .video:
                    self.createAttachmentForVideo(asset, isFullImage: isFullImage) { result in
                        switch result {
                        case .success(let attachment):
                            attachments[index] = attachment
                        case .failure(let error):
                            showError(error)
                        }
                        group.leave()
                    }
                case .image:
                    self.createAttachmentForImage(asset, isFullImage: isFullImage) { result in
                        switch result {
                        case .success(let attachment):
                            attachments[index] = attachment
                        case .failure(let error):
                            showError(error)
                        }
                        group.leave()
                    }
                default:
                    break
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.loadingView.stopAnimating()
            
            let results = attachments.compactMap { $0 }
            self.showApprovalDialog(forAttachments: results)
        }
    }
    
    func createAttachmentForVideo(
        _ video: PHAsset,
        isFullImage: Bool,
        completion: @escaping (Swift.Result<SignalAttachment, TSAttachmentError>) -> Void
    ) {
        let options = PHVideoRequestOptions()
        options.version = .current
        options.deliveryMode = isFullImage ? .highQualityFormat : .automatic
        options.isNetworkAccessAllowed = true
    
        PHImageManager.default().requestAVAsset(
            forVideo: video,
            options: options
        ) { asset, audioMix, info in
            
            guard let asset else {
                let error = info?[PHImageErrorKey] as? NSError
                owsFailDebug("request AVAsset for video failed: \(error?.localizedDescription ?? "Unknown error")")
                DispatchMainThreadSafe { completion(.failure(.missData)) }
                return
            }
            
//            if let track = asset.tracks(withMediaType: .video).first {
//                let size = track.totalSampleDataLength
//                Logger.info("\(size)")
//            }
            
            let fileName = video.value(forKey: "filename") as? String
            let dataUTI: String
            if let urlAsset = asset as? AVURLAsset {
                let url = urlAsset.url
                dataUTI = MIMETypeUtil.utiType(forFileExtension: url.pathExtension) ?? kUTTypeVideo as String
                
                if let dataSource = try? DataSourcePath.dataSource(with: url, shouldDeleteOnDeallocation: false) {
                    if !SignalAttachment.isVideoThatNeedsCompression(dataSource: dataSource, dataUTI: dataUTI) {
                        dataSource.sourceFilename = fileName
                        completion(.success(SignalAttachment.attachment(dataSource: dataSource, dataUTI: dataUTI)))
                        return
                    }
                }
                
            } else {
                dataUTI = kUTTypeVideo as String
            }
            
            Task {
                do {
                    let presentName: String = isFullImage ? AVAssetExportPresetHighestQuality : AVAssetExportPreset640x480
                    let attachment = try await SignalAttachment.compressVideoAsMp4(
                        asset: asset,
                        baseFilename: fileName,
                        dataUTI: dataUTI,
                        presentName: presentName
                    )
                    if attachment.hasError {
                        owsFailDebug("Invalid attachment: \(attachment.errorName ?? "Unknown error").")
                        completion(.failure(.invalidAttachment(attachment: attachment)))
                    } else {
                        completion(.success(attachment))
                    }
                } catch {
                    owsFailDebug("Invalid attachment: \(error).")
                    completion(.failure(.missData))
                }
            }
        }
    }
    
    func createVideoAttachmentForURLAsset(
        _ asset: AVURLAsset,
        fileName: String?,
        completion: @escaping (Swift.Result<SignalAttachment, TSAttachmentError>) -> Void
    ) {
        let url = asset.url
        let dataSource: DataSource
        do {
            dataSource = try DataSourcePath.dataSource(with: url, shouldDeleteOnDeallocation: false)
            dataSource.sourceFilename = fileName
        } catch {
            owsFailDebug("Create dataSource failed: \(error).")
            DispatchMainThreadSafe { completion(.failure(.missData)) }
            return
        }
        
        let (promise, _) = SignalAttachment.compressVideoAsMp4(
            dataSource: dataSource,
            dataUTI: kUTTypeMPEG4 as String
        )
        firstly {
            promise
        }.done(on: DispatchQueue.main) { attachment in
            if attachment.hasError {
                owsFailDebug("Invalid attachment: \(attachment.errorName ?? "Unknown error").")
                completion(.failure(.invalidAttachment(attachment: attachment)))
            } else {
                completion(.success(attachment))
            }
        }.catch(on: DispatchQueue.main) { error in
            owsFailDebug("Invalid attachment: \(error).")
            completion(.failure(.missData))
        }
    }
    
    func createVideoAttachmentForAsset(
        _ asset: AVAsset, 
        fileName: String?,
        completion: @escaping (Swift.Result<SignalAttachment, TSAttachmentError>) -> Void
    ) {
        let directoryPath = self.videoDirectoryPath
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: directoryPath) {
            do {
                try fileManager.createDirectory(atPath: directoryPath, withIntermediateDirectories: true)
            } catch {
                owsFailDebug("Create directory failed: \(error).")
                DispatchMainThreadSafe { completion(.failure(.missData)) }
                return
            }
        }
        let videoName = "\(Date.ows_millisecondTimestamp()).mov"
        let videoURL = URL(fileURLWithPath: directoryPath).appendingPathComponent(videoName)
        guard let exporter = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetHighestQuality
        ) else {
            owsFailDebug("Create AVAssetExportSession failed.")
            DispatchMainThreadSafe { completion(.failure(.missData)) }
            return
        }
        exporter.outputURL = videoURL
        exporter.outputFileType = .mov
        exporter.shouldOptimizeForNetworkUse = true
        exporter.exportAsynchronously {
            DispatchMainThreadSafe {
                guard exporter.status != .failed,
                      exporter.status != .unknown,
                      exporter.status != .cancelled 
                else {
                    owsFailDebug("Export video failed.")
                    completion(.failure(.missData))
                    return
                }
                guard exporter.status == .completed else { return }
                let dataSource: DataSource
                do {
                    dataSource = try DataSourcePath.dataSource(with: videoURL, shouldDeleteOnDeallocation: false)
                    dataSource.sourceFilename = fileName
                } catch {
                    owsFailDebug("Create dataSource failed: \(error).")
                    completion(.failure(.missData))
                    return
                }
                let (promise, _) = SignalAttachment.compressVideoAsMp4(
                    dataSource: dataSource,
                    dataUTI: kUTTypeMPEG4 as String
                )
                firstly {
                    promise
                }.done(on: DispatchQueue.main) { attachment in
                    if attachment.hasError {
                        owsFailDebug("Invalid attachment: \(attachment.errorName ?? "Unknown error").")
                        completion(.failure(.invalidAttachment(attachment: attachment)))
                    } else {
                        completion(.success(attachment))
                    }
                }.catch(on: DispatchQueue.main) { error in
                    owsFailDebug("Invalid attachment: \(error).")
                    completion(.failure(.missData))
                }
            }
        }
    }
    
    func createAttachmentForImage(
        _ asset: PHAsset,
        isFullImage: Bool,
        completion: @escaping (Swift.Result<SignalAttachment, TSAttachmentError>) -> Void
    ) {
        var imageQuality: TSImageQuality = .original
        if asset.mediaSubtypes != .photoScreenshot && !isFullImage {
            imageQuality = .compact
        }
        
        let options = PHImageRequestOptions()
        options.isSynchronous = true // We're only fetching one asset.
        options.isNetworkAccessAllowed = true // iCloud OK
        options.version = .current
        options.deliveryMode = .highQualityFormat // Don't need quick/dirty version
        options.resizeMode = .none
        
        PHImageManager.default().requestImageDataAndOrientation(
            for: asset,
            options: options
        ) { imageData, dataUTI, orientation, info in
            
            guard let imageData, let dataUTI else {
                let error = info?[PHImageErrorKey] as? NSError
                owsFailDebug("request AVAsset for image failed: \(error?.localizedDescription ?? "Unknown error")")
                DispatchMainThreadSafe { completion(.failure(.missData)) }
                return
            }
            
            guard let dataSource = DataSourceValue.dataSource(with: imageData, utiType: dataUTI) else {
                owsFailDebug("Create dataSource for image failed.")
                DispatchMainThreadSafe { completion(.failure(.missData)) }
                return
            }
            dataSource.sourceFilename = asset.value(forKey: "filename") as? String
            
            let attachment = SignalAttachment.attachment(
                dataSource: dataSource,
                dataUTI: dataUTI,
                imageQuality: imageQuality
            )
            if attachment.hasError {
                owsFailDebug("Invalid attachment: \(attachment.errorName ?? "Unknown error").")
                DispatchMainThreadSafe {
                    completion(.failure(.invalidAttachment(attachment: attachment)))
                }
            } else {
                DispatchMainThreadSafe { completion(.success(attachment)) }
            }
        }
    }
}
