//
//  ConversationViewController+DocumentPicker.swift
//  Signal
//
//  Created by Jaymin on 2024/2/1.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import CoreServices
import TTMessaging
import TTServiceKit

// MARK: - Public

extension ConversationViewController {
    func showDocumentPicker() {
        // UIDocumentPickerModeImport copies to a temp file within our container.
        // It uses more memory than "open" but lets us avoid working with security scoped URLs.
        let allDocumentTypes = kUTTypeItem as String
        let pickerController = UIDocumentPickerViewController(
            documentTypes: [allDocumentTypes],
            in: .import
        )
        pickerController.delegate = self
        
        dismissKeyBoard()
        presentFormSheet(pickerController, animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate

extension ConversationViewController: UIDocumentPickerDelegate {
    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        Logger.debug("Picked document at url: \(url)")

        let typeIdentifier: String = {
            do {
                let resourceValues = try url.resourceValues(forKeys: Set([
                    .typeIdentifierKey
                ]))
                guard let typeIdentifier = resourceValues.typeIdentifier else {
                    owsFailDebug("Missing typeIdentifier.")
                    return kUTTypeData as String
                }
                return typeIdentifier
            } catch {
                owsFailDebug("Error: \(error)")
                return kUTTypeData as String
            }
        }()
        let isDirectory: Bool = {
            do {
                let resourceValues = try url.resourceValues(forKeys: Set([
                    .isDirectoryKey
                ]))
                guard let isDirectory = resourceValues.isDirectory else {
                    owsFailDebug("Missing isDirectory.")
                    return false
                }
                return isDirectory
            } catch {
                owsFailDebug("Error: \(error)")
                return false
            }
        }()

        if isDirectory {
            Logger.info("User picked directory.")

            DispatchQueue.main.async {
                OWSActionSheets.showActionSheet(title: Localized("ATTACHMENT_PICKER_DOCUMENTS_PICKED_DIRECTORY_FAILED_ALERT_TITLE", "Alert title when picking a document fails because user picked a directory/bundle"),
                                                message: Localized("ATTACHMENT_PICKER_DOCUMENTS_PICKED_DIRECTORY_FAILED_ALERT_BODY", "Alert body when picking a document fails because user picked a directory/bundle"))
            }
            return
        }

        let filename: String = {
            if let filename = url.lastPathComponent.strippedOrNil {
                return filename
            }
            owsFailDebug("Unable to determine filename")
            return Localized("ATTACHMENT_DEFAULT_FILENAME", "Generic filename for an attachment with no known name")
        }()

        func buildDataSource() -> DataSource? {
            do {
                return try DataSourcePath.dataSource(with: url,
                                                     shouldDeleteOnDeallocation: false)
            } catch {
                owsFailDebug("Error: \(error).")
                return nil
            }
        }
        guard let dataSource = buildDataSource() else {
            DispatchQueue.main.async {
                OWSActionSheets.showActionSheet(title: Localized("ATTACHMENT_PICKER_DOCUMENTS_FAILED_ALERT_TITLE", "Alert title when picking a document fails for an unknown reason"))
            }
            return
        }
        dataSource.sourceFilename = filename

        // Although we want to be able to send higher quality attachments through the document picker
        // it's more important that we ensure the sent format is one all clients can accept (e.g. *not* quicktime .mov)
        if SignalAttachment.isInvalidVideo(dataSource: dataSource, dataUTI: typeIdentifier) {
            self.showApprovalDialogAfterProcessingVideoURL(url, filename: filename)
            return
        }

        // "Document picker" attachments _SHOULD NOT_ be resized, if possible.
        let attachment = SignalAttachment.attachment(dataSource: dataSource, dataUTI: typeIdentifier)
        showApprovalDialog(forAttachment: attachment)
    }
    
    private func showApprovalDialogAfterProcessingVideoURL(_ movieURL: URL, filename: String?) {
        AssertIsOnMainThread()

        ModalActivityIndicatorViewController.present(
            fromViewController: self,
            canCancel: true
        ) { modalActivityIndicator in
            
            let dataSource: DataSource
            do {
                dataSource = try DataSourcePath.dataSource(with: movieURL, shouldDeleteOnDeallocation: false)
            } catch {
                owsFailDebug("Error: \(error).")
                DispatchMainThreadSafe { self.showErrorAlert(forAttachment: nil) }
                return
            }
            dataSource.sourceFilename = filename
            
            let (promise, session) = SignalAttachment.compressVideoAsMp4(
                dataSource: dataSource,
                dataUTI: kUTTypeMPEG4 as String
            )
            firstly { () -> Promise<SignalAttachment> in
                promise
            }.done(on: DispatchQueue.main) { (attachment: SignalAttachment) in
                if modalActivityIndicator.wasCancelled {
                    session?.cancelExport()
                    return
                }
                modalActivityIndicator.dismiss {
                    if attachment.hasError {
                        owsFailDebug("Invalid attachment: \(attachment.errorName ?? "Unknown error").")
                        self.showErrorAlert(forAttachment: attachment)
                    } else {
                        self.showApprovalDialog(forAttachment: attachment)
                    }
                }
            }.catch(on: DispatchQueue.main) { error in
                owsFailDebug("Error: \(error).")
                
                modalActivityIndicator.dismiss {
                    owsFailDebug("Invalid attachment.")
                    self.showErrorAlert(forAttachment: nil)
                }
            }
        }
    }
}
