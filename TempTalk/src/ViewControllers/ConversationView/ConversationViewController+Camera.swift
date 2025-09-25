//
//  ConversationViewController+Camera.swift
//  Signal
//
//  Created by Jaymin on 2024/2/1.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import Photos
import CoreServices
import TTMessaging
import TTServiceKit

extension ConversationViewController {
    func takePictureOrVideo() {
        AssertIsOnMainThread()
        
        ows_ask(forCameraPermissions: { [weak self] isCameraGranted in
            guard let self else { return }
            guard isCameraGranted else {
                Logger.warn("camera permission denied.")
                return
            }
            
            let imagePicker = UIImagePickerController()
            imagePicker.sourceType = .camera
            imagePicker.mediaTypes = [kUTTypeImage as String, kUTTypeMovie as String]
            imagePicker.allowsEditing = false
            imagePicker.delegate = self
            
            self.dismissKeyBoard()
            self.present(imagePicker, animated: true)
        })
    }
}

extension ConversationViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true)
    }
    
    public func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
    ) {
        // fixes bug on frame being off after this selection
        self.view.frame = UIScreen.main.bounds
        
        guard let referenceURL = info[.referenceURL] as? URL else {
            Logger.verbose("Could not retrieve reference URL for picked asset")
            imagePickerController(picker, didFinishPickingMediaWithInfo: info, fileName: nil)
            return
        }
        
        let asset = PHAsset.fetchAssets(withALAssetURLs: [referenceURL], options: nil).lastObject
        let fileName = asset?.value(forKey: "filename") as? String
        imagePickerController(picker, didFinishPickingMediaWithInfo: info, fileName: fileName)
    }
    
    private func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any],
        fileName: String?
    ) {
        AssertIsOnMainThread()
        
        let mediaType = info[.mediaType] as? String ?? ""
        Logger.debug("Picked mediaType <\(mediaType)> for file: \(fileName ?? "")")
        if mediaType == (kUTTypeMovie as String) {
            dismiss(animated: true) {
                self.sendQualityAdjustedAttachment(pickedInfo: info, fileName: fileName)
                // 如果开启自动保存到相册的逻辑
                if let videoURL = info[.mediaURL] as? URL {
                    MediaSavePolicyManager.shared.saveVideoIfNeeded(videoURL)
                }
            }
            return
        }
        
        if picker.sourceType == .camera {
            // Static Image captured from camera
            let imageFromCamera = (info[.originalImage] as? UIImage)?.normalized()
            dismiss(animated: true) {
                guard let imageFromCamera else {
                    Logger.error("failed to pick attachment")
                    return
                }
                let attachment = SignalAttachment.imageAttachment(
                    image: imageFromCamera,
                    dataUTI: kUTTypeJPEG as String,
                    filename: fileName,
                    imageQuality: .original
                )
                // 如果开启自动保存到相册的逻辑
                if let originImage = info[.originalImage] as? UIImage {
                    MediaSavePolicyManager.shared.saveImageIfNeeded(originImage)
                }
                if attachment.hasError {
                    owsFailDebug("Invalid attachment: \(attachment.errorName ?? "Unknown error").")
                    self.showErrorAlert(forAttachment: attachment)
                } else {
                    self.tryToSendAttachments(
                        [attachment],
                        preSendMessageCallBack: nil,
                        messageText: nil,
                        completion: nil
                    )
                }
            }
        }
    }
    
    private func sendQualityAdjustedAttachment(
        pickedInfo: [UIImagePickerController.InfoKey : Any],
        fileName: String?
    ) {
        AssertIsOnMainThread()
        
        ModalActivityIndicatorViewController.present(
            fromViewController: self,
            canCancel: true
        ) { modalActivityIndicator in
            
            guard let videoURL = pickedInfo[.mediaURL] as? URL else {
                owsFailDebug("Video url not found.")
                DispatchMainThreadSafe { self.showErrorAlert(forAttachment: nil) }
                return
            }
            let dataSource: DataSource
            do {
                dataSource = try DataSourcePath.dataSource(with: videoURL, shouldDeleteOnDeallocation: false)
            } catch {
                owsFailDebug("Error: \(error).")
                DispatchMainThreadSafe { self.showErrorAlert(forAttachment: nil) }
                return
            }
            dataSource.sourceFilename = fileName
            
            let (promise, session) = SignalAttachment.compressVideoAsMp4(
                dataSource: dataSource,
                dataUTI: kUTTypeMPEG4 as String
            )
            firstly {
                promise
            }.done(on: DispatchQueue.main) { attachment in
                guard !modalActivityIndicator.wasCancelled else {
                    session?.cancelExport()
                    return
                }
                modalActivityIndicator.dismiss {
                    if attachment.hasError {
                        owsFailDebug("Invalid attachment: \(attachment.errorName ?? "Unknown error").")
                        self.showErrorAlert(forAttachment: attachment)
                    } else {
                        self.tryToSendAttachments(
                            [attachment],
                            preSendMessageCallBack: nil,
                            messageText: nil,
                            completion: nil
                        )
                    }
                }
            }.catch(on: DispatchQueue.main) { error in
                modalActivityIndicator.dismiss {
                    owsFailDebug("Invalid attachment, error: \(error).")
                    self.showErrorAlert(forAttachment: nil)
                }
            }
        }
    }
}
