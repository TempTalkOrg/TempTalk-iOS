//
//  DTGIFFavoritesView.swift
//  TempTalk
//
//  Favorites tab content: loads the account-level favorites list, renders each
//  entry via DTFavoriteGifCell, and supports tap-to-send / long-press-to-remove.
//  Hosted by DTGIFPickerViewController, which translates a tapped file into a
//  SignalAttachment for sending.
//

import UIKit
import SnapKit
import TTServiceKit
import TTMessaging

protocol DTGIFFavoritesViewDelegate: AnyObject {
    func favoritesView(_ view: DTGIFFavoritesView, didSelect fileURL: URL)
}

class DTGIFFavoritesView: UIView {

    enum State { case loading, loaded, empty, error }

    weak var delegate: DTGIFFavoritesViewDelegate?

    private var hasLoadedOnce = false

    private var records: [FavoriteRecord] = [] {
        didSet {
            // Skip a redundant reload (e.g. cache == server on open) to avoid a flash.
            guard records.map({ $0.attachment.fileHash }) != oldValue.map({ $0.attachment.fileHash }) else { return }
            collectionView.collectionViewLayout.invalidateLayout()
            collectionView.reloadData()
        }
    }

    private var state: State = .loading {
        didSet { updateContents() }
    }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        createViews()
        // Live refresh: an add/remove elsewhere may land after this tab is already shown.
        NotificationCenter.default.addObserver(
            self, selector: #selector(favoritesDidChange),
            name: DTGifFavoritesRepository.favoritesDidChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Public

    /// Exposed for the host's PanModal scroll tracking.
    var scrollableView: UIScrollView { collectionView }

    /// Load favorites the first time the tab is shown; no-op afterwards.
    func loadIfNeeded() {
        guard !hasLoadedOnce else { return }
        reload()
    }

    func reload() {
        hasLoadedOnce = true
        // Show the cached list instantly (offline-capable); reconcile from the server below.
        let cached = DTGifFavoritesRepository.shared.cachedFavorites()
        records = cached
        state = cached.isEmpty ? .loading : .loaded
        Task { [weak self] in
            do {
                let loaded = try await DTGifFavoritesRepository.shared.loadFavorites()
                await MainActor.run {
                    guard let self else { return }
                    self.records = loaded
                    self.state = loaded.isEmpty ? .empty : .loaded
                }
            } catch {
                await MainActor.run {
                    guard let self else { return }
                    // Keep cached rows if any; otherwise surface a retryable error.
                    self.state = self.records.isEmpty ? .error : .loaded
                }
            }
        }
    }

    // MARK: - Theme

    func applyTheme() {
        backgroundColor = Theme.bg1Color
        collectionView.backgroundColor = Theme.bg1Color
        [emptyLabel, errorLabel].forEach { $0.textColor = Theme.tprimaryColor }
    }

    // MARK: - Views

    private func createViews() {
        addSubview(collectionView)
        collectionView.snp.makeConstraints { $0.edges.equalToSuperview() }

        [emptyLabel, errorLabel].forEach {
            addSubview($0)
            $0.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(24)
            }
        }

        addSubview(activityIndicator)
        activityIndicator.snp.makeConstraints { $0.center.equalToSuperview() }

        applyTheme()
        updateContents()
    }

    private func updateContents() {
        collectionView.isHidden = (state != .loaded)
        emptyLabel.isHidden = (state != .empty)
        errorLabel.isHidden = (state != .error)
        if state == .loading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    // MARK: - Lazy views

    private lazy var layout: DTGIFPickerCollectionViewLayout = {
        let layout = DTGIFPickerCollectionViewLayout()
        layout.dataSource = self
        return layout
    }()

    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(
            DTFavoriteGifCell.self,
            forCellWithReuseIdentifier: DTFavoriteGifCell.reuseIdentifier)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        collectionView.addGestureRecognizer(longPress)
        return collectionView
    }()

    private lazy var emptyLabel = makeCenteredLabel(text: Localized("GIF_FAVORITES_EMPTY"))

    private lazy var errorLabel: UILabel = {
        let label = makeCenteredLabel(text: Localized("GIF_SEARCH_ERROR"))
        label.isUserInteractionEnabled = true
        label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(retryTapped)))
        return label
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private func makeCenteredLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .semiboldFont(ofSize: 16)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }

    // MARK: - Events

    @objc
    private func retryTapped() {
        reload()
    }

    /// Repository broadcast an add/remove — reconcile from cache only (no network, no reload loop).
    @objc
    private func favoritesDidChange() {
        guard hasLoadedOnce else { return }
        let cached = DTGifFavoritesRepository.shared.cachedFavorites()
        records = cached
        state = cached.isEmpty ? .empty : .loaded
    }

    @objc
    private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point),
              indexPath.row < records.count,
              let cell = collectionView.cellForItem(at: indexPath) else { return }
        let record = records[indexPath.row]
        // Same anchored popover as the search/trending grid — "Remove from Favorite" state.
        let anchorRect = collectionView.convert(cell.frame, to: self)
        DTGifFavoriteActionPopover.present(in: self, anchorRect: anchorRect, mode: .remove) { [weak self] in
            self?.remove(record)
        }
    }

    private func remove(_ record: FavoriteRecord) {
        let fileHash = record.attachment.fileHash
        // Optimistic removal; the manager enqueues + drives a retryable commit (stays pending offline).
        records.removeAll { $0.attachment.fileHash == fileHash }
        if records.isEmpty { state = .empty }
        DTGifFavoriteSendManager.shared.enqueueUnfavorite(fileHash: fileHash)
    }
}

// MARK: - DTGIFPickerCollectionViewLayoutDataSource

extension DTGIFFavoritesView: DTGIFPickerCollectionViewLayoutDataSource {
    func aspectRatiosForLayout() -> [CGFloat] {
        records.map { record in
            let h = CGFloat(record.attachment.height)
            return h > 0 ? CGFloat(record.attachment.width) / h : 1
        }
    }
}

// MARK: - UICollectionViewDataSource

extension DTGIFFavoritesView: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        records.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: DTFavoriteGifCell.reuseIdentifier, for: indexPath)
        guard indexPath.row < records.count, let gifCell = cell as? DTFavoriteGifCell else {
            return cell
        }
        gifCell.record = records[indexPath.row]
        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension DTGIFFavoritesView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.row < records.count else { return }
        let pointer = records[indexPath.row].attachment
        Task { [weak self] in
            guard let url = try? await DTGifFavoriteAssetLoader.shared.localGifURL(for: pointer) else { return }
            await MainActor.run {
                guard let self else { return }
                self.delegate?.favoritesView(self, didSelect: url)
            }
        }
    }
}
