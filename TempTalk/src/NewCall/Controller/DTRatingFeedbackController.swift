//
//  DTRatingFeedbackController.swift
//  Difft
//
//  Created by Henry on 2025/10/14.
//  Copyright © 2025 Difft. All rights reserved.

import UIKit
import PanModal
import TTMessaging

@objc
public class DTRatingFeedbackController: OWSViewController, PanModalPresentable {

    // MARK: - Public API

    @objc public class FeedbackResult: NSObject {
        @objc public let stars: Int
        @objc public let reasons: [String]?
        @objc public init(stars: Int, reasons: [String]? = nil) {
            self.stars = stars
            self.reasons = reasons
        }
    }

    @objc public var submitHandler: ((FeedbackResult) -> Void)?

    @objc
    public static func present(from source: UIViewController, submit: ((FeedbackResult) -> Void)? = nil) {
        let vc = DTRatingFeedbackController()
        vc.submitHandler = submit
        let nav = DTPanModalNavController(rootViewController: vc, defaultHeight: 270.0)
        source.presentPanModal(nav)
    }

    // MARK: - State

    private enum ViewState {
        case rating
        case reasons
    }

    private var viewState: ViewState = .rating {
        didSet { applyViewState(animated: true) }
    }

    private var selectedStars: Int = 0 {
        didSet {
            updateSubmitButtonState()
        }
    }
    // MARK: - Views

