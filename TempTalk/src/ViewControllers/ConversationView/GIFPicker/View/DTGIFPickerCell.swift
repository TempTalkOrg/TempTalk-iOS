//
//  DTGIFPickerCell.swift
//  TempTalk
//
//  GIF grid cell: lazily loads the original rendition for on-screen cells only.
//

import TTServiceKit
import TTMessaging
import PureLayout
import YYImage

class DTGIFPickerCell: UICollectionViewCell {

    static let reuseIdentifier = "DTGIFPickerCell"

    private let imageView = YYAnimatedImageView()

    private let activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        view.autoSetDimension(.width, toSize: 30)
        view.autoSetDimension(.height, toSize: 30)
        view.layer.cornerRadius = 3
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(square: 1)
        view.layer.shadowOpacity = 0.7
        view.layer.shadowRadius = 1.0
        view.hidesWhenStopped = true
        return view
    }()

    private var loadedAsset: ProxiedContentAsset?
    private var loadedAssetRequest: ProxiedContentAssetRequest? {
        didSet { oldValue?.cancel() }
    }
    // The asset currently shown in imageView; avoids redecoding on isSelected/isCellVisible re-entry.
    private var displayedAsset: ProxiedContentAsset?
    // Decoded images shared across cells: a reused cell scrolling back to an already-decoded GIF
    // assigns it synchronously instead of flashing the placeholder during a background decode.
    private static let decodedImageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 60
        return cache
    }()

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        [imageView, activityIndicator].forEach { contentView.addSubview($0) }
        imageView.isHidden = true

        imageView.autoPinEdgesToSuperviewEdges()
        activityIndicator.autoCenterInSuperview()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applyTheme),
            name: .themeDidChange,
            object: nil)

        applyTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        loadedAssetRequest?.cancel()
    }

    // MARK: Public

    public func ensureCellState() {
        ensureLoadState()
        ensureViewState()
    }

    var assetInfo: DTGIFSearchAssetInfo? {
        didSet {
            AssertIsOnMainThread()
            ensureCellState()
        }
    }

    // Loading/playing GIFs is expensive; only preload on-screen cells.
    var isCellVisible = false {
        didSet {
            AssertIsOnMainThread()
            ensureCellState()
        }
    }

    override var isSelected: Bool {
        didSet {
            AssertIsOnMainThread()
            ensureCellState()
        }
    }

    public var isDisplayingAsset: Bool {
        (loadedAsset != nil) && imageView.image != nil
    }

    /// The rendition sent into a conversation: the original WebP already shown in the grid, so this
    /// resolves from the in-memory asset with no extra download or a larger rendition to upload.
    public func requestRenditionForSending() -> Promise<ProxiedContentAsset> {
        requestOriginalWebp()
    }

    /// The rendition to favorite/save: the same original WebP a send uses — one rendition for both.
    public func requestRenditionForFavorite() -> Promise<ProxiedContentAsset> {
        requestOriginalWebp()
    }

    /// The original WebP. The grid already loaded it for display, so a send/favorite reuses those
    /// exact bytes: the loaded asset when present, else a downloader cache hit. Never the GIF
    /// rendition, so the bytes always match the WebP content type that sending/favoriting pins.
    private func requestOriginalWebp() -> Promise<ProxiedContentAsset> {
        let (promise, future) = Promise<ProxiedContentAsset>.pending()
        if let loadedAsset {
            future.resolve(loadedAsset)
            return promise
        }
        guard let assetInfo, let original = assetInfo.originalAsset.webpAssetDescription else {
            owsFailDebug("original webp was unexpectedly nil")
            future.reject(DTGIFSearchError.assertionError(description: "original webp was unexpectedly nil"))
            return promise
        }
        // Only one asset is ever selected, so we never cancel this request.
        _ = DTAssetDownloader.gifDownloader.requestAsset(
            assetDescription: original,
            priority: .high,
            success: { _, asset in future.resolve(asset) },
            failure: { _ in
                Logger.error("request original webp failed")
                future.reject(DTGIFSearchError.fetchFailure)
            })
        return promise
    }

    // MARK: UICollectionViewCell

    override func prepareForReuse() {
        super.prepareForReuse()
        assetInfo = nil
        isCellVisible = false
        isSelected = false
        loadedAssetRequest = nil
        loadedAsset = nil
        clearViewState()
    }

    // MARK: - Private

    @objc
    private func applyTheme() {
        backgroundColor = Theme.isDarkThemeEnabled ? .ows_gray75 : .ows_gray05
    }

    private func ensureLoadState() {
        guard isCellVisible, let assetInfo = assetInfo else {
            loadedAssetRequest = nil
            return
        }
        ensureAssetLoad(assetInfo)
    }

    private func ensureAssetLoad(_ assetInfo: DTGIFSearchAssetInfo) {
        guard loadedAssetRequest == nil, loadedAsset == nil else {
            return
        }
        // WebP only: grid, sending, and favoriting all use the original WebP (the GIF rendition is ignored).
        guard let originalAssetDescription = assetInfo.originalAsset.webpAssetDescription else {
            Logger.warn("could not pick original webp: \(assetInfo.identifier)")
            return
        }

        loadedAssetRequest = DTAssetDownloader.gifDownloader.requestAsset(
            assetDescription: originalAssetDescription,
            priority: .low,
            success: { [weak self] assetRequest, asset in
                AssertIsOnMainThread()
                guard let self = self else { return }
                guard assetRequest == self.loadedAssetRequest else {
                    owsFailDebug("Obsolete request callback.")
                    return
                }
                self.loadedAssetRequest = nil
                self.loadedAsset = asset
                self.ensureViewState()
            },
            failure: { [weak self] assetRequest in
                AssertIsOnMainThread()
                guard let self = self else { return }
                guard assetRequest == self.loadedAssetRequest else {
                    owsFailDebug("Obsolete request callback.")
                    return
                }
                self.loadedAssetRequest = nil
            }
        )
    }

    private func ensureViewState() {
        AssertIsOnMainThread()

        guard isCellVisible, let asset = loadedAsset else {
            clearViewState()
            return
        }

        // The spinner reflects selection and must respond immediately, independent of decoding.
        if isSelected {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }

        // Already showing this asset: an isSelected/isCellVisible re-entry must not redecode.
        if displayedAsset === asset, imageView.image != nil {
            return
        }

        let filePath = asset.filePath
        let cacheKey = filePath as NSString

        // Synchronous hit on the decoded-image cache: assign immediately so a reused cell scrolling
        // back to this GIF doesn't flash the placeholder while a background decode runs.
        if let cached = Self.decodedImageCache.object(forKey: cacheKey) {
            imageView.image = cached
            imageView.isHidden = false
            displayedAsset = asset
            return
        }

        // First decode of this file: do it off the main thread so it doesn't hitch grid scrolling.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let image = Self.decodeImage(atPath: filePath)
            if let image = image {
                Self.decodedImageCache.setObject(image, forKey: cacheKey)
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                // The cell may have been reused or scrolled off-screen while decoding.
                guard self.isCellVisible, self.loadedAsset === asset else { return }
                guard let image = image else {
                    owsFailDebug("could not load asset.")
                    self.clearViewState()
                    return
                }
                self.imageView.image = image
                self.imageView.isHidden = false
                self.displayedAsset = asset
            }
        }
    }

    /// Decodes a downloaded asset into a displayable image (animated WebP/GIF via YYImage, still
    /// JPEG via UIImage). Safe to call off the main thread.
    private static func decodeImage(atPath filePath: String) -> UIImage? {
        if NSData.ows_isValidImage(atPath: filePath, mimeType: OWSMimeTypeImageWebp) {
            return YYImage(contentsOfFile: filePath)
        }
        if NSData.ows_isValidImage(atPath: filePath, mimeType: OWSMimeTypeImageGif) {
            return YYImage(contentsOfFile: filePath)
        }
        if NSData.ows_isValidImage(atPath: filePath, mimeType: OWSMimeTypeImageJpeg) {
            return UIImage(contentsOfFile: filePath)
        }
        return nil
    }

    private func clearViewState() {
        AssertIsOnMainThread()
        imageView.image = nil
        imageView.isHidden = true
        displayedAsset = nil
        activityIndicator.stopAnimating()
    }
}
