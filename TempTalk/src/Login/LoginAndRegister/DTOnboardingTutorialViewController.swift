//
//  DTOnboardingTutorialViewController.swift
//  TempTalk
//
//  Created on 2026/5/12.
//  Copyright © 2026 Difft. All rights reserved.
//

import UIKit
import TTMessaging

@objc class DTOnboardingTutorialViewController: OWSViewController, OWSNavigationChildController {

    // MARK: - OWSNavigationChildController

    var navbarBackgroundColorOverride: UIColor? { Theme.bgpageSecondaryColor }
    var childForOWSNavigationConfiguration: OWSNavigationChildController? { nil }
    var preferredNavigationBarStyle: OWSNavigationBarStyle { .solid }
    var navbarTintColorOverride: UIColor? { nil }
    var prefersNavigationBarHidden: Bool { false }
    var shouldCancelNavigationBack: Bool { false }

    // MARK: - Properties

    private var currentPage = 0
    private let totalPages = 2
    private var isAnimating = false

    var onFinished: (() -> Void)?

    private enum SlideDirection {
        case left, right, none
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNav()
        createViews()
        setupGestures()
        applyTheme()
    }

    override func applyTheme() {
        view.backgroundColor = Theme.bgpageSecondaryColor
        cardView.backgroundColor = Theme.bgpopupColor
        cardView.layer.borderColor = Theme.lineColor.withAlphaComponent(0.9).cgColor
        updatePage(direction: .none)
    }

    // MARK: - Nav