    private lazy var contentContainer: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.alignment = .fill
        s.distribution = .fill
        s.spacing = 12
        return s
    }()

    private lazy var messageLabel: UILabel = {
        let l = UILabel()
        l.text = Localized("CALL_RATING_STAR_DESCRIPTION", "")
        l.textColor = Theme.tsecondaryColor
        l.font = UIFont.systemFont(ofSize: 13)
        l.numberOfLines = 0
        l.textAlignment = .center
        return l
    }()

    private lazy var starsStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.alignment = .center
        s.distribution = .equalSpacing
        s.spacing = 24
        return s
    }()

    private var starButtons: [UIButton] = []

    // Hint text under stars
    private lazy var ratingHintLabel: UILabel = {
        let l = UILabel()
        l.textAlignment = .center
        l.textColor = UIColor.color(rgbHex: 0x848E9C)
        l.font = UIFont.systemFont(ofSize: 12)
        l.numberOfLines = 0
        l.text = ""
        return l
    }()

    private lazy var submitButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle(Localized("CALL_RATING_SUBMIT", ""), for: .normal)
        b.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        b.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x474D57) : UIColor.color(rgbHex: 0xEAECEF)
        b.setTitleColor(Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x5E6673) : UIColor.color(rgbHex: 0xB7BDC6), for: .normal)
        b.layer.cornerRadius = 10
        b.isUserInteractionEnabled = false
        b.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        return b
    }()

    private lazy var cancelButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle(Localized("CALL_RATING_NOT_NOW", ""), for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        b.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x474D57) : UIColor.color(rgbHex: 0xFFFFFF)
        b.setTitleColor(Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xEAECEF) : UIColor.color(rgbHex: 0x1E2329), for: .normal)
        b.layer.cornerRadius = 10
        b.layer.borderWidth = 1
        b.layer.borderColor = Theme.isDarkThemeEnabled ? UIColor.init(rgbHex: 0x474D57).cgColor : UIColor.init(rgbHex: 0xEAECEF).cgColor
        b.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        return b
    }()

    private lazy var buttonsStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.alignment = .fill
        s.distribution = .fillEqually
        s.spacing = 24
        return s
    }()

    private lazy var reasonsButtonsStack: UIStackView = {
        let s = UIStackView()
        s.axis = .horizontal
        s.alignment = .fill
        s.distribution = .fillEqually
        s.spacing = 12
        return s
    }()

    private lazy var reasonsCancelButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle(Localized("CALL_RATING_NOT_NOW", ""), for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        b.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x474D57) : UIColor.color(rgbHex: 0xFFFFFF)
        b.setTitleColor(Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xEAECEF) : UIColor.color(rgbHex: 0x1E2329), for: .normal)
        b.layer.cornerRadius = 10
        b.layer.borderWidth = 1
        b.layer.borderColor = Theme.isDarkThemeEnabled ? UIColor.init(rgbHex: 0x474D57).cgColor : UIColor.init(rgbHex: 0xEAECEF).cgColor
        b.addTarget(self, action: #selector(reasonsCancelTapped), for: .touchUpInside)
        return b
    }()

    private lazy var reasonsSubmitButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle(Localized("CALL_RATING_SUBMIT", ""), for: .normal)
        b.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        b.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x474D57) : UIColor.color(rgbHex: 0xEAECEF)
        b.setTitleColor(Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x5E6673) : UIColor.color(rgbHex: 0xB7BDC6), for: .normal)
        b.layer.cornerRadius = 10
        b.isUserInteractionEnabled = false
        b.addTarget(self, action: #selector(reasonsSubmitTapped), for: .touchUpInside)
        return b
    }()
    
    private let reasonsTableView = FeedbackReasonsView()

    // MARK: - Lifecycle

    public override func loadView() {
        super.loadView()
        view.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x181A20) : UIColor.color(rgbHex: 0xFFFFFF)
        navigationItem.title = Localized("CALL_RATING_STAR_TITLE", "")
        setupLayout()
        setupStars()
        setupFooter()
        updateSubmitButtonState()
        applyViewState(animated: false)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x181A20) : UIColor.color(rgbHex: 0xFFFFFF)
    }

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(contentContainer)
        
        // contentContainer 布局
        contentContainer.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        contentContainer.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        contentContainer.isLayoutMarginsRelativeArrangement = true
        
        // messageLabel
        contentContainer.addArrangedSubview(messageLabel)
        
        // ⭐️ Stars Section
        let starsWrapper = UIView()
        contentContainer.addArrangedSubview(starsWrapper)
        starsWrapper.addSubview(starsStack)
        starsStack.autoPinEdge(toSuperviewEdge: .top, withInset: 8)
        starsStack.autoAlignAxis(toSuperviewAxis: .vertical)
        starsStack.autoPinEdge(toSuperviewEdge: .bottom, withInset: 8)
        
        // 提示文本
        contentContainer.addArrangedSubview(ratingHintLabel)
        
        // 🔘 按钮 Section
        let buttonsWrapper = UIView()
        contentContainer.addArrangedSubview(buttonsWrapper)
        buttonsWrapper.addSubview(buttonsStack)
        buttonsStack.autoPinEdge(toSuperviewEdge: .top, withInset: 12)
        buttonsStack.autoPinEdge(toSuperviewEdge: .leading, withInset: 16)
        buttonsStack.autoPinEdge(toSuperviewEdge: .trailing, withInset: 16)
        buttonsStack.autoSetDimension(.height, toSize: 48)
        buttonsStack.autoPinEdge(toSuperviewEdge: .bottom, withInset: 12)
        
        // 设置 stackview 内自定义间距
        contentContainer.setCustomSpacing(20, after: buttonsWrapper)
    }
    
    private func loadReasonsLayout() {
        contentContainer.removeAllSubviews()
        let reasonsTableWrapper = UIView()
        contentContainer.addArrangedSubview(reasonsTableWrapper)
        
        reasonsTableWrapper.addSubview(reasonsTableView)
        reasonsTableView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: -10, left: 0, bottom: 0, right: 0))
        reasonsTableView.autoSetDimension(.height, toSize: 350)
        
        contentContainer.addArrangedSubview(reasonsButtonsStack)
        reasonsButtonsStack.autoSetDimension(.height, toSize: 48)
        reasonsButtonsStack.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        reasonsButtonsStack.isLayoutMarginsRelativeArrangement = true
        
        reasonsTableView.onSelectionChanged = { [weak self] hasSelection in
            guard let self = self else { return }
            if hasSelection {
                self.reasonsSubmitButton.backgroundColor = UIColor.color(rgbHex: 0x056FFA)
                self.reasonsSubmitButton.setTitleColor(.white, for: .normal)
                self.reasonsSubmitButton.isUserInteractionEnabled = true
            } else {
                self.reasonsSubmitButton.backgroundColor = Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x474D57) : UIColor.color(rgbHex: 0xEAECEF)
                self.reasonsSubmitButton.setTitleColor(Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x5E6673) : UIColor.color(rgbHex: 0xB7BDC6), for: .normal)
                self.reasonsSubmitButton.isUserInteractionEnabled = false
            }
        }
    }

    private func setupStars() {
        starButtons = (1...5).map { index in
            let btn = UIButton(type: .custom)
            btn.tag = index
            btn.setImage(UIImage(named: "call_rating_star_empty"), for: .normal)
            btn.addTarget(self, action: #selector(starTapped(_:)), for: .touchUpInside)
            return btn
        }
        starButtons.forEach { starsStack.addArrangedSubview($0) }
        refreshStars()
    }

    private func setupFooter() {
        // Buttons are in header; also compose stack now
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        buttonsStack.addArrangedSubview(cancelButton)
        buttonsStack.addArrangedSubview(submitButton)
        updateSubmitButtonState()

        reasonsButtonsStack.translatesAutoresizingMaskIntoConstraints = false
        reasonsCancelButton.translatesAutoresizingMaskIntoConstraints = false
        reasonsSubmitButton.translatesAutoresizingMaskIntoConstraints = false
        reasonsButtonsStack.addArrangedSubview(reasonsCancelButton)
        reasonsButtonsStack.addArrangedSubview(reasonsSubmitButton)
    }

    // MARK: - Actions

    @objc private func starTapped(_ sender: UIButton) {
        selectedStars = sender.tag
        updateRatingHint()
    }

    @objc private func submitTapped() {
        if selectedStars <= 2 {
            viewState = .reasons
            return
        }
        
        submitFeedback(reasons: [:])
    }
    
    private func dismissRate() {
        DTMeetingManager.shared.feedbackUserSid = nil
        DTMeetingManager.shared.feedbackRoomSid = nil
        DTMeetingManager.shared.feedbackRoomId = nil
        DTMeetingManager.shared.feedbackIsNetworkPoor = nil
        dismiss(animated: true)
    }

    @objc private func cancelTapped() {
        dismissRate()
    }

    // MARK: - Helpers

    private func refreshStars() {
        for (idx, btn) in starButtons.enumerated() {
            let index = idx + 1
            let isFilled = index <= selectedStars
            if isFilled {
                btn.setImage(UIImage(named: "call_rating_star_fill"), for: .normal)
            } else {
                btn.setImage(UIImage(named: "call_rating_star_empty"), for: .normal)
            }
        }
    }

    private func updateSubmitButtonState() {
        let enabled = selectedStars > 0
        submitButton.isEnabled = enabled
        submitButton.alpha = enabled ? 1.0 : 0.5
    }

    private func updateRatingHint() {
        let text: String
        switch selectedStars {
        case 1: text = Localized("CALL_RATING_DESC_1", "")
        case 2: text = Localized("CALL_RATING_DESC_2", "")
        case 3: text = Localized("CALL_RATING_DESC_3", "")
        case 4: text = Localized("CALL_RATING_DESC_4", "")
        case 5: text = Localized("CALL_RATING_DESC_5", "")
        default: text = ""
        }
        ratingHintLabel.text = text
        submitButton.backgroundColor = UIColor.color(rgbHex: 0x056FFA)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.isUserInteractionEnabled = true
        refreshStars()
    }

    private func applyViewState(animated: Bool) {
        let isReasons = (viewState == .reasons)
        // Rating section (titleLabel removed)
        messageLabel.isHidden = isReasons
        starsStack.isHidden = isReasons
        ratingHintLabel.isHidden = isReasons
        buttonsStack.isHidden = isReasons

        // Reasons section
        reasonsTableView.isHidden = !isReasons
        reasonsButtonsStack.isHidden = !isReasons
        
        navigationItem.title = isReasons ? Localized("CALL_RATING_REASON_TITLE", "") : Localized("CALL_RATING_STAR_TITLE", "")
        if isReasons {
            loadReasonsLayout()
        }

        if let nav = navigationController as? DTPanModalNavController {
            nav.panModalSetNeedsLayoutUpdate()
            nav.panModalTransition(to: isReasons ? .longForm : .shortForm)
        }
    }

    public var panScrollable: UIScrollView? { nil }
    
    public var shortFormHeight: PanModalHeight {
        .contentHeight(270)
    }

    public var longFormHeight: PanModalHeight {
        .contentHeight(500)
    }
}

