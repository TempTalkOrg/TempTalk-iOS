//
//  DTAddFileController.swift
//  Signal
//
//  Created by Ethan on 29/08/2023.
//  Copyright © 2023 Difft. All rights reserved.
//

import UIKit
import SignalMessaging
import SignalServiceKit

class DTAddFileController: OWSViewController {

    var file = DTMeetingAttachment()!
    
    var updateFileHandler: ( (DTMeetingAttachment) -> Void )?
    
    private let titlePlaceholder = "Enter a name"
    
    private let linkPlaceholder = "Paste URL here"
    
    private lazy var lbTitle: UILabel = createLabel("Title")
    
    private lazy var lbLink: UILabel = createLabel("Link")
    
    private lazy var tfTitle: DTTextField = createTextField(placeholder: titlePlaceholder)
    
    private lazy var tfLink: DTTextField = createTextField(placeholder: linkPlaceholder)

    override func applyTheme() {
        super.applyTheme()

        let themeBlue = Theme.isDarkThemeEnabled ? UIColor(rgbHex: 0x82C1FC) : UIColor.ows_themeBlue
        navigationItem.leftBarButtonItem?.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 17), .foregroundColor: themeBlue], for: .normal)
        navigationItem.leftBarButtonItem?.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 17), .foregroundColor: themeBlue], for: .highlighted)
        navigationItem.rightBarButtonItem?.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 17, weight: .medium), .foregroundColor: themeBlue], for: .normal)
        navigationItem.rightBarButtonItem?.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 17, weight: .medium), .foregroundColor: themeBlue], for: .highlighted)
        
        lbTitle.textColor = Theme.primaryTextColor
        lbLink.textColor = Theme.primaryTextColor
        tfTitle.layer.borderColor = Theme.hairlineColor.cgColor
        tfLink.layer.borderColor = Theme.hairlineColor.cgColor
        tfTitle.attributedPlaceholder = NSAttributedString(string: titlePlaceholder, attributes: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: Theme.thirdTextAndIconColor])
        tfLink.attributedPlaceholder = NSAttributedString(string: linkPlaceholder, attributes: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: Theme.thirdTextAndIconColor])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    func setupUI() {
        
        navigationItem.title = "Add file"
        let cancelItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancelItemAction))
        navigationItem.leftBarButtonItem = cancelItem
        
        let saveItem = UIBarButtonItem(title: "Save", style: .plain, target: self, action: #selector(saveItemAction))
        navigationItem.rightBarButtonItem = saveItem

        if (!file.name.isEmpty) {
            tfTitle.text = file.name
        }
        if (!file.link.isEmpty) {
            tfLink.text = file.link
        }
        
        view.addSubview(lbTitle)
        view.addSubview(tfTitle)
        view.addSubview(lbLink)
        view.addSubview(tfLink)
        
        lbTitle.autoPinEdge(toSuperviewEdge: .top, withInset: 10)
        lbTitle.autoPinEdge(toSuperviewEdge: .leading, withInset: 16)
        
        tfTitle.autoPinEdge(.leading, to: .leading, of: lbTitle)
        tfTitle.autoPinEdge(toSuperviewEdge: .trailing, withInset: 16)
        tfTitle.autoPinEdge(.top, to: .bottom, of: lbTitle, withOffset: 8)
        tfTitle.autoSetDimension(.height, toSize: 40)
        
        lbLink.autoPinEdge(.leading, to: .leading, of: lbTitle)
        lbLink.autoPinEdge(.top, to: .bottom, of: tfTitle, withOffset: 24)

        tfLink.autoPinEdge(.leading, to: .leading, of: lbTitle)
        tfLink.autoPinEdge(toSuperviewEdge: .trailing, withInset: 16)
        tfLink.autoPinEdge(.top, to: .bottom, of: lbLink, withOffset: 8)
        tfLink.autoSetDimension(.height, toSize: 40)

        applyTheme()
    }
    
    @objc
    func cancelItemAction() {
        dismiss(animated: true)
    }
    
    @objc
    func saveItemAction() {
        guard let updateFileHandler = updateFileHandler else {
            return
        }
        
        guard let fileLink = tfLink.text, fileLink.stripped.isEmpty == false else {
            return
        }
        
//        guard let url = URL(string: fileLink.stripped.lowercased()), UIApplication.shared.canOpenURL(url) == true else {
//            DTToastHelper.show(withInfo: "invalid link")
//            return
//        }
        
        guard let fileName = tfTitle.text, fileName.stripped.isEmpty == false else {
            return
        }
    
        file.name = fileName
        file.link = fileLink
        updateFileHandler(file)
        dismiss(animated: true)
    }
    
    func createLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 14)
        label.textAlignment = .left
        label.textColor = Theme.primaryTextColor

        return label
    }

    func createTextField(placeholder: String) -> DTTextField {
        let textField = DTTextField()
        textField.delegate = self
        textField.clearButtonMode = .always
        textField.returnKeyType = .done
        textField.enablesReturnKeyAutomatically = true
        textField.font = UIFont.systemFont(ofSize: 14)
        textField.attributedPlaceholder = NSAttributedString(string: placeholder, attributes: [.font: UIFont.systemFont(ofSize: 14), .foregroundColor: Theme.thirdTextAndIconColor])
        textField.layer.masksToBounds = true
        textField.layer.cornerRadius = 4
        textField.layer.borderWidth = 1
        
        return textField
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        view.endEditing(true)
    }
    
}

extension DTAddFileController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        textField.endEditing(true)
        return true
    }
}
