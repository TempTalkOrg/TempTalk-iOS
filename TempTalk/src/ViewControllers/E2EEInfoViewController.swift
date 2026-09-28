//
//  E2EEInfoViewController.swift
//  TempTalk
//

import UIKit
import TTMessaging

final class E2EEInfoViewController: OWSViewController {

    private let forceDarkTheme: Bool
    private var palette: ThemeProtocol.Type {
        forceDarkTheme || Theme.isDarkThemeEnabled ? Theme.dark : Theme.light
    }

    private let backdropControl = UIControl()
    private let sheetView = UIView()
    private let grabberView = UIView()
    private let scrollView = UIScrollView()
    private let scrollContentView = UIView()
    private let contentStack = UIStackView()
    private let protectedContentCard = UIView()
    private let separatorView = UIView()
    private let dismissButton = UIButton(type: .custom)
    private let learnMoreButton = UIButton(type: .system)

    private let lockView: UIImageView = {
        let image = UIImage(named: "ic_e2ee_lock")?.withRenderingMode(.alwaysTemplate)
        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let titleLabel = E2EEInfoViewController.makeLabel(
        text: Localized("E2EE_INFO_TITLE", comment: "Your chats and calls are private"),
        font: .systemFont(ofSize: 16, weight: .medium),
        lineHeight: 24,
        alignment: .center
    )
    private let introLabel = E2EEInfoViewController.makeLabel(
        text: Localized("E2EE_INFO_INTRO", comment: "End-to-end encryption introduction"),
        font: .systemFont(ofSize: 14),
        lineHeight: 20,
        alignment: .center
    )
    private let caveatLabel = E2EEInfoViewController.makeLabel(
        text: Localized("E2EE_INFO_CAVEAT", comment: "End-to-end encryption limitation"),
        font: .systemFont(ofSize: 12),
        lineHeight: 16,
        alignment: .left
    )

    private var protectedIconViews: [UIImageView] = []
    private var protectedLabels: [UILabel] = []
    private var sheetHeightConstraint: NSLayoutConstraint!
    private var contentBottomConstraint: NSLayoutConstraint!
    private var hasAnimatedIn = false

    init(forceDarkTheme: Bool = false) {
        self.forceDarkTheme = forceDarkTheme
        super.init()
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        applyTheme()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasAnimatedIn = false
        backdropControl.alpha = 0
        view.layoutIfNeeded()
        let translation = max(sheetHeightConstraint.constant, view.bounds.height * 0.6)
        sheetView.transform = CGAffineTransform(translationX: 0, y: translation)
        grabberView.transform = CGAffineTransform(translationX: 0, y: translation)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasAnimatedIn else { return }
        hasAnimatedIn = true
        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0.2,
            options: [.curveEaseOut, .allowUserInteraction]
        ) { [weak self] in
            guard let self else { return }
            backdropControl.alpha = 1
            sheetView.transform = .identity
            grabberView.transform = .identity
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let bottomInset = max(16, view.safeAreaInsets.bottom)
        contentBottomConstraint.constant = -bottomInset

        let contentWidth = max(0, view.bounds.width - 32)
        let contentHeight = contentStack.systemLayoutSizeFitting(
            CGSize(width: contentWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        let naturalHeight = 32 + contentHeight + bottomInset
        let targetHeight = min(naturalHeight, view.bounds.height * 0.78)
        if abs(sheetHeightConstraint.constant - targetHeight) > 0.5 {
            sheetHeightConstraint.constant = targetHeight
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        forceDarkTheme || Theme.isDarkThemeEnabled ? .lightContent : .darkContent
    }

    override func accessibilityPerformEscape() -> Bool {
        dismissSheet()
        return true
    }

    override func applyTheme() {
        super.applyTheme()

        view.backgroundColor = .clear
        backdropControl.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        sheetView.backgroundColor = palette.bgpopupColor
        grabberView.backgroundColor = palette.tdisableColor
        lockView.tintColor = palette.primaryColor
        protectedContentCard.backgroundColor = palette.bg3Color
        separatorView.backgroundColor = palette.lineColor
        protectedIconViews.forEach { $0.tintColor = palette.iconColor }

        updateLabel(titleLabel, color: palette.tprimaryColor, lineHeight: 24)
        updateLabel(introLabel, color: palette.tsecondaryColor, lineHeight: 20)
        updateLabel(caveatLabel, color: palette.tsecondaryColor, lineHeight: 16)
        protectedLabels.forEach { updateLabel($0, color: palette.tprimaryColor, lineHeight: 20) }

        dismissButton.backgroundColor = palette.primaryColor
        dismissButton.setTitleColor(.white, for: .normal)
        learnMoreButton.setTitleColor(palette.tinfoColor, for: .normal)
        setNeedsStatusBarAppearanceUpdate()
    }

    private func setupView() {
        view.backgroundColor = .clear
        view.accessibilityViewIsModal = true

        [backdropControl, sheetView, grabberView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        backdropControl.addTarget(self, action: #selector(didTapBackdrop), for: .touchUpInside)
        sheetView.layer.cornerRadius = 16
        sheetView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        sheetView.clipsToBounds = true
        grabberView.layer.cornerRadius = 2.5

        NSLayoutConstraint.activate([
            backdropControl.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdropControl.topAnchor.constraint(equalTo: view.topAnchor),
            backdropControl.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdropControl.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sheetView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sheetView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sheetView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            grabberView.widthAnchor.constraint(equalToConstant: 35),
            grabberView.heightAnchor.constraint(equalToConstant: 5),
            grabberView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            grabberView.bottomAnchor.constraint(equalTo: sheetView.topAnchor, constant: -7)
        ])
        sheetHeightConstraint = sheetView.heightAnchor.constraint(equalToConstant: 560)
        sheetHeightConstraint.isActive = true

        setupScrollView()
        contentStack.addArrangedSubview(makeBodyView())
        contentStack.addArrangedSubview(makeActionsView())
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = false
        scrollView.showsVerticalScrollIndicator = false
        sheetView.addSubview(scrollView)

        scrollContentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(scrollContentView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 28
        scrollContentView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: sheetView.leadingAnchor),
            scrollView.topAnchor.constraint(equalTo: sheetView.topAnchor),
            scrollView.trailingAnchor.constraint(equalTo: sheetView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: sheetView.bottomAnchor),
            scrollContentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollContentView.leadingAnchor, constant: 16),
            contentStack.topAnchor.constraint(equalTo: scrollContentView.topAnchor, constant: 32),
            contentStack.trailingAnchor.constraint(equalTo: scrollContentView.trailingAnchor, constant: -16)
        ])
        contentBottomConstraint = contentStack.bottomAnchor.constraint(
            equalTo: scrollContentView.bottomAnchor,
            constant: -16
        )
        contentBottomConstraint.isActive = true
    }

    private func makeBodyView() -> UIView {
        let bodyStack = UIStackView()
        bodyStack.axis = .vertical
        bodyStack.spacing = 20

        let headStack = UIStackView()
        headStack.axis = .vertical
        headStack.alignment = .center
        headStack.spacing = 12

        NSLayoutConstraint.activate([
            lockView.widthAnchor.constraint(equalToConstant: 32),
            lockView.heightAnchor.constraint(equalToConstant: 32)
        ])
        titleLabel.accessibilityTraits.insert(.header)
        headStack.addArrangedSubview(lockView)
        headStack.addArrangedSubview(titleLabel)
        headStack.addArrangedSubview(introLabel)

        bodyStack.addArrangedSubview(headStack)
        bodyStack.addArrangedSubview(makeProtectedContentCard())
        return bodyStack
    }

    private func makeProtectedContentCard() -> UIView {
        protectedContentCard.layer.cornerRadius = 8

        let cardStack = UIStackView()
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        cardStack.axis = .vertical
        cardStack.spacing = 16
        protectedContentCard.addSubview(cardStack)

        NSLayoutConstraint.activate([
            cardStack.leadingAnchor.constraint(equalTo: protectedContentCard.leadingAnchor, constant: 16),
            cardStack.topAnchor.constraint(equalTo: protectedContentCard.topAnchor, constant: 16),
            cardStack.trailingAnchor.constraint(equalTo: protectedContentCard.trailingAnchor, constant: -16),
            cardStack.bottomAnchor.constraint(equalTo: protectedContentCard.bottomAnchor, constant: -16)
        ])

        cardStack.addArrangedSubview(makeProtectedItem(
            imageName: "e2ee_message_circle",
            text: Localized("E2EE_INFO_ITEM_1", comment: "Text and voice messages")
        ))
        cardStack.addArrangedSubview(makeProtectedItem(
            imageName: "e2ee_phone",
            text: Localized("E2EE_INFO_ITEM_2", comment: "Voice and video calls")
        ))
        cardStack.addArrangedSubview(makeProtectedItem(
            imageName: "e2ee_paperclip",
            text: Localized("E2EE_INFO_ITEM_3", comment: "Photos, videos, and files")
        ))

        separatorView.translatesAutoresizingMaskIntoConstraints = false
        separatorView.heightAnchor.constraint(equalToConstant: 1).isActive = true
        cardStack.addArrangedSubview(separatorView)
        cardStack.addArrangedSubview(caveatLabel)
        return protectedContentCard
    }

    private func makeProtectedItem(imageName: String, text: String) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 10

        let image = UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate)
        let iconView = UIImageView(image: image)
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20)
        ])

        let label = Self.makeLabel(
            text: text,
            font: .systemFont(ofSize: 14),
            lineHeight: 20,
            alignment: .left
        )
        protectedIconViews.append(iconView)
        protectedLabels.append(label)
        row.addArrangedSubview(iconView)
        row.addArrangedSubview(label)
        return row
    }

    private func makeActionsView() -> UIView {
        let actionsStack = UIStackView()
        actionsStack.axis = .vertical
        actionsStack.alignment = .fill
        actionsStack.spacing = 12

        dismissButton.layer.cornerRadius = 8
        dismissButton.titleLabel?.font = .systemFont(ofSize: 14)
        dismissButton.setTitle(Localized("E2EE_INFO_DISMISS", comment: "OK"), for: .normal)
        dismissButton.addTarget(self, action: #selector(didTapDismiss), for: .touchUpInside)
        dismissButton.heightAnchor.constraint(equalToConstant: 48).isActive = true

        learnMoreButton.titleLabel?.font = .systemFont(ofSize: 14)
        learnMoreButton.setTitle(Localized("E2EE_INFO_LEARN_MORE", comment: "Learn more"), for: .normal)
        learnMoreButton.addTarget(self, action: #selector(didTapLearnMore), for: .touchUpInside)
        learnMoreButton.heightAnchor.constraint(equalToConstant: 32).isActive = true

        actionsStack.addArrangedSubview(dismissButton)
        actionsStack.addArrangedSubview(learnMoreButton)
        return actionsStack
    }

    private static func makeLabel(
        text: String,
        font: UIFont,
        lineHeight: CGFloat,
        alignment: NSTextAlignment
    ) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.text = text
        label.font = font
        label.textAlignment = alignment
        return label
    }

    private func updateLabel(_ label: UILabel, color: UIColor, lineHeight: CGFloat) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = label.textAlignment
        paragraphStyle.minimumLineHeight = lineHeight
        paragraphStyle.maximumLineHeight = lineHeight
        label.attributedText = NSAttributedString(string: label.text ?? "", attributes: [
            .font: label.font as Any,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ])
    }

    @objc private func didTapBackdrop() {
        dismissSheet()
    }

    @objc private func didTapDismiss() {
        dismissSheet()
    }

    @objc private func didTapLearnMore() {
        guard let url = URL(string: "https://quicall.app/security") else { return }
        UIApplication.shared.open(url)
    }

    private func dismissSheet() {
        let translation = max(sheetHeightConstraint.constant, view.bounds.height * 0.6)
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.curveEaseIn, .beginFromCurrentState]
        ) { [weak self] in
            guard let self else { return }
            backdropControl.alpha = 0
            sheetView.transform = CGAffineTransform(translationX: 0, y: translation)
            grabberView.transform = CGAffineTransform(translationX: 0, y: translation)
        } completion: { [weak self] _ in
            self?.dismiss(animated: false)
        }
    }
}