// MARK: - Reasons Buttons Actions
private extension DTRatingFeedbackController {
    @objc func reasonsCancelTapped() {
        dismissRate()
    }

    @objc func reasonsSubmitTapped() {
        let selectedIndexes = reasonsTableView.submitSelectedItems()
        var reasonsDict: [String: [Int]] = [:]
        for (tabIndex, indexes) in selectedIndexes {
            switch tabIndex {
            case 0:
                reasonsDict["audio"] = indexes
            case 1:
                reasonsDict["video"] = indexes
            case 2:
                reasonsDict["other"] = indexes
            default:
                break
            }
        }
        
        submitFeedback(reasons: reasonsDict)
    }
    
    private func submitFeedback(reasons: [String: [Int]] = [:]) {
        guard let account = TSAccountManager.localNumber(),
              let userSid = DTMeetingManager.shared.feedbackUserSid,
              let roomSid = DTMeetingManager.shared.feedbackRoomSid,
              let roomId = DTMeetingManager.shared.feedbackRoomId else {
            dismissRate()
            return
        }
        
        let userIdentity = "\(account).1"
        FeedbackAPI().feedbackServers(params: [
            "userIdentity": userIdentity,
            "userSid": userSid,
            "roomSid": roomSid,
            "roomId": roomId,
            "rating": selectedStars,
            "reasons": reasons
        ]) { _ in
            Logger.info("[newCall] feedback Success")
            self.dismissRate()
        } failure: { error, _ in
            Logger.error("[newCall] feedback failure \(error.localizedDescription)")
            self.dismissRate()
        }
    }
}


