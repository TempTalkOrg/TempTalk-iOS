//
//  EditContactNameViewController.swift
//  TempTalk
//
//  Created by henry Code on 2025/1/7.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation

final class EditContactNameViewController: SettingBaseViewController {
    
    let disableAlpha = 0.4

    fileprivate lazy var contactNameTextField: UITextField = {
        let textField = UITextField()
        textField.text = self.currentContactName
        textField.placeholder = Localized("EDIT_CONTACT_NAME_PLACEHOLDER")
        textField.borderStyle = .roundedRect
        textField.layer.borderWidth = 1
        textField.layer.borderColor = Theme.lineColor.cgColor
        textField.layer.cornerRadius = 8
        textField.backgroundColor = Theme.bgpopupColor
        textField.textColor = Theme.tprimaryColor
        textField.font = UIFont.systemFont(ofSize: 16)
        textField.delegate = self
        textField.keyboardType = .default
        textField.returnKeyType = .done

        // Set placeholder color
        let placeholderColor = Theme.tdisableColor
        textField.attributedPlaceholder = NSAttributedString(
            string: Localized("EDIT_CONTACT_NAME_PLACEHOLDER"),
            attributes: [NSAttributedString.Key.foregroundColor: placeholderColor]
        )

        return textField
    }()

    fileprivate lazy var tipsLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.text = ""
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = Theme.terrorColor
        label.isHidden = true
        label.numberOfLines = 0
        return label
    }()

    fileprivate lazy var rulesLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.font = UIFont(name: "SFPro-Regular", size: 14) ?? UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor(red: 0.278, green: 0.302, blue: 0.341, alpha: 1)

        // Set line height to 1.2x (20pt for 14pt font)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.2

        let rulesText = Localized("EDIT_CONTACT_NAME_RULES")
        label.attributedText = NSMutableAttributedString(
            string: rulesText,
            attributes: [NSAttributedString.Key.paragraphStyle: paragraphStyle]
        )

        return label
    }()

    fileprivate lazy var saveButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(Localized("EDIT_CONTACT_NAME_SAVE_BUTTON"), for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        button.setTitleColor(Theme.twhiteColor, for: .normal)
        button.backgroundColor = Theme.primaryColor
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        button.isEnabled = false
        button.alpha = disableAlpha
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        return button
    }()

    var currentContactName: String = ""
    var suggestedContactName: String = ""
    var saveCompletion: ((String) -> Void)?
    var profileInfoApi: DTProfileInfoApi?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupBackButton()
        DispatchQueue.main.async {
            self.setupView()
            self.setupLayout()
            self.applyTheme()
        }
    }

    deinit {
        OWSLogger.info("edit contact name view deinit.")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        contactNameTextField.becomeFirstResponder()
    }

    private func setupView() {
        self.navigationItem.title = Localized("EDIT_CONTACT_NAME_TITLE")
        view.addSubview(contactNameTextField)
        view.addSubview(tipsLabel)
        view.addSubview(rulesLabel)
        view.addSubview(saveButton)
    }

    private func setupLayout() {
        contactNameTextField.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).offset(16)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(48)
        }

        tipsLabel.snp.makeConstraints { make in
            make.top.equalTo(contactNameTextField.snp.bottom).offset(12)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }

        rulesLabel.snp.makeConstraints { make in
            if tipsLabel.isHidden {
                // If tips label is hidden, rules label is 12px below text field
                make.top.equalTo(contactNameTextField.snp.bottom).offset(12)
            } else {
                // If tips label is visible, rules label is 16px below tips label
                make.top.equalTo(tipsLabel.snp.bottom).offset(16)
            }
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }

        saveButton.snp.makeConstraints { make in
            make.top.equalTo(rulesLabel.snp.bottom).offset(24)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.height.equalTo(48)
        }
    }

    override func applyTheme() {
        super.applyTheme()
        self.view.backgroundColor = Theme.bgpageSecondaryColor
        contactNameTextField.backgroundColor = Theme.bgpopupColor
        tipsLabel.textColor = Theme.terrorColor
    }

    @objc func saveButtonTapped() {
        guard let newName = contactNameTextField.text, !newName.isEmpty else {
            return
        }

        // Validate contact name
        if getValidationErrorMessage(newName) == nil {
            // Show loading indicator
            DTToastHelper.show()

            // Call API to update customUid
            let params: [String: Any] = [
                "customUid": newName
            ]
            profileInfoApi?.setProfileInfo(params) { [weak self] _ in
                DispatchQueue.main.async {
                    DTToastHelper.hide()
                    self?.saveCompletion?(newName)
                    self?.navigationController?.popViewController(animated: true)
                }
            } failure: { [weak self] error in
                DispatchQueue.main.async {
                    DTToastHelper.hide()
                    // Check if error is due to UID already exists (10301)
                    if let nsError = error as? NSError, nsError.code == 10301 {
                        // Extract recommended UID from error message
                        let errorMessage = Localized("EDIT_CONTACT_NAME_TAKEN") + nsError.localizedDescription
                        self?.showErrorState(with: errorMessage)
                    } else if let nsError = error as? NSError, nsError.code == 10302 {
                        // Name change limit error (can only change once every 3 months)
                        let errorMessage = Localized("EDIT_CONTACT_NAME_CHANGE_LIMIT")
                        self?.showErrorState(with: errorMessage)
                    }  else {
                        Logger.error("[setProfileInfo] request error \(error.localizedDescription)")
                        self?.showErrorState(with: Localized("EDIT_CONTACT_NAME_ERROR"))
                    }
                }
            }
        }
    }

    private func setupBackButton() {
        let backButton = UIButton(type: .custom)
        backButton.setImage(UIImage(named: "nav_back_arrow_new"), for: .normal)
        backButton.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)

        let backBarButtonItem = UIBarButtonItem(customView: backButton)
        self.navigationItem.leftBarButtonItem = backBarButtonItem
    }

    @objc func backButtonTapped() {
        self.navigationController?.popViewController(animated: true)
    }

    private func getValidationErrorMessage(_ name: String) -> String? {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)

        // Rule 1: Check length (6-20 characters)
        if trimmedName.count < 6 || trimmedName.count > 20 {
            return Localized("EDIT_CONTACT_NAME_ERROR_LENGTH")
        }

        // Rule 2: Check if starts with letter or "_"
        if !trimmedName.isEmpty {
            guard let firstChar = trimmedName.first else {
                return Localized("EDIT_CONTACT_NAME_ERROR_START")
            }
            if !((firstChar >= "a" && firstChar <= "z") ||
                 (firstChar >= "A" && firstChar <= "Z") ||
                 firstChar == "_") {
                return Localized("EDIT_CONTACT_NAME_ERROR_START")
            }
        }

        // Rule 3: Check if contains only letters, numbers, "_" or "-"
        let validCharacterSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-")
        if !trimmedName.unicodeScalars.allSatisfy({ validCharacterSet.contains($0) }) {
            return Localized("EDIT_CONTACT_NAME_ERROR_CONTENT")
        }

        return nil
    }

    private func updateRulesLabelConstraints() {
        rulesLabel.snp.remakeConstraints { make in
            if tipsLabel.isHidden {
                // If tips label is hidden, rules label is 12px below text field
                make.top.equalTo(contactNameTextField.snp.bottom).offset(12)
            } else {
                // If tips label is visible, rules label is 16px below tips label
                make.top.equalTo(tipsLabel.snp.bottom).offset(16)
            }
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
        }

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }
}

