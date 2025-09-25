//
//  DTAddConditionsController.swift
//  Signal
//
//  Created by Ethan on 2022/7/18.
//  Copyright © 2022 Difft. All rights reserved.
//

import UIKit
import TTMessaging
import TTServiceKit

@objcMembers
class DTAddConditionsController: OWSViewController {
    
    let keywordsMinLength = 2
    let KeywordsMaxLength = 64
    
    @IBOutlet weak var lbKeywords: UILabel!
    @IBOutlet weak var lbTextLength: UILabel!
    @IBOutlet weak var lbPlaceholder: UILabel!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var backgroundView: UIView!
    
    var lastKeywords: String?
    var keywords: String?
    var saveItem: UIBarButtonItem!
    
    var saveKeywordsHandler: ( (String) -> Void )?

    override func applyTheme() {
        super.applyTheme()
        let color = Theme.isDarkThemeEnabled ? UIColor(rgbHex: 0x312F34) : UIColor(rgbHex: 0xF3F1F4)
        backgroundView.backgroundColor = color
        textView.backgroundColor = color
        lbPlaceholder.textColor = Theme.placeholderColor
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let lastKeywords = lastKeywords else {
            return
        }
        textView.text = lastKeywords
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        textView.becomeFirstResponder()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = Localized("CHAT_FOLDER_ADD_CONDITIONS_VC_TITLE", comment: "")
        
        saveItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(saveKeywordsAction))
        saveItem.isEnabled = false
        navigationItem.rightBarButtonItem = saveItem
        
        applyTheme()
        lbKeywords.text = Localized("CHAT_FOLDER_KEYWORDS", comment: "")
        lbPlaceholder.text = String(format: Localized("CHAT_FOLDER_ADD_CONDITIONS_PLACEHOLDER", comment: ""), keywordsMinLength, KeywordsMaxLength)
        textView.textContainerInset = .init(margin: 10)
        lbPlaceholder.isHidden = !lastKeywords.isEmptyOrNil
        
        guard let lastKeywords = lastKeywords else {
            return
        }
        guard !lastKeywords.isEmpty else {
            return
        }
        updateTextLengthLimit(lastKeywords)
    }
    
    @objc
    func saveKeywordsAction() {
        
        guard let keywords = keywords else {
            return
        }
        saveKeywordsHandler?(keywords)
        navigationController?.popViewController(animated: true)
    }
    
    func updateTextLengthLimit(_ keywords: String) {
        lbTextLength.text = "\(keywords.count)/\(KeywordsMaxLength)"
        lbTextLength.textColor = keywords.count > KeywordsMaxLength ? .red : .lightGray
        if let lastKeywords = lastKeywords {
            saveItem.isEnabled = keywords.count > keywordsMinLength - 1 && keywords.count < KeywordsMaxLength + 1 && lastKeywords != keywords
        } else {
            saveItem.isEnabled = keywords.count > keywordsMinLength - 1 && keywords.count < KeywordsMaxLength + 1
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
}

extension DTAddConditionsController: UITextViewDelegate {
    
    func textViewDidChange(_ textView: UITextView) {
        
        let finalKeywords = textView.text.stripped
        keywords = finalKeywords
        lbPlaceholder.isHidden = textView.text.count > 0
        updateTextLengthLimit(finalKeywords)
    }
}
