//
//  DTResetGroupCryptoKeyViewController.swift
//  TempTalk
//
//  Copyright © 2026 Difft. All rights reserved.
//

import Foundation
import UIKit
import SnapKit
import TTMessaging
import TTServiceKit

/// "Reset encryption key" dialog for encrypted groups (Android-parity).
/// A single always-editable centered card: title, description, a tappable circular avatar with a
/// camera badge, a prefilled group-name field, and a "Cancel / Reset" button row. Presented over the
/// full screen with its own dimmed backdrop (mirrors DTCardAlertViewController). The owner/admin can
/// always edit name/avatar; `onReset` reports the result and the presenter performs the rotate.
@objc public class DTResetGroupCryptoKeyViewController: OWSViewController {

    private let moduleTag = "[GroupCrypto]"

    private let currentName: String
    /// Initial avatar shown before the user picks anything (nil → static placeholder).
    private let prefillAvatar: UIImage?
    /// Called AFTER the dialog dismisses itself when the user taps Reset.
    /// `avatarChanged` is true when the user picked a new image via the picker.
    private let onReset: (_ name: String, _ avatar: UIImage?, _ avatarChanged: Bool) -> Void

    /// nil until the user actually picks a new image via the picker.
    private var pickedAvatar: UIImage?

    // MARK: - Subviews