// MARK: - UITextFieldDelegate

extension EditContactNameViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let name = textField.text, !name.isEmpty else {
            return true
        }

        if getValidationErrorMessage(name) == nil {
            saveButtonTapped()
        }
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Calculate the new text after the change
        let currentText = textField.text ?? ""
        let newText = (currentText as NSString).replacingCharacters(in: range, with: string)

        // Update tips label and button state based on input
        updateUIState(with: newText)

        return true
    }

    private func updateUIState(with text: String) {
        if text.isEmpty {
            // Hide tips label if empty
            tipsLabel.isHidden = true
            contactNameTextField.layer.borderColor = Theme.lineColor.cgColor
            saveButton.isEnabled = false
            saveButton.alpha = disableAlpha
        } else {
            // Validate contact name
            if getValidationErrorMessage(text) == nil {
                tipsLabel.isHidden = true
                contactNameTextField.layer.borderColor = Theme.lineColor.cgColor
                saveButton.isEnabled = true
                saveButton.alpha = 1.0
            } else {
                // Show specific validation error
                if let errorMessage = getValidationErrorMessage(text) {
                    tipsLabel.text = errorMessage
                } else {
                    tipsLabel.text = Localized("EDIT_CONTACT_NAME_ERROR")
                }
                tipsLabel.isHidden = false
                contactNameTextField.layer.borderColor = Theme.terrorColor.cgColor
                saveButton.isEnabled = false
                saveButton.alpha = disableAlpha
            }
        }

        // Update rules label constraints
        updateRulesLabelConstraints()
    }

    private func showErrorState(with message: String) {
        tipsLabel.text = message
        tipsLabel.isHidden = false
        contactNameTextField.layer.borderColor = Theme.terrorColor.cgColor
        saveButton.isEnabled = false
        saveButton.alpha = disableAlpha
        updateRulesLabelConstraints()
    }
}

