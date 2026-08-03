//
//  DTGIFPickerViewController+Search.swift
//  TempTalk
//
//  Search / trending tab: waterfall data source, paging, and send-on-select.
//

import Foundation
import UIKit
import TTServiceKit
import TTMessaging

// MARK: - DTGIFPickerCollectionViewLayoutDataSource

extension DTGIFPickerViewController: DTGIFPickerCollectionViewLayoutDataSource {
    func aspectRatiosForLayout() -> [CGFloat] {
        return searchResults.map { $0.aspectRatio }
    }
}

// MARK: - UICollectionViewDataSource

extension DTGIFPickerViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return searchResults.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: DTGIFPickerCell.reuseIdentifier,
            for: indexPath)
        guard indexPath.row < searchResults.count, let gifCell = cell as? DTGIFPickerCell else {
            return cell
        }
        gifCell.assetInfo = searchResults[indexPath.row]
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension DTGIFPickerViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return selectableCell(at: indexPath) != nil
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        guard let cell = selectableCell(at: indexPath) else { return }
        // WeChat-style: close the panel immediately; the conversation bubble owns
        // the sending/sent state. Sending reuses the original WebP already shown in the
        // grid, so it's instant with no extra download.
        if isHostedInKeyboard {
            delegate?.gifPickerViewControllerRequestDismiss(self)
        }
        sendGif(from: cell)
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? DTGIFPickerCell else { return }
        cell.isCellVisible = true
        if indexPath.row + 3 >= searchResults.count {
            loadMoreData()
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? DTGIFPickerCell else { return }
        cell.isCellVisible = false
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        searchField.resignFirstResponder()
    }

    private func selectableCell(at indexPath: IndexPath) -> DTGIFPickerCell? {
        guard let cell = collectionView.cellForItem(at: indexPath) as? DTGIFPickerCell else {
            return nil
        }
        // Don't allow selecting a cell whose asset hasn't loaded yet.
        guard cell.isDisplayingAsset else {
            return nil
        }
        return cell
    }

    /// Wrap the original-WebP rendition (already loaded for the grid) in a SignalAttachment and
    /// hand it to the conversation (which shows the sending/sent bubble).
    private func sendGif(from cell: DTGIFPickerCell) {
        firstly {
            cell.requestRenditionForSending()
        }.map(on: DispatchQueue.global()) { (asset: ProxiedContentAsset) -> SignalAttachment in
            guard let assetDescription = asset.assetDescription as? DTAssetDescription else {
                throw OWSAssertionError("Invalid asset description.")
            }
            let assetTypeIdentifier = assetDescription.fileType.utiType
            let assetFileExtension = assetDescription.fileType.extension
            let pathForConsumableFile = OWSFileSystem.temporaryFilePath(fileExtension: assetFileExtension)
            try FileManager.default.copyItem(atPath: asset.filePath, toPath: pathForConsumableFile)
            let dataSource = try DataSourcePath.dataSource(withFilePath: pathForConsumableFile,
                                                           shouldDeleteOnDeallocation: false)
            return SignalAttachment.attachment(dataSource: dataSource, dataUTI: assetTypeIdentifier)

        }.done { [weak self] attachment in
            guard let self else { return }
            self.delegate?.gifPickerViewController(self, didSelect: attachment)

        }.catch { error in
            Logger.error("[GIF] send gif failed: \(error)")
            DTToastHelper.toast(withText: Localized("GIF_SEARCH_FAILURE_ALERT_TITLE"))
        }
    }
}

// MARK: - UITextFieldDelegate (search field)

extension DTGIFPickerViewController: UITextFieldDelegate {

    @objc
    func searchTextChanged() {
        if viewMode == .error || viewMode == .noResults {
            viewMode = .idle
        }
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(loadData), object: nil)
        perform(#selector(loadData), with: nil, afterDelay: 0.3)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(loadData), object: nil)
        loadData()
        return true
    }
}

// MARK: - Load Data

extension DTGIFPickerViewController {

    @objc
    func loadData() {
        let query = activeQuery
        if (viewMode == .searching || viewMode == .results) && lastQuery == query {
            return
        }

        operationQueue.cancelAllOperations()
        searchResults = []
        viewMode = .searching
        lastQuery = query
        nextPage = .first
        collectionView.contentOffset = .zero
        reloadResults()

        isShowLoading = true
        let operation = DTGIFSearchOperation(page: .first, query: query) { [weak self] response in
            guard let self else { return }
            self.isShowLoading = false
            switch response {
            case let .success((result, nextPage)):
                if !result.data.isEmpty {
                    self.searchResults = result.data
                    self.viewMode = .results
                } else {
                    self.viewMode = .noResults
                }
                self.reloadResults()
                self.nextPage = nextPage
            case .failure:
                self.viewMode = .error
                self.nextPage = nil
            }
        }
        operationQueue.addOperation(operation)
    }

    func loadMoreData() {
        guard let nextPage, nextPage != .first else { return }
        guard viewMode != .searching else { return }
        viewMode = .searching

        let operation = DTGIFSearchOperation(page: nextPage, query: lastQuery) { [weak self] response in
            guard let self else { return }
            switch response {
            case let .success((result, nextPage)):
                let oldCount = self.searchResults.count
                var newResults = Array(self.searchResults)
                newResults.append(contentsOf: result.data)
                self.searchResults = newResults
                self.viewMode = .results
                self.nextPage = nextPage
                self.appendResults(insertedCount: result.data.count, from: oldCount)
            case .failure:
                self.viewMode = .results
            }
        }
        operationQueue.addOperation(operation)
    }

    /// Full reload — for a fresh query or tab switch where the whole result set is replaced.
    func reloadResults() {
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.reloadData()
    }

    /// Incremental append for paging: insert only the new items so existing cells aren't rebuilt.
    /// A full reloadData rebuilt every visible cell and flashed the whole grid on each new page.
    func appendResults(insertedCount: Int, from oldCount: Int) {
        guard insertedCount > 0,
              isViewLoaded,
              collectionView.numberOfItems(inSection: 0) == oldCount else {
            reloadResults()
            return
        }
        let indexPaths = (oldCount ..< (oldCount + insertedCount)).map { IndexPath(row: $0, section: 0) }
        collectionView.performBatchUpdates {
            collectionView.insertItems(at: indexPaths)
        }
    }
}
