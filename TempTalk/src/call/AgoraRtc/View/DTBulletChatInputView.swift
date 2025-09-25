//
//  DTBulletChatInputView.swift
//  Signal
//
//  Created by Ethan on 2022/8/4.
//  Copyright © 2022 Difft. All rights reserved.
//

import UIKit
import TTMessaging

@objc
enum DTMeetingBottomOrientation: Int {
    case portrait = 0, landscape
}

@objcMembers
class DTBulletChatInputView: UIView {
    
    let kInputMaxLength = 500
    
    @objc weak var delegate: DTBulletChatInputDelegate?
    var message: String?
    var textViewHeightConstraint: NSLayoutConstraint!

    @objc lazy var textView: UITextView = {
        let textView = UITextView()
        textView.textColor = .white
        textView.tintColor = .white
        textView.font = .systemFont(ofSize: 15, weight: .medium)
        textView.backgroundColor = UIColor(rgbHex: 0x1E2329)
        textView.showsHorizontalScrollIndicator = false
        textView.textContainerInset = .zero
        textView.returnKeyType = .send
        textView.enablesReturnKeyAutomatically = true
        textView.delegate = self
        
        return textView
    }()
    
    lazy var lbPlaceholder: UILabel = {
        let lbPlaceholder = UILabel()
        lbPlaceholder.text = "Message"
        lbPlaceholder.backgroundColor = .clear
        lbPlaceholder.textColor = UIColor(rgbHex: 0x5E6673)
        lbPlaceholder.font = .systemFont(ofSize: 15.0, weight: .medium)
        
        return lbPlaceholder
    }()
    
    lazy var chatIcon: UIImageView = {
        let chatIcon = UIImageView(image: UIImage(named: "ic_meeting_chat2"))
        
        return chatIcon
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        backgroundColor = UIColor(rgbHex: 0x1E2329)
        addKeyboardFrameNotifination()
    }
    
    convenience init(orientation: DTMeetingBottomOrientation) {
        self.init(frame: .zero)
        
        setupUI(orientation)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc
    func clearText() {
        
        textView.text = nil
        message = nil
        lbPlaceholder.isHidden = false
        
        let lineHeight = UIFont.systemFont(ofSize: 15).pointSize
        if textViewHeightConstraint.constant == lineHeight {
            return
        }
        NSLayoutConstraint.deactivate([textViewHeightConstraint])
        textViewHeightConstraint = textView.autoSetDimension(.height, toSize: lineHeight)
    }
      
    @discardableResult
    override func becomeFirstResponder() -> Bool {
        return textView.becomeFirstResponder()
//        return super.becomeFirstResponder()
    }
      
    @discardableResult
    override func resignFirstResponder() -> Bool {
        return textView.resignFirstResponder()
//        return super.resignFirstResponder()
    }
    
    override var isFirstResponder: Bool {
        return textView.isFirstResponder
    }

    func setupUI(_ orientation: DTMeetingBottomOrientation) {
        
        addSubview(chatIcon)
        addSubview(textView)
        addSubview(lbPlaceholder)
        
        chatIcon.autoAlignAxis(toSuperviewAxis: .horizontal)
        if orientation == .portrait {
            chatIcon.autoPinEdge(toSuperviewEdge: .leading, withInset: 16)
        } else {
            chatIcon.autoPinEdge(toSuperviewSafeArea: .leading, withInset: 10)
        }
        
        let lineHeight = UIFont.systemFont(ofSize: 15).pointSize
        textViewHeightConstraint = textView.autoSetDimension(.height, toSize: lineHeight)
        textView.autoAlignAxis(toSuperviewAxis: .horizontal)
        textView.autoPinEdge(.leading, to: .trailing, of: chatIcon, withOffset: 10)
        textView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 16)
   
        lbPlaceholder.autoPinEdge(.leading, to: .leading, of: textView, withOffset: 7)
        lbPlaceholder.autoAlignAxis(toSuperviewAxis: .horizontal)
    }
    
