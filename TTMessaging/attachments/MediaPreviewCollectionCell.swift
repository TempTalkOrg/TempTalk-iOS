//
//  Copyright (c) 2026 Open Whisper Systems. All rights reserved.
//

import AVFoundation
import ImageIO
import TTServiceKit
import UIKit

/// One page of the media-preview screen. Renders from `MediaPreviewItem.state`:
/// a spinner while the processor prepares the asset, then the real content —
/// the full image for photos, an `OWSVideoPlayer` for videos.
public class MediaPreviewCollectionCell: UICollectionViewCell {

    public static let reuseIdentifier = "MediaPreviewCollectionCell"

    // MARK: - Subviews

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.decelerationRate = .fast
        return sv
    }()

    private let containerView = UIView.container()
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        return iv
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private lazy var playButton: UIButton = {
        let button = UIButton()
        button.accessibilityLabel = Localized(
            "PLAY_BUTTON_ACCESSABILITY_LABEL",
            comment: "Accessibility label for button to start media playback"
        )
        button.setBackgroundImage(UIImage(named: "play_button"), for: .normal)
        button.contentMode = .scaleAspectFit
        let size = ScaleFromIPhone5(70)
        button.autoSetDimensions(to: CGSize(width: size, height: size))
        button.addTarget(self, action: #selector(playButtonTapped), for: .touchUpInside)
        button.isHidden = true
        return button
    }()

    private lazy var errorOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        view.isHidden = true

        let label = UILabel()
        label.text = Localized(
            "ATTACHMENT_ERROR_ALERT_TITLE",
            comment: "The title of the 'attachment error' alert."
        )
        label.textColor = .white
        label.font = .systemFont(ofSize: 14)
        label.textAlignment = .center
        view.addSubview(label)
        label.autoCenterInSuperview()

        return view
    }()

    private var videoPlayer: OWSVideoPlayer?
    private var playerView: VideoPlayerView?
    private var progressBar: PlayerProgressBar?
    private var item: MediaPreviewItem?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(scrollView)
        scrollView.delegate = self
        scrollView.autoPinEdgesToSuperviewEdges()

        scrollView.addSubview(containerView)
        containerView.autoPinEdgesToSuperviewEdges()
        containerView.autoMatch(.height, to: .height, of: contentView)
        containerView.autoMatch(.width, to: .width, of: contentView)

        containerView.addSubview(imageView)
        imageView.autoPinEdgesToSuperviewEdges()

        contentView.addSubview(loadingIndicator)
        loadingIndicator.autoCenterInSuperview()

        contentView.addSubview(playButton)
        playButton.autoCenterInSuperview()

        contentView.addSubview(errorOverlay)
        errorOverlay.autoPinEdgesToSuperviewEdges()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    // MARK: - Configure

    public func configure(with item: MediaPreviewItem) {
        self.item = item
        // No eager poster: the spinner covers the prepare window and the real
        // content lands on `.ready`. Pre-fetching a PHImageManager preview here
        // would block presentation and be discarded anyway.
        imageView.image = nil

        item.onStateChanged = { [weak self] state in
            self?.applyState(state)
        }
        applyState(item.state)
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        item?.onStateChanged = nil
        item = nil
        imageView.image = nil
        stopVideo()
        removeVideoViews()
        loadingIndicator.stopAnimating()
        playButton.isHidden = true
        playButton.alpha = 1.0
        errorOverlay.isHidden = true
        scrollView.zoomScale = 1.0
    }

    // MARK: - State

    private func applyState(_ state: MediaPreviewItemState) {
        switch state {
        case .pending, .compressing:
            loadingIndicator.startAnimating()
            playButton.isHidden = true
            errorOverlay.isHidden = true

        case .ready:
            errorOverlay.isHidden = true

            guard let item else {
                loadingIndicator.stopAnimating()
                return
            }
            if item.isVideo {
                loadingIndicator.stopAnimating()
                playButton.isHidden = false
                setupVideoPlayer()
            } else {
                // `.ready` means the prepared file exists, but the screen-sized
                // bitmap is still decoded asynchronously below. Keep the spinner
                // visible until that decode actually lands in this cell.
                loadingIndicator.startAnimating()
                playButton.isHidden = true
                loadImage(for: item)
            }

        case .failed:
            loadingIndicator.stopAnimating()
            playButton.isHidden = true
            errorOverlay.isHidden = false
        }
    }

    // MARK: - Image

    /// Decodes off the main thread and caps the bitmap at screen size.
    ///
    /// `UIImage(contentsOfFile:)` only wraps the file — the real decode is deferred to
    /// first draw, on the main thread, during the CA commit. For an original-quality
    /// photo that is the exact stall this whole flow exists to avoid, and it also
    /// materialises a full-resolution bitmap per visible page. `CGImageSourceCreate-
    /// ThumbnailAtIndex` with `ShouldCacheImmediately` does both the decode and the
    /// downscale on the background queue instead.
    ///
    /// Screen size costs nothing here: the scroll view never sets `maximumZoomScale`,
    /// so it stays at the default 1.0 and nothing ever renders above 1x.
    private func loadImage(for item: MediaPreviewItem) {
        guard let dataUrl = item.signalAttachment?.dataUrl else {
            Logger.error("Preview image URL is missing for a ready media item.")
            loadingIndicator.stopAnimating()
            errorOverlay.isHidden = false
            return
        }
        let screenBounds = UIScreen.main.bounds.size
        let maxPixelSize = Int(max(screenBounds.width, screenBounds.height) * UIScreen.main.scale)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let image = Self.downsampledImage(at: dataUrl, maxPixelSize: maxPixelSize)
            DispatchQueue.main.async {
                // The cell may have been recycled onto another page mid-decode.
                guard let self, self.item === item else { return }
                self.loadingIndicator.stopAnimating()
                guard let image else {
                    Logger.error("Decode preview image failed: \(dataUrl.lastPathComponent).")
                    self.errorOverlay.isHidden = false
                    return
                }
                self.imageView.image = image
            }
        }
    }

    private static func downsampledImage(at url: URL, maxPixelSize: Int) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else {
            return nil
        }
        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            // Honour the EXIF orientation — the thumbnail is a bare CGImage with no
            // UIImage.Orientation to carry it, so a portrait shot would land sideways.
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Video

    private func setupVideoPlayer() {
        guard let item, let attachment = item.signalAttachment, let videoURL = attachment.dataUrl else {
            return
        }

        let player = OWSVideoPlayer(url: videoURL)
        self.videoPlayer = player
        player.delegate = self

        let pView = VideoPlayerView()
        pView.player = player.avPlayer
        self.playerView = pView
        containerView.addSubview(pView)
        pView.autoPinEdgesToSuperviewEdges()

        let pauseGesture = UITapGestureRecognizer(target: self, action: #selector(didTapPlayerView))
        pView.addGestureRecognizer(pauseGesture)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pauseVideo),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        let bar = PlayerProgressBar()
        bar.player = player.avPlayer
        bar.delegate = self
        self.progressBar = bar
        contentView.addSubview(bar)
        bar.autoPinTopToSuperviewMargin(withInset: 60)
        bar.autoPinWidthToSuperview()
        bar.autoSetDimension(.height, toSize: 44)
    }

    private func stopVideo() {
        videoPlayer?.stop()
        videoPlayer = nil

        NotificationCenter.default.removeObserver(
            self,
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    @objc private func pauseVideo() {
        guard let videoPlayer else { return }
        videoPlayer.pause()
        UIView.animate(withDuration: 0.1) {
            self.playButton.alpha = 1.0
        }
    }

    private func removeVideoViews() {
        playerView?.removeFromSuperview()
        playerView = nil
        progressBar?.removeFromSuperview()
        progressBar = nil
    }

    @objc private func playButtonTapped() {
        guard let videoPlayer else { return }
        UIView.animate(withDuration: 0.1) {
            self.playButton.alpha = 0.0
        }
        videoPlayer.play()
    }

    @objc private func didTapPlayerView() {
        pauseVideo()
    }
}

// MARK: - UIScrollViewDelegate

extension MediaPreviewCollectionCell: UIScrollViewDelegate {

    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let scrollViewSize = scrollView.bounds.size
        let contentSize = scrollView.contentSize

        let horizontalInset = max(0, (scrollViewSize.width - contentSize.width) / 2)
        let verticalInset = max(0, (scrollViewSize.height - contentSize.height) / 2)

        scrollView.contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }
}

// MARK: - OWSVideoPlayerDelegate & PlayerProgressBarDelegate

extension MediaPreviewCollectionCell: OWSVideoPlayerDelegate, PlayerProgressBarDelegate {

    public func videoPlayerDidPlayToCompletion(_ videoPlayer: OWSVideoPlayer) {
        UIView.animate(withDuration: 0.1) {
            self.playButton.alpha = 1.0
        }
    }

    public func playerProgressBarDidStartScrubbing(_ playerProgressBar: PlayerProgressBar) {
        videoPlayer?.pause()
    }

    public func playerProgressBar(_ playerProgressBar: PlayerProgressBar, scrubbedToTime time: CMTime) {
        videoPlayer?.seek(to: time)
    }

    public func playerProgressBar(
        _ playerProgressBar: PlayerProgressBar,
        didFinishScrubbingAtTime time: CMTime,
        shouldResumePlayback: Bool
    ) {
        videoPlayer?.seek(to: time)
        if shouldResumePlayback {
            videoPlayer?.play()
        }
    }
}