    private let backdropView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        view.alpha = 0
        return view
    }()

    private let cardView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 14
        view.clipsToBounds = true
        view.alpha = 0
        return view
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = Localized("GROUP_CRYPTO_RESET_TITLE", comment: "Reset Encryption Key")
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = Theme.tprimaryColor
        label.textAlignment = .left
        return label
    }()

    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = Localized("GROUP_CRYPTO_RESET_CONFIRM_BODY",
                               comment: "After reset, group info will use a new encryption key.")
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = Theme.tsecondaryColor
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()

    private lazy var avatarImageView: DTAvatarImageView = {
        let imageView = DTAvatarImageView()
        imageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapAvatar))
        imageView.addGestureRecognizer(tap)
        return imageView
    }()

    private lazy var avatarBadge: UIImageView = {
        let badge = UIImageView(image: UIImage(named: "edit_avatar_icon"))
        badge.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapAvatar))
        badge.addGestureRecognizer(tap)
        return badge
    }()

    private lazy var avatarViewHelper: AvatarViewHelper = {
        let helper = AvatarViewHelper()
        helper.delegate = self
        return helper
    }()

    private lazy var nameTextField: UITextField = {
        let tf = UITextField()
        tf.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        tf.textColor = Theme.tprimaryColor
        tf.backgroundColor = Theme.bg2Color
        tf.layer.cornerRadius = 8
        tf.clipsToBounds = true
        tf.clearButtonMode = .whileEditing
        tf.returnKeyType = .done
        tf.delegate = self
        tf.text = currentName
        tf.attributedPlaceholder = NSAttributedString(
            string: Localized("GROUP_CRYPTO_RESET_NAME_PLACEHOLDER", comment: "Enter a group name"),
            attributes: [.foregroundColor: Theme.tdisableColor]
        )
        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 0))
        tf.leftView = padding
        tf.leftViewMode = .always
        return tf
    }()

    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(CommonStrings.cancelButton(), for: .normal)
        button.setTitleColor(Theme.tprimaryColor, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        button.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)
        return button
    }()

    private lazy var resetButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(Localized("GROUP_CRYPTO_RESET_BUTTON", comment: "Reset"), for: .normal)
        button.setTitleColor(Theme.tinfoColor, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        button.addTarget(self, action: #selector(didTapReset), for: .touchUpInside)
        return button
    }()

    /// Keyboard shifts the card up so the name field stays visible. Adjusting this offset.
    private var cardCenterYConstraint: Constraint?

    // MARK: - Init

    @objc public init(currentName: String,
                       prefillAvatar: UIImage?,
                       onReset: @escaping (_ name: String, _ avatar: UIImage?, _ avatarChanged: Bool) -> Void) {
        self.currentName = currentName
        self.prefillAvatar = prefillAvatar
        self.onReset = onReset
        super.init()
        modalPresentationStyle = .overFullScreen
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        applyTheme()
        registerKeyboardObservers()
        avatarImageView.image = prefillAvatar ?? UIImage(named: "empty-group-avatar")
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Fade in the backdrop + card with a subtle scale-up.
        cardView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        UIView.animate(withDuration: 0.2) { [weak self] in
            guard let self else { return }
            self.backdropView.alpha = 1
            self.cardView.alpha = 1
            self.cardView.transform = .identity
        }
    }

    public override func applyTheme() {
        super.applyTheme()
        view.backgroundColor = .clear
        cardView.backgroundColor = Theme.bg1Color
    }

    // MARK: - Layout

    private func setupViews() {
        view.addSubview(backdropView)
        backdropView.snp.makeConstraints { $0.edges.equalToSuperview() }
        let backdropTap = UITapGestureRecognizer(target: self, action: #selector(didTapBackdrop))
        backdropView.addGestureRecognizer(backdropTap)

        view.addSubview(cardView)
        cardView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            self.cardCenterYConstraint = make.centerY.equalToSuperview().constraint
            make.leading.greaterThanOrEqualToSuperview().offset(32)
            make.trailing.lessThanOrEqualToSuperview().offset(-32)
            make.width.lessThanOrEqualTo(320)
            make.width.equalTo(320).priority(.high)
        }

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 16
        cardView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(20)
            make.leading.trailing.equalToSuperview().inset(24)
        }

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(descriptionLabel)
        stackView.addArrangedSubview(makeAvatarBlock())
        stackView.addArrangedSubview(makeNameField())
        stackView.addArrangedSubview(makeButtonRow())
    }

    /// Centered circular avatar with a camera badge anchored bottom-trailing.
    private func makeAvatarBlock() -> UIView {
        let wrapper = UIView()
        wrapper.addSubview(avatarImageView)
        wrapper.addSubview(avatarBadge)
        avatarImageView.snp.makeConstraints { make in
            make.width.height.equalTo(72)
            make.top.bottom.equalToSuperview()
            make.centerX.equalToSuperview()
        }
        avatarBadge.snp.makeConstraints { make in
            make.width.height.equalTo(28)
            make.trailing.bottom.equalTo(avatarImageView)
        }
        return wrapper
    }

    private func makeNameField() -> UIView {
        nameTextField.snp.makeConstraints { $0.height.equalTo(44) }
        return nameTextField
    }

    /// Right-aligned "Cancel / Reset" row.
    private func makeButtonRow() -> UIView {
        let row = UIStackView(arrangedSubviews: [cancelButton, resetButton])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 24
        // Spacer pushes the buttons to the right.
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.insertArrangedSubview(spacer, at: 0)
        return row
    }

    // MARK: - Keyboard

    private func registerKeyboardObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow(_:)),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide(_:)),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        // Shift the card up by part of the keyboard height so the name field stays visible.
        let offset = -min(frame.height * 0.5, 160)
        cardCenterYConstraint?.update(offset: offset)
        UIView.animate(withDuration: 0.25) { [weak self] in
            self?.view.layoutIfNeeded()
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        cardCenterYConstraint?.update(offset: 0)
        UIView.animate(withDuration: 0.25) { [weak self] in
            self?.view.layoutIfNeeded()
        }
    }

    // MARK: - Actions

    @objc private func didTapAvatar() {
        view.endEditing(true)
        avatarViewHelper.showChangeAvatarUI()
    }

    @objc private func didTapBackdrop() {
        // Backdrop tap cancels: dismiss without calling onReset.
        view.endEditing(true)
        dismiss(animated: false)
    }

    @objc private func didTapCancel() {
        Logger.info("\(moduleTag) reset dialog cancelled")
        view.endEditing(true)
        dismiss(animated: false)
    }

    @objc private func didTapReset() {
        view.endEditing(true)
        let name = (nameTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        // Block an empty name: keep the dialog open and do not start the rotate (test-cases.md case 5).
        guard !name.isEmpty else {
            Logger.info("\(moduleTag) reset blocked: empty group name")
            DTToastHelper.showInfo(Localized("GROUP_CRYPTO_RESET_NAME_EMPTY", comment: "Enter a group name"))
            return
        }
        let avatarChanged = pickedAvatar != nil
        let avatar = pickedAvatar ?? prefillAvatar
        Logger.info("\(moduleTag) reset dialog confirmed, avatarChanged: \(avatarChanged)")
        // Dismiss first, then report — the presenter performs the rotate with fromPage: nil.
        dismiss(animated: false) { [weak self] in
            self?.onReset(name, avatar, avatarChanged)
        }
    }
}

// MARK: - UITextFieldDelegate

extension DTResetGroupCryptoKeyViewController: UITextFieldDelegate {
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - AvatarViewHelperDelegate

extension DTResetGroupCryptoKeyViewController: AvatarViewHelperDelegate {

    public func avatarActionSheetTitle() -> String {
        Localized("NEW_GROUP_ADD_PHOTO_ACTION",
                  comment: "Action Sheet title prompting the user for a group avatar")
    }

    public func avatarDidChange(_ image: UIImage) {
        pickedAvatar = image
        avatarImageView.image = image
    }

    public func fromViewController() -> UIViewController {
        self
    }

    public func hasClearAvatarAction() -> Bool {
        false
    }
}