    private func addKeyboardFrameNotifination() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardNotification(_:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillDismiss(_:)), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc private func handleKeyboardNotification(_ notification: Notification) {
        AssertIsOnMainThread()
        
        guard let userInfo = notification.userInfo,
              let beginFrame = userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? CGRect,
              var endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
              let rawAnimationCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int,
              let animationCurve = UIView.AnimationCurve(rawValue: rawAnimationCurve) else {
            return owsFailDebug("keyboard notification missing expected userInfo properties")
        }
        
        // We only want to do an animated presentation if either a) the height changed or b) the view is
        // starting from off the bottom of the screen (a full presentation). This provides the best experience
        // when canceling an interactive dismissal or changing orientations.
        guard beginFrame.height != endFrame.height || beginFrame.minY == UIScreen.main.bounds.height else { return }
        
        guard let keyboardWindow = UIApplication.shared.windows.last else {
            return
        }
        guard let targetVC = keyboardWindow.rootViewController else {
            return
        }
        let targetView = targetVC.view.findSubview("UIInputSetHostView")
        let tmpSize = CGSize(width: endFrame.width, height: endFrame.height > 0 ? endFrame.height : targetView.height)
        endFrame.size = tmpSize

        guard let delegate = delegate else {
            return
        }
        guard delegate.responds(to: #selector(DTBulletChatInputDelegate.updateKeyboardFrame(_:animationDuration:animationCurve:))) else {
            return
        }
        
        delegate.updateKeyboardFrame(endFrame, animationDuration: animationDuration, animationCurve: animationCurve)
    }
    
    @objc private func keyboardWillDismiss(_ notification: Notification) {
        alpha = 0
        guard let userInfo = notification.userInfo,
              var endFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let animationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
              let rawAnimationCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int,
              let animationCurve = UIView.AnimationCurve(rawValue: rawAnimationCurve) else {
            return owsFailDebug("keyboard notification missing expected userInfo properties")
        }
        
        guard let delegate = delegate else {
            return
        }
        guard delegate.responds(to: #selector(DTBulletChatInputDelegate.updateKeyboardFrame(_:animationDuration:animationCurve:))) else {
            return
        }
        
        endFrame.size.height = 0 // 横屏状态下需要让自己归位
                
        delegate.updateKeyboardFrame(endFrame, animationDuration: animationDuration, animationCurve: animationCurve)
    }
    
}

extension DTBulletChatInputView: UITextViewDelegate {
    
    func textViewDidChange(_ textView: UITextView) {
        
        guard let origionMessage = textView.text else {
            return
        }
        var finalMessage = textView.text.stripped
        lbPlaceholder.isHidden = textView.text.count > 0
        
        if origionMessage.count > kInputMaxLength {
            let subString = origionMessage.prefix(kInputMaxLength)
            finalMessage = String(subString).stripped
            textView.text = finalMessage
        }
        
        message = finalMessage
        
        var currentHeight = textView.sizeThatFits(CGSize(width: textView.width, height: .greatestFiniteMagnitude)).height
        currentHeight = min(currentHeight, 40)
        NSLayoutConstraint.deactivate([textViewHeightConstraint])
        textViewHeightConstraint = textView.autoSetDimension(.height, toSize: currentHeight)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        
        if text == "\n" {
            guard let delegate = delegate else {
                return true
            }
            guard delegate.responds(to: #selector(DTBulletChatInputDelegate.sendBulletChat(_:finalMessage:))) else {
                return true
            }
            guard let message = message else {
                return false
            }
            guard !message.isEmpty else {
                return false
            }
            delegate.sendBulletChat(self, finalMessage: message)
            return false
        }
        
        return true
    }
}

@objc protocol DTBulletChatInputDelegate: NSObjectProtocol {
    
    func sendBulletChat(_ inputView: DTBulletChatInputView, finalMessage: String?)
    
    func updateKeyboardFrame(_ keyboardFrame: CGRect, animationDuration: TimeInterval, animationCurve: UIView.AnimationCurve)
    
}



