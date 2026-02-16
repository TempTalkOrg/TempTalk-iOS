//
//  TranslateResultViewController.swift
//  TempTalk
//
//  Created by henry on 2025/12/27.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import UIKit
import PanModal
import SnapKit
import TTServiceKit

// MARK: - TranslateResultViewController

class TranslateResultViewController: UIViewController, PanModalPresentable {

    // MARK: - Properties

    private let originalText: String
    private var translatedText: String?
    private let sourceLanguage: DTTranslateMessageType
    private var currentTargetLanguage: DTTranslateMessageType

    private var originalTextLabel: UILabel?
    private var dividerView: UIView?
    private var translatedTextView: UITextView?
    private var switchLanguageButton: UIButton?
    private var loadingIndicator: UIActivityIndicatorView?

    // 按钮约束引用，用于动画更新
    private var buttonTopConstraint: Constraint?
    private var buttonBottomConstraint: Constraint?

    // 翻译 API
    private var translateApi: DTTranslateApi {
        DTTranslateProcessor.sharedInstance().translateApi
    }

    // MARK: - Initialization

    init(originalText: String, sourceLanguage: DTTranslateMessageType, targetLanguage: DTTranslateMessageType) {
        self.originalText = originalText
        self.sourceLanguage = sourceLanguage
        self.currentTargetLanguage = targetLanguage
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadTranslation()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = Theme.bg1Color

        // 原文标签（最多2行）
        originalTextLabel = UILabel()
        originalTextLabel?.numberOfLines = 2
        originalTextLabel?.font = UIFont.systemFont(ofSize: 14)
        originalTextLabel?.textColor = UIColor.ows_gray45
        originalTextLabel?.text = originalText
        if let originalTextLabel = originalTextLabel {
            view.addSubview(originalTextLabel)
        }

        // 分割线
        dividerView = UIView()
        dividerView?.backgroundColor = Theme.lineColor
        if let dividerView = dividerView {
            view.addSubview(dividerView)
        }

        // 翻译结果 TextView
        translatedTextView = UITextView()
        translatedTextView?.backgroundColor = .clear
        translatedTextView?.isEditable = false
        translatedTextView?.isSelectable = true
        translatedTextView?.isScrollEnabled = true
        translatedTextView?.alwaysBounceVertical = true
        translatedTextView?.font = UIFont.systemFont(ofSize: 16)
        translatedTextView?.textColor = Theme.tprimaryColor
        translatedTextView?.text = ""
        translatedTextView?.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        translatedTextView?.showsVerticalScrollIndicator = true
        translatedTextView?.showsHorizontalScrollIndicator = false
        translatedTextView?.contentInsetAdjustmentBehavior = .never
        if let translatedTextView = translatedTextView {
            view.addSubview(translatedTextView)
        }

        // 加载指示器
        loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator?.hidesWhenStopped = true
        if let loadingIndicator = loadingIndicator {
            view.addSubview(loadingIndicator)
        }

        // 切换语言按钮
        switchLanguageButton = UIButton(type: .system)
        updateSwitchLanguageButtonTitle()
        switchLanguageButton?.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        switchLanguageButton?.setTitleColor(Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0x82C1FC) : UIColor.color(rgbHex: 0x056FFA), for: .normal)
        switchLanguageButton?.contentHorizontalAlignment = .left
        switchLanguageButton?.addTarget(self, action: #selector(switchLanguageTapped), for: .touchUpInside)
        if let switchLanguageButton = switchLanguageButton {
            view.addSubview(switchLanguageButton)
        }

        setupConstraints()
    }

    private func setupConstraints() {
        originalTextLabel?.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
        }

        dividerView?.snp.makeConstraints { make in
            if let originalTextLabel = originalTextLabel {
                make.top.equalTo(originalTextLabel.snp.bottom).offset(12)
            } else {
                make.top.equalTo(view.safeAreaLayoutGuide).offset(12)
            }
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }

