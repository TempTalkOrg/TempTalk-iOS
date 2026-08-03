//
//  DTFavoriteGifCell.swift
//  TempTalk
//
//  Favorites grid cell: renders a favorite pointer by downloading + decrypting
//  its account-level asset on demand (DTGifFavoriteAssetLoader), then plays it via YYImage.
//

import TTServiceKit
import TTMessaging
import PureLayout
import YYImage

class DTFavoriteGifCell: UICollectionViewCell {

    static let reuseIdentifier = "DTFavoriteGifCell"

    /// Decoded favorites keyed by fileHash — lets an already-loaded GIF re-display instantly
    /// (no clear + async round-trip), avoiding a flash on reload/scroll.
    private static let imageCache = NSCache<NSString, YYImage>()

    private let imageView = YYAnimatedImageView()

    private let activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.hidesWhenStopped = true
        return view
    }()

    // Guards against a reused cell rendering a stale async load.
    private var loadToken = UUID()

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        [imageView, activityIndicator].forEach { contentView.addSubview($0) }
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isHidden = true
        imageView.autoPinEdgesToSuperviewEdges()
        activityIndicator.autoCenterInSuperview()

        NotificationCenter.default.addObserver(
            self, selector: #selector(applyTheme), name: .themeDidChange, object: nil)
        applyTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public

    var record: FavoriteRecord? {
        didSet {
            AssertIsOnMainThread()
            guard record?.attachment.fileHash != oldValue?.attachment.fileHash else { return }
            reload()
        }
    }

    // MARK: - UICollectionViewCell

    override func prepareForReuse() {
        super.prepareForReuse()
        record = nil
        loadToken = UUID()
        clearViewState()
    }

    // MARK: - Private

    @objc
    private func applyTheme() {
        backgroundColor = Theme.isDarkThemeEnabled ? .ows_gray75 : .ows_gray05
    }

    private func reload() {
        let token = UUID()
        loadToken = token

        guard let pointer = record?.attachment else {
            clearViewState()
            return
        }

        // Cache hit → show instantly without clearing (no flash).
        if let cached = Self.imageCache.object(forKey: pointer.fileHash as NSString) {
            activityIndicator.stopAnimating()
            imageView.image = cached
            imageView.isHidden = false
            return
        }

        clearViewState()
        activityIndicator.startAnimating()

        Task { [weak self] in
            let url = try? await DTGifFavoriteAssetLoader.shared.localGifURL(for: pointer)
            // Decode off the main thread.
            let image = url.flatMap { YYImage(contentsOfFile: $0.path) }
            await MainActor.run {
                guard let self, self.loadToken == token else { return }
                self.activityIndicator.stopAnimating()
                guard let image else {
                    self.imageView.isHidden = true
                    return
                }
                Self.imageCache.setObject(image, forKey: pointer.fileHash as NSString)
                self.imageView.image = image
                self.imageView.isHidden = false
            }
        }
    }

    private func clearViewState() {
        imageView.image = nil
        imageView.isHidden = true
        activityIndicator.stopAnimating()
    }
}
