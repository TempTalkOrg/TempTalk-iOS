//
//  DTConfidentialFilePreviewController.swift
//  TempTalk
//
//  Created by henry on 2026/03/12.
//  Copyright © 2026 Difft. All rights reserved.
//

import UIKit
import QuickLook
import TTServiceKit
import TTMessaging

// MARK: - DTConfidentialFilePreviewController

final class DTConfidentialFilePreviewController: QLPreviewController {

    // MARK: - Properties

    private let fileURL: URL
    private let incomingMessage: TSIncomingMessage?
    private let previewDataSource: DTConfidentialFilePreviewDataSource
    private var hasMarkedAsRead = false

    // MARK: - Init

    @available(*, unavailable, message: "use init(fileURL:incomingMessage:) instead.")
    required init?(coder: NSCoder) {
        fatalError("\(#function) is unimplemented.")
    }

    init(fileURL: URL, incomingMessage: TSIncomingMessage?) {
        self.fileURL = fileURL
        self.incomingMessage = incomingMessage
        self.previewDataSource = DTConfidentialFilePreviewDataSource(fileURL: fileURL)
        super.init(nibName: nil, bundle: nil)
        self.dataSource = previewDataSource
        self.delegate = self
        self.currentPreviewItemIndex = 0
    }

    // MARK: - Lifecycle

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setToolbarHidden(false, animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        markAsReadAndDelete()
        DTConfidentialHintToast().show(in: view)
    }

    // MARK: - Present

    func present(from presenter: UIViewController) {
        modalPresentationStyle = .fullScreen
        presenter.present(self, animated: true)
    }

    // MARK: - Private

    private func markAsReadAndDelete() {
        guard !hasMarkedAsRead, let incomingMessage else { return }
        hasMarkedAsRead = true
        OWSReadReceiptManager.shared().confidentialMessageWasReadLocally(incomingMessage)
        databaseStorage.asyncWrite { [incomingMessage] transaction in
            incomingMessage.anyRemove(transaction: transaction)
        }
    }
}

// MARK: - QLPreviewControllerDelegate

extension DTConfidentialFilePreviewController: QLPreviewControllerDelegate {
    func previewController(_ controller: QLPreviewController, editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
        .disabled
    }
}

// MARK: - DTConfidentialFilePreviewDataSource

final class DTConfidentialFilePreviewDataSource: NSObject, QLPreviewControllerDataSource {

    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        fileURL as QLPreviewItem
    }
}