        // 按钮初始状态（shortForm模式）
        switchLanguageButton?.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            buttonTopConstraint = make.top.equalTo(view.safeAreaLayoutGuide).offset(300 - 34).constraint
            buttonBottomConstraint = make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20).constraint
            make.width.equalTo(150)
            make.height.equalTo(20)
        }
        buttonBottomConstraint?.deactivate()

        // TextView 填充剩余空间
        translatedTextView?.snp.makeConstraints { make in
            if let dividerView = dividerView {
                make.top.equalTo(dividerView.snp.bottom)
            } else {
                make.top.equalTo(view.safeAreaLayoutGuide)
            }
            make.leading.trailing.equalToSuperview()
            if let switchLanguageButton = switchLanguageButton {
                make.bottom.equalTo(switchLanguageButton.snp.top).offset(-10)
            } else {
                make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-10)
            }
        }

        if let translatedTextView = translatedTextView {
            loadingIndicator?.snp.makeConstraints { make in
                make.centerX.equalTo(translatedTextView)
                make.centerY.equalTo(translatedTextView)
            }
        }
    }

    private func updateSwitchLanguageButtonTitle() {
        let buttonTitleKey = currentTargetLanguage == .english ? "CONVERSATION_PANMODEL_TRANSLATE_TO_CHINESE" : "CONVERSATION_PANMODEL_TRANSLATE_TO_ENGLISH"
        let buttonTitle = Localized(buttonTitleKey, nil) ?? (currentTargetLanguage == .english ? "Translate to Chinese" : "Translate to English")
        switchLanguageButton?.setTitle(buttonTitle, for: .normal)
    }

    // MARK: - Translation

    private func loadTranslation() {
        loadingIndicator?.startAnimating()
        translatedTextView?.text = ""
        translatedTextView?.textColor = Theme.tprimaryColor

        translateApi.translateText(
            originalText,
            targetLang: currentTargetLanguage
        ) { [weak self] entity in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.loadingIndicator?.stopAnimating()

                let translateResult = entity.data.translatedText

                if !translateResult.isEmpty {
                    self.translatedText = translateResult
                    self.translatedTextView?.text = translateResult
                } else {
                    let errorMessage = Localized("TRANSLATE_TIP_MESSAGE_FAILED", "") ?? "Translation failed"
                    self.translatedTextView?.text = errorMessage
                    self.translatedTextView?.textColor = Theme.tsecondaryColor
                }
            }
        } failure: { [weak self] error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.loadingIndicator?.stopAnimating()

                let errorMessage = Localized("TRANSLATE_TIP_MESSAGE_FAILED", "") ?? "Translation failed"
                self.translatedTextView?.text = errorMessage
                self.translatedTextView?.textColor = Theme.tsecondaryColor

                DTToastHelper.toast(withText: errorMessage, durationTime: 2.0)
            }
        }
    }

    // MARK: - Actions

    @objc private func switchLanguageTapped() {
        // 切换目标语言
        currentTargetLanguage = currentTargetLanguage == .english ? .chinese : .english

        // 更新按钮文字
        updateSwitchLanguageButtonTitle()

        // 重新翻译
        loadTranslation()
    }

    // MARK: - PanModalPresentable

    var panScrollable: UIScrollView? {
        // 返回 nil，让 PanModal 不管理 ScrollView，避免滚动冲突
        return nil
    }

    var shortFormHeight: PanModalHeight {
        return .contentHeight(300)
    }

    var longFormHeight: PanModalHeight {
        return .maxHeight
    }

    var anchorModalToLongForm: Bool {
        return false
    }

    var shouldRoundTopCorners: Bool {
        return true
    }

    var cornerRadius: CGFloat {
        return 16.0
    }

    var showDragIndicator: Bool {
        return true
    }

    func shouldRespond(to panModalGestureRecognizer: UIPanGestureRecognizer) -> Bool {
        // 获取触摸位置
        let location = panModalGestureRecognizer.location(in: view)

        // 如果触摸在 TextView 区域内，不让 PanModal 响应
        if let translatedTextView = translatedTextView, translatedTextView.frame.contains(location) {
            return false
        }

        return true
    }

    func willTransition(to state: PanModalPresentationController.PresentationState) {
        if state == .longForm {
            buttonTopConstraint?.deactivate()
            buttonBottomConstraint?.activate()
        } else {
            buttonBottomConstraint?.deactivate()
            buttonTopConstraint?.activate()
        }
    }
}