    private lazy var backButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        button.setImage(UIImage(named: "nav_back_arrow_new"), for: .normal)
        return button
    }()

    private func setupNav() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backButton)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: skipButton)
    }

    // MARK: - Gestures

    private func setupGestures() {
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        cardView.addGestureRecognizer(swipeLeft)

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        cardView.addGestureRecognizer(swipeRight)
    }

    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        guard !isAnimating else { return }
        switch gesture.direction {
        case .left:
            goToNextPage()
        case .right:
            goToPreviousPage()
        default:
            break
        }
    }

    // MARK: - Data

    private struct TutorialPage {
        let illustrationType: IllustrationType
        let titleKey: String
        let descriptionKey: String
    }

    private enum IllustrationType {
        case messagesDisappear
        case endToEndEncryption
    }

    private let pages: [TutorialPage] = [
        TutorialPage(
            illustrationType: .messagesDisappear,
            titleKey: "ONBOARDING_TUTORIAL_MESSAGES_DISAPPEAR_TITLE",
            descriptionKey: "ONBOARDING_TUTORIAL_MESSAGES_DISAPPEAR_DESC"
        ),
        TutorialPage(
            illustrationType: .endToEndEncryption,
            titleKey: "ONBOARDING_TUTORIAL_E2E_TITLE",
            descriptionKey: "ONBOARDING_TUTORIAL_E2E_DESC"
        )
    ]

    // MARK: - Actions

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func skipTapped() {
        onFinished?()
    }

    @objc private func nextTapped() {
        goToNextPage()
    }

    private func goToNextPage() {
        guard !isAnimating else { return }
        if currentPage < totalPages - 1 {
            currentPage += 1
            updatePage(direction: .left)
        } else {
            onFinished?()
        }
    }

    private func goToPreviousPage() {
        guard !isAnimating, currentPage > 0 else { return }
        currentPage -= 1
        updatePage(direction: .right)
    }

    // MARK: - Update

    private func updatePage(direction: SlideDirection) {
        let page = pages[currentPage]

        let applyContent = {
            self.titleLabel.text = Localized(page.titleKey)
            self.descriptionLabel.text = Localized(page.descriptionKey)
            self.nextButton.setTitle(Localized("ONBOARDING_TUTORIAL_NEXT"), for: .normal)
            self.updateIllustration(page.illustrationType)
            self.titleLabel.textColor = Theme.tprimaryColor
            self.descriptionLabel.textColor = Theme.tsecondaryColor
        }

        updatePageIndicator()

        guard direction != .none else {
            applyContent()
            return
        }

        guard let snapshot = cardContentView.snapshotView(afterScreenUpdates: false) else {
            applyContent()
            return
        }

        isAnimating = true
        let slideOffset: CGFloat = cardContentView.bounds.width * 0.35
        let outX: CGFloat = (direction == .left) ? -slideOffset : slideOffset
        let inX: CGFloat = -outX

        snapshot.frame = cardContentView.bounds
        cardContentView.superview?.addSubview(snapshot)
        snapshot.frame.origin = cardContentView.frame.origin

        applyContent()
        cardContentView.transform = CGAffineTransform(translationX: inX, y: 0)
        cardContentView.alpha = 0

        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
            snapshot.transform = CGAffineTransform(translationX: outX, y: 0)
            snapshot.alpha = 0
            self.cardContentView.transform = .identity
            self.cardContentView.alpha = 1
        } completion: { _ in
            snapshot.removeFromSuperview()
            self.isAnimating = false
        }
    }

    // MARK: - Illustration Builders

    private func updateIllustration(_ type: IllustrationType) {
        illustrationContainer.subviews.forEach { $0.removeFromSuperview() }

        switch type {
        case .messagesDisappear:
            buildMessagesDisappearIllustration()
        case .endToEndEncryption:
            buildEncryptionIllustration()
        }
    }

    private func buildMessagesDisappearIllustration() {
        let imageName = Theme.isDarkThemeEnabled ? "signup_message_icon_dark" : "signup_message_icon_light"
        let imageView = UIImageView(image: UIImage(named: imageName))
        imageView.contentMode = .scaleAspectFit

        illustrationContainer.addSubview(imageView)
        imageView.autoPinEdgesToSuperviewEdges()
    }

    private func buildEncryptionIllustration() {
        let imageName = Theme.isDarkThemeEnabled ? "signup_visible_icon_dark" : "signup_visible_icon_light"
        let imageView = UIImageView(image: UIImage(named: imageName))
        imageView.contentMode = .scaleAspectFit

        illustrationContainer.addSubview(imageView)
        imageView.autoPinEdgesToSuperviewEdges()
    }

    private func updatePageIndicator() {
        pageIndicatorStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        pageIndicatorDots.removeAll()

        for i in 0..<totalPages {
            let dot = UIView()
            dot.layer.cornerRadius = 3
            let isActive = (i == currentPage)
            dot.backgroundColor = isActive ? Theme.tprimaryColor : Theme.tdisableColor
            let width: CGFloat = isActive ? 16 : 6
            dot.autoSetDimensions(to: CGSize(width: width, height: 6))
            pageIndicatorDots.append(dot)
            pageIndicatorStack.addArrangedSubview(dot)
        }
    }

    // MARK: - Views

    private lazy var skipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(Localized("ONBOARDING_TUTORIAL_SKIP"), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14)
        button.setTitleColor(Theme.iconColor, for: .normal)
        button.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        return button
    }()

    private lazy var cardView: UIView = {
        let card = UIView()
        card.backgroundColor = Theme.bgpopupColor
        card.layer.cornerRadius = 24
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOffset = CGSize(width: 0, height: 7)
        card.layer.shadowRadius = 14
        card.layer.shadowOpacity = 0.08
        card.layer.borderWidth = 0.5
        card.layer.borderColor = Theme.lineColor.withAlphaComponent(0.9).cgColor
        return card
    }()

    private lazy var cardContentView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    private lazy var illustrationContainer: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        return view
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 24)
        label.textColor = Theme.tprimaryColor
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = Theme.tsecondaryColor
        label.textAlignment = .left
        label.numberOfLines = 0
        return label
    }()

    private lazy var nextButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = Theme.primaryColor
        button.setTitle(Localized("ONBOARDING_TUTORIAL_NEXT"), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        return button
    }()

    private lazy var pageIndicatorStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()

    private var pageIndicatorDots: [UIView] = []

    // MARK: - Layout

    private func createViews() {
        // Card
        view.addSubview(cardView)
        cardView.autoPinEdge(toSuperviewSafeArea: .top, withInset: 0)
        cardView.autoPinEdge(toSuperviewEdge: .left, withInset: 16)
        cardView.autoPinEdge(toSuperviewEdge: .right, withInset: 16)
        cardView.autoPinEdge(toSuperviewSafeArea: .bottom, withInset: 16)

        // Card content
        cardView.addSubview(cardContentView)
        cardContentView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))

        // Illustration
        cardContentView.addSubview(illustrationContainer)
        illustrationContainer.autoHCenterInSuperview()
        illustrationContainer.autoPinEdge(toSuperviewEdge: .top, withInset: 100)
        illustrationContainer.autoSetDimensions(to: CGSize(square: 120))

        // Title
        cardContentView.addSubview(titleLabel)
        titleLabel.autoPinEdge(.top, to: .bottom, of: illustrationContainer, withOffset: 12)
        titleLabel.autoPinEdge(toSuperviewEdge: .left)
        titleLabel.autoPinEdge(toSuperviewEdge: .right)

        // Description
        cardContentView.addSubview(descriptionLabel)
        descriptionLabel.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: 24)
        descriptionLabel.autoPinEdge(toSuperviewEdge: .left, withInset: 12)
        descriptionLabel.autoPinEdge(toSuperviewEdge: .right, withInset: 12)

        // Next button
        cardContentView.addSubview(nextButton)
        nextButton.autoPinEdge(.top, to: .bottom, of: descriptionLabel, withOffset: 24)
        nextButton.autoPinEdge(toSuperviewEdge: .left)
        nextButton.autoPinEdge(toSuperviewEdge: .right)
        nextButton.autoSetDimension(.height, toSize: 48)

        // Page indicator
        cardContentView.addSubview(pageIndicatorStack)
        pageIndicatorStack.autoPinEdge(.top, to: .bottom, of: nextButton, withOffset: 24)
        pageIndicatorStack.autoHCenterInSuperview()
    }
}
