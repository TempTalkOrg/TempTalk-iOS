//
//  FullScreenInputViewController.swift
//  Difft
//
//  Created by Kris.s on 2025/3/28.
//  Copyright © 2025 Difft. All rights reserved.
//

@objc protocol FullScreenInputViewDelegate: AnyObject {

    func fullScreenConfideButtonPressed()
        
    func fullScreenCollapseButtonPressed()
    
}

class FullScreenInputViewController: OWSViewController {
    
    public weak var delegate: FullScreenInputViewDelegate?
    
    var text: String = ""
    var onTextUpdated: ((String) -> Void)?
    var thread: TSThread?
    
    private var keyboardHeight: CGFloat = 0
    
    private lazy var textView: UITextView = {
        let textView = UITextView()
        textView.font = .preferredFont(forTextStyle: .body)
        return textView
    }()
    
    private lazy var collapseButton: UIButton = {
        let button = UIButton(type: .custom)
        button.tintColor = Theme.primaryIconColor
        button.addTarget(self, action: #selector(collapseButtonPressed), for: .touchUpInside)
        button.setImage(UIImage(named: "input_collapse"), for: .normal)
        return button
    }()
    
    private lazy var confideButton: UIButton = {
        let button = UIButton(type: .custom)
        button.tintColor = Theme.primaryIconColor
        button.addTarget(self, action: #selector(confideButtonPressed), for: .touchUpInside)
        button.setImage(UIImage(named: "input_attachment_confide"), for: .normal)
        button.setImage(UIImage(named: "input_attachment_confide_select"), for: .selected)
                    
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        setupViews()
        
        setupObservers()
        
        textView.becomeFirstResponder()
        
    }
    
    private func setupViews() {
        view.backgroundColor = textView.backgroundColor
        view.addSubview(collapseButton)
        collapseButton.snp.makeConstraints { make in
            make.top.left.equalToSuperview()
            make.size.equalTo(CGSize(square: 56))
        }
        
        view.addSubview(confideButton)
        confideButton.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.right.equalToSuperview()
            make.size.equalTo(CGSize(square: 56))
        }
        
        checkConfideStatus()
        
        textView.text = text
        view.addSubview(textView)
        textView.snp.makeConstraints { make in
            make.top.equalTo(collapseButton.snp.bottom)
            make.left.equalToSuperview().offset(16)
            make.right.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-16)
        }
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(conversationSettingDidChange),
            name: .DTConversationDidChange,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            keyboardHeight = keyboardFrame.height
            adjustTextViewForKeyboard()
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        keyboardHeight = 0
        adjustTextViewForKeyboard()
    }
    
    private func adjustTextViewForKeyboard() {
        textView.snp.updateConstraints { make in
            make.bottom.equalToSuperview().offset(-keyboardHeight - 16) // 距离底部 16，避免遮挡
        }
        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded() // 动画更新布局
        }
    }
    
    
    
    @objc func conversationSettingDidChange(_ notification: Notification) {
        
        guard let thread else { return }
        
        databaseStorage.asyncRead { transaction in
            thread.anyReload(transaction: transaction)
        } completion: {
            self.checkConfideStatus()
        }
    }
    
    func checkConfideStatus() {
        guard let thread else { return }
        
        if let conversationEntity = thread.conversationEntity, conversationEntity.confidentialMode == TSMessageModeType.confidential {
            self.confideButton.isSelected = true
        } else {
            self.confideButton.isSelected = false
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func collapseButtonPressed() {
        onTextUpdated?(textView.text)
        dismiss(animated: true)
        delegate?.fullScreenCollapseButtonPressed()
    }
    
    @objc
    private func confideButtonPressed() {
        delegate?.fullScreenConfideButtonPressed()
    }
    
}
