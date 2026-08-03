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
        navigationController?.setToolbarHidden(true, animated: false)
        lockDownNavigationBar()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // QuickLook may re-add its built-in share/action button after layout; keep it gone.
        lockDownNavigationBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // QuickLook adds its share/save chrome asynchronously after the preview loads,
        // i.e. after our earlier lifecycle clears. Clear once more shortly after.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.lockDownNavigationBar()
        }
        markAsReadAndDelete()
        DTConfidentialHintToast().show(in: view)
    }

    // MARK: - Present

    func present(from presenter: UIViewController) {
        // Embed in our own nav controller so QuickLook puts its share button on
        // self.navigationItem (which we can clear). Presented standalone, the share
        // button lives on QuickLook's private bar and can't be removed.
        let nav = OWSNavigationController(rootViewController: self)
        nav.modalPresentationStyle = .fullScreen
        presenter.present(nav, animated: true)
    }

    // MARK: - Private

    /// Confidential = view-only: strip QuickLook's built-in share/action button and its
    /// title dropdown menu (Save to Files / export / duplicate), and provide our own close button.
    private func lockDownNavigationBar() {
        if !(navigationItem.rightBarButtonItems?.isEmpty ?? true) {
            navigationItem.rightBarButtonItems = []
        }
        // QuickLook also puts a share/action button in the bottom toolbar (bottom-left);
        // clear its items and keep the toolbar hidden (QuickLook re-shows it otherwise).
        if !(toolbarItems?.isEmpty ?? true) {
            toolbarItems = []
        }
        navigationController?.setToolbarHidden(true, animated: false)
        // QuickLook exposes save/export through the interactive document title menu.
        if #available(iOS 16.0, *) {
            navigationItem.titleMenuProvider = nil
            navigationItem.documentProperties = nil
        }
        if navigationItem.leftBarButtonItem == nil {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(closeButtonTapped)
            )
        }
    }

    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }

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
