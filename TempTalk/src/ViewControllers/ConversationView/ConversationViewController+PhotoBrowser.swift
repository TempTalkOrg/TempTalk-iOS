//
//  ConversationViewController+PhotoBrowser.swift
//  Signal
//
//  Created by Jaymin on 2024/2/1.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import Photos
import TTMessaging
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
                self.showMediaPreview(assets: assets, isFullImage: isFullImage)
            }
            viewState.photoBrowser = newBrowser
            return newBrowser
        }
    }

    /// Presents immediately and lets `MediaPreviewProcessor` prepare each asset
    /// in the background. No eager fetch here: pulling an attachment per asset
    /// before presenting would block on the slowest one — an undownloaded iCloud
    /// video stalls the whole batch behind a full-screen spinner — and the work
    /// gets redone on `.ready` anyway. Each cell shows its own spinner instead.
    func showMediaPreview(assets: [PHAsset], isFullImage: Bool) {
        AssertIsOnMainThread()

        let items = assets.map { MediaPreviewItem(asset: $0, isFullImage: isFullImage) }
        guard !items.isEmpty else { return }

        let isConfidential = thread.conversationEntity?.confidentialMode == .confidential
        let nav = MediaPreviewViewController.wrappedInNavController(
            items: items,
            isConfidential: isConfidential,
            delegate: self
        )
        present(nav, animated: true)
    }
}
