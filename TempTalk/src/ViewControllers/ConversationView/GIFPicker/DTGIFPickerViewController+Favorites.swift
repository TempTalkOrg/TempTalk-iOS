//
//  DTGIFPickerViewController+Favorites.swift
//  TempTalk
//
//  Favorites tab hosting: bridges DTGIFFavoritesView events to the picker —
//  send a tapped favorite, confirm removal, and kick off favKey recovery.
//

import Foundation
import UIKit
import CoreServices
import TTServiceKit
import TTMessaging

/// GIF favorites size ceiling (10 MB). Favorites aren't compressed, so an oversized GIF would be
/// pinned/uploaded as-is — reject it up front with a toast instead.
private let kMaxGifFavoriteBytes: UInt64 = 10 * 1024 * 1024

/// `false` (+ size-limit toast) when `byteCount` exceeds the ceiling; `true` to proceed. Main thread.
private func gifFavoriteSizeWithinLimit(_ byteCount: UInt64) -> Bool {
    guard byteCount > kMaxGifFavoriteBytes else { return true }
    DTToastHelper.toast(withText: Localized("gif_favorites_add_size_limit"))
    return false
}

/// File size in bytes at `path`, or 0 when unreadable.
private func gifFileByteCount(_ path: String) -> UInt64 {
    let attrs = try? FileManager.default.attributesOfItem(atPath: path)
    return (attrs?[.size] as? NSNumber)?.uint64Value ?? 0
}

/// 200-cap confirmation before adding a favorite (design §4.3). If full, ask to replace the oldest
/// (FIFO eviction happens in the repository on the ensuing favorite); otherwise proceed directly.
enum DTGifFavoriteLimitPrompt {
    static func confirmIfNeeded(present: (ActionSheetController) -> Void, proceed: @escaping () -> Void) {
        guard DTGifFavoritesRepository.shared.favoritesCount() >= DTGifFavoritesRepository.maxFavorites else {
            proceed()
            return
        }
        let sheet = ActionSheetController(title: Localized("gif_favorites_cap_title"),
                                          message: Localized("gif_favorites_cap_message"))
        // Replace the oldest favorite with the current GIF (FIFO eviction happens in the repository).
        sheet.addAction(ActionSheetAction(title: Localized("gif_favorites_cap_confirm"), style: .destructive) { _ in
            proceed()
        })
        // Secondary action: dismiss without adding the current GIF.
        sheet.addAction(ActionSheetAction(title: Localized("gif_favorites_cap_cancel"), style: .cancel))
        present(sheet)
    }
}

/// Favoriting a GIF/WebP message attachment, shared by the main conversation and the
/// combined-forward detail (single & merged forwards). Handles the 200-cap confirm prompt.
enum DTGifFavoriteMessageAction {
    static func addToFavorite(_ item: ConversationViewItem, presenter: UIViewController) {
        guard let stream = item.attachmentStream(),
              let fileHash = DTGifFavoriteTranscoder.fileHash(for: stream) else {
            DTToastHelper.toast(withText: Localized("GIF_FAVORITE_FAILED"))
            return
        }
        let repo = DTGifFavoritesRepository.shared
        let manager = DTGifFavoriteSendManager.shared
        // Already favorited → bump to top (dedup, move-to-front); count doesn't grow, so skip the
        // 200-cap prompt. Enqueues locally + toasts instantly; the job commits/retries in the background.
        if repo.isFavorited(fileHash: fileHash) {
            if let pointer = repo.resolvedPointer(forFileHash: fileHash) {
                manager.enqueueResolvedFavorite(pointer: pointer, giphyId: nil)
            }
            DTToastHelper.toast(withText: Localized("GIF_FAVORITE_ADDED"))
            return
        }
        // New favorite: reject an oversized GIF up front (server-pinned, not compressed).
        // Measure the decrypted file on disk; byteCount is sender-declared metadata and may under-report.
        let fileBytes = stream.filePath().map { gifFileByteCount($0) } ?? 0
        let effectiveBytes = fileBytes > 0 ? fileBytes : UInt64(stream.byteCount)
        guard gifFavoriteSizeWithinLimit(effectiveBytes) else { return }
        DTGifFavoriteLimitPrompt.confirmIfNeeded(present: { [weak presenter] sheet in
            presenter?.presentActionSheet(sheet)
        }, proceed: {
            // Optimistic: seeds display + enqueues; upload/commit deferred to the retryable job.
            manager.enqueueMessageFavorite(stream: stream)
            DTToastHelper.toast(withText: Localized("GIF_FAVORITE_ADDED"))
        })
    }
}

