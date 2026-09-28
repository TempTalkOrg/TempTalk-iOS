//
//  Copyright (c) 2026 Open Whisper Systems. All rights reserved.
//

import SnapKit
import TTServiceKit
import UIKit

public protocol MediaPreviewViewControllerDelegate: AnyObject {
    func mediaPreview(_ vc: MediaPreviewViewController, didApproveAttachments attachments: [SignalAttachment])
    func mediaPreviewDidCancel(_ vc: MediaPreviewViewController)
    func mediaPreviewDidTapConfide(_ vc: MediaPreviewViewController)
}

/// Media preview for picker selections. Presents immediately and lets
/// `MediaPreviewProcessor` prepare each item in the background, so nothing
/// blocks presentation and each page surfaces on its own.
public class MediaPreviewViewController: OWSViewController, CaptioningToolbarDelegate {

    public weak var delegate: MediaPreviewViewControllerDelegate?

    private let items: [MediaPreviewItem]
    private let initialIsConfidential: Bool
    private let processor = MediaPreviewProcessor()

    public private(set) var bottomToolbar: CaptioningToolbar?

    // MARK: - UI Components

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = UIScreen.main.bounds.size
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .black
        cv.dataSource = self
        cv.delegate = self
        cv.showsVerticalScrollIndicator = false
        cv.showsHorizontalScrollIndicator = false
        cv.isPagingEnabled = true
        cv.register(
            MediaPreviewCollectionCell.self,
            forCellWithReuseIdentifier: MediaPreviewCollectionCell.reuseIdentifier
        )
        return cv
    }()

    private lazy var topGradient: GradientView = {
        GradientView(from: .black, to: .clear)
    }()

    private lazy var cancelButton: RoundMediaButton = {
        let button = RoundMediaButton(image: UIImage(named: "x-28"), backgroundStyle: .blur)
        button.addTarget(self, action: #selector(cancelPressed), for: .touchUpInside)
        return button
    }()

    // MARK: - Init

    public init(items: [MediaPreviewItem], isConfidential: Bool, delegate: MediaPreviewViewControllerDelegate) {
        self.items = items
        self.initialIsConfidential = isConfidential
        self.delegate = delegate
        super.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        processor.cancelAll()
    }

    // MARK: - Autorotate

    public override var shouldAutorotate: Bool { false }
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    public override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .portrait }

    // MARK: - Factory

    public static func wrappedInNavController(
        items: [MediaPreviewItem],
        isConfidential: Bool,
        delegate: MediaPreviewViewControllerDelegate
    ) -> OWSNavigationController {
        let vc = MediaPreviewViewController(items: items, isConfidential: isConfidential, delegate: delegate)
        let nav = OWSNavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .overFullScreen
        nav.navigationBar.isHidden = true
        return nav
    }

    // MARK: - View Lifecycle

    public override func loadView() {
        self.view = UIView()
        view.backgroundColor = .black

        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        view.addSubview(topGradient)
        topGradient.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(ScaleFromIPhone5(60))
        }

        let captioningToolbar = CaptioningToolbar()
        captioningToolbar.captioningToolbarDelegate = self
        captioningToolbar.isConfidential = initialIsConfidential
        self.bottomToolbar = captioningToolbar
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(cancelButton)
        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.equalToSuperview().offset(8)
        }

        processor.process(items: items)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        CurrentAppContext().setStatusBarHidden(true, animated: animated)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        CurrentAppContext().setStatusBarHidden(false, animated: false)
    }

    public override var inputAccessoryView: UIView? {
        bottomToolbar?.layoutIfNeeded()
        return bottomToolbar
    }

    public override var canBecomeFirstResponder: Bool { true }

    // MARK: - Actions

    @objc private func cancelPressed() {
        guard !processor.isAllCompleted else {
            delegate?.mediaPreviewDidCancel(self)
            return
        }

        let alert = UIAlertController(
            title: nil,
            message: Localized("MEDIA_PREVIEW_CLOSE_WHILE_COMPRESSING"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: Localized("TXT_CANCEL_TITLE"), style: .cancel))
        alert.addAction(
            UIAlertAction(title: Localized("TXT_CONFIRM_TITLE"), style: .destructive) { [weak self] _ in
                guard let self else { return }
                self.processor.cancelAll()
                self.delegate?.mediaPreviewDidCancel(self)
            }
        )
        present(alert, animated: true)
    }

    // MARK: - CaptioningToolbarDelegate

    public func captioningToolbarDidTapSend(_ captioningToolbar: CaptioningToolbar, captionText: String?) {
        guard processor.isAllCompleted else {
            let toast = ToastController(text: Localized("MEDIA_PREVIEW_COMPRESSING_TOAST"))
            toast.presentToastView(fromBottomOfView: view, inset: 80)
            return
        }

        let attachments = items.compactMap { $0.signalAttachment }
        // Everything has completed by now, so anything without an attachment
        // failed. Those are dropped from the send — say so instead of quietly
        // sending a partial set, or accepting the tap and doing nothing at all.
        let failedCount = items.count - attachments.count
        guard failedCount == 0 else {
            presentFailureAlert(failedCount: failedCount, sendable: attachments, captionText: captionText)
            return
        }

        send(attachments, captionText: captionText)
    }

    private func presentFailureAlert(
        failedCount: Int,
        sendable: [SignalAttachment],
        captionText: String?
    ) {
        let alert = UIAlertController(
            title: nil,
            message: String(format: Localized("MEDIA_PREVIEW_ITEMS_FAILED"), failedCount),
            preferredStyle: .alert
        )
        guard !sendable.isEmpty else {
            alert.addAction(UIAlertAction(title: Localized("TXT_CONFIRM_TITLE"), style: .cancel))
            present(alert, animated: true)
            return
        }
        alert.addAction(UIAlertAction(title: Localized("TXT_CANCEL_TITLE"), style: .cancel))
        alert.addAction(
            UIAlertAction(title: Localized("SEND_BUTTON_TITLE"), style: .default) { [weak self] _ in
                self?.send(sendable, captionText: captionText)
            }
        )
        present(alert, animated: true)
    }

    private func send(_ attachments: [SignalAttachment], captionText: String?) {
        bottomToolbar?.isUserInteractionEnabled = false
        bottomToolbar?.isHidden = true

        attachments.last?.captionText = captionText
        delegate?.mediaPreview(self, didApproveAttachments: attachments)
    }

    public func captioningToolbarDidTapConfide(_ captioningToolbar: CaptioningToolbar) {
        delegate?.mediaPreviewDidTapConfide(self)
    }

    public func captioningToolbarDidBeginEditing(_ captioningToolbar: CaptioningToolbar) {
        scaleCollectionView(.compact)
    }

    public func captioningToolbarDidEndEditing(_ captioningToolbar: CaptioningToolbar) {
        scaleCollectionView(.fullsize)
    }

    // MARK: - Keyboard Scale

    private enum CollectionViewScale {
        case fullsize, compact
    }

    private func scaleCollectionView(_ fit: CollectionViewScale) {
        switch fit {
        case .fullsize:
            UIView.animate(withDuration: 0.2) {
                self.collectionView.transform = .identity
            }
        case .compact:
            UIView.animate(withDuration: 0.2) {
                let scaleFactor: CGFloat = 0.7
                let scale = CGAffineTransform(scaleX: scaleFactor, y: scaleFactor)
                let heightDelta = self.collectionView.bounds.height * (1 - scaleFactor)
                let translate = CGAffineTransform(translationX: 0, y: -heightDelta / 2)
                self.collectionView.transform = scale.concatenating(translate)
            }
        }
    }
}

// MARK: - UICollectionViewDataSource & Delegate

extension MediaPreviewViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        collectionView.dequeueReusableCell(
            withReuseIdentifier: MediaPreviewCollectionCell.reuseIdentifier,
            for: indexPath
        )
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard let cell = cell as? MediaPreviewCollectionCell else { return }
        cell.configure(with: items[indexPath.item])
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        didEndDisplaying cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard let cell = cell as? MediaPreviewCollectionCell else { return }
        cell.prepareForReuse()
    }
}