extension DTGIFPickerViewController: DTGIFFavoritesViewDelegate {

    func favoritesView(_ view: DTGIFFavoritesView, didSelect fileURL: URL) {
        do {
            // Copy out of the shared cache so sending can own/consume its file.
            let tempPath = OWSFileSystem.temporaryFilePath(fileExtension: "gif")
            try FileManager.default.copyItem(atPath: fileURL.path, toPath: tempPath)
            let dataSource = try DataSourcePath.dataSource(withFilePath: tempPath,
                                                           shouldDeleteOnDeallocation: false)
            let attachment = SignalAttachment.attachment(dataSource: dataSource,
                                                         dataUTI: kUTTypeGIF as String)
            // Same as the other tabs: close the keyboard panel, then send (conversation owns state).
            if isHostedInKeyboard {
                delegate?.gifPickerViewControllerRequestDismiss(self)
            }
            delegate?.gifPickerViewController(self, didSelect: attachment)
        } catch {
            Logger.error("[GifFav] build favorite attachment failed: \(error)")
        }
    }

}

// MARK: - Add a panel GIF to favorites (long-press on search/trending)

extension DTGIFPickerViewController {

    @objc
    func handlePanelLongPress(_ gesture: UILongPressGestureRecognizer) {
        // Any waterfall tab (trending / happy / sad / search results) can favorite;
        // the favorites tab renders its own view, not this collection view.
        guard gesture.state == .began, !collectionView.isHidden else { return }
        let point = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point),
              let cell = collectionView.cellForItem(at: indexPath) as? DTGIFPickerCell,
              cell.isDisplayingAsset,
              let giphyId = cell.assetInfo?.identifier, !giphyId.isEmpty else { return }

        // The search/trending grid only offers "add to favorite" — removal lives in the favorites tab.
        let anchorRect = collectionView.convert(cell.frame, to: view)
        DTGifFavoriteActionPopover.present(
            in: view, anchorRect: anchorRect, mode: .add
        ) { [weak self, weak cell] in
            guard let self, let cell else { return }
            self.addPanelGifToFavorites(cell, giphyId: giphyId)
        }
    }

    /// Download the picked GIF, upload it as an account-level asset, then favorite it.
    private func addPanelGifToFavorites(_ cell: DTGIFPickerCell, giphyId: String) {
        // Already favorited on this device → bump it to the top (dedup, then move-to-front)
        // without re-uploading; also skips the 200-cap prompt since the count doesn't grow.
        guard !DTGifFavoritesRepository.shared.isGiphyFavorited(giphyId) else {
            DTGifFavoriteSendManager.shared.enqueueBump(giphyId: giphyId)
            DTToastHelper.toast(withText: Localized("GIF_FAVORITE_ADDED"))
            return
        }
        DTGifFavoriteLimitPrompt.confirmIfNeeded(present: { [weak self] sheet in
            self?.presenter.presentActionSheet(sheet)
        }, proceed: { [weak self, weak cell] in
            guard let self, let cell else { return }
            self.uploadAndFavoritePanelGif(cell, giphyId: giphyId)
        })
    }

    private func uploadAndFavoritePanelGif(_ cell: DTGIFPickerCell, giphyId: String) {
        // Grid dimensions for the pending display cell (aspect ratio); the job carries the upload.
        let original = cell.assetInfo?.originalAsset
        let width = Int(original?.widthValue ?? 0)
        let height = Int(original?.heightValue ?? 0)
        firstly {
            // Send and favorite both reuse the original WebP already shown in the grid.
            cell.requestRenditionForFavorite()
        }.done { asset in
            // Favorites aren't compressed — reject an oversized (or unreadable/0-byte) asset up front.
            let byteCount = gifFileByteCount(asset.filePath)
            guard byteCount > 0, gifFavoriteSizeWithinLimit(byteCount) else { return }
            // Optimistic: seeds display cache + enqueues; the retryable job uploads then commits.
            DTGifFavoriteSendManager.shared.enqueuePanelFavorite(
                localWebpPath: asset.filePath, giphyId: giphyId, width: width, height: height)
            DTToastHelper.toast(withText: Localized("GIF_FAVORITE_ADDED"))
        }.catch { error in
            Logger.error("[GifFav] download panel gif failed: \(error)")
            DTToastHelper.toast(withText: Localized("GIF_FAVORITE_FAILED"))
        }
    }
}
