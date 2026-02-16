//
//  DTForwardPreviewViewController.swift
//  Wea
//
//  Created by Ethan on 2021/11/16.
//

import UIKit
import TTMessaging

let screenHeight = UIScreen.main.bounds.size.height
let screenWidth = UIScreen.main.bounds.size.width
let avatarGridViewWidth = Int(UIScreen.main.bounds.size.width * 3/4 - 44)
/// avatar margin
let avatarMargin = 8
/// avatar number in one row
let numberOfOneRow = 5

@objcMembers
class DTForwardPreviewViewController: OWSViewController {

    private var threads: [TSThread]?
    var contactsManager: OWSContactsManager?
    weak var delegate: DTForwardPreviewDelegate?

    @IBOutlet weak var previewView: UIView?
    @IBOutlet weak var btnSend: UIButton?
    @IBOutlet weak var btnCancel: UIButton?
    @IBOutlet weak var tfLeaveMessage: UITextField?
    @IBOutlet weak var lbSendTo: UILabel?
    @IBOutlet weak var lbMessagePreview: UILabel?
    @IBOutlet weak var avatarGridView: UICollectionView?
    @IBOutlet var sepLine: [UIView]?

    @IBOutlet weak var previewOffsetY: NSLayoutConstraint?
    @IBOutlet weak var collectionViewHeight: NSLayoutConstraint?

    deinit {
        self.avatarGridView?.removeObserver(self, forKeyPath: "contentSize")
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        owsAssertDebug(delegate != nil)
        if let delegate = delegate, delegate.responds(to: #selector(DTForwardPreviewDelegate.getThreadsToForwarding)) {
            threads = delegate.getThreadsToForwarding()
        }
        guard let threads = threads, threads.count > 0 else {
            owsFailDebug("No threads to forward")
            return
        }

        let basePointSize = UIFont.ows_dynamicTypeBody.pointSize;
        self.lbMessagePreview?.font = .ows_regularFont(withSize: basePointSize - 3)
        self.tfLeaveMessage?.font = .ows_regularFont(withSize: basePointSize - 3)
        let highlightedBackgroundImage = UIImage(color: UIColor(white: 0, alpha: 0.1))
        btnCancel?.setTitle(Localized("TXT_CANCEL_TITLE", comment: ""), for: .normal)
        btnCancel?.setBackgroundImage(highlightedBackgroundImage, for: .highlighted)
        var btnSentTitle = Localized("SEND_BUTTON_TITLE", comment: "")
        if threads.count > 1 {
            btnSentTitle = btnSentTitle + "(\(threads.count))"
        }
        btnSend?.setTitle(btnSentTitle, for: .normal)
        btnSend?.setBackgroundImage(highlightedBackgroundImage, for: .highlighted)

        self.tfLeaveMessage?.placeholder = Localized("FORWARD_MESSAGE_LEAVE_MESSAGE", comment: "")
        let leftView = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: 34))
        self.tfLeaveMessage?.leftViewMode = .always
        self.tfLeaveMessage?.rightViewMode = .always
        self.tfLeaveMessage?.leftView = leftView
        self.tfLeaveMessage?.rightView = leftView

        let avatarWidth = Int((avatarGridViewWidth - avatarMargin * (numberOfOneRow - 1)) / numberOfOneRow)
        let layout = UICollectionViewFlowLayout()
        if threads.count > 1 {
            self.lbSendTo?.text = Localized("FORWARD_MESSAGE_SEND_TO_MULTI", comment: "")
            layout.itemSize = CGSize(width: avatarWidth, height: avatarWidth)
            layout.minimumLineSpacing = 8
            layout.minimumInteritemSpacing = 8
            self.avatarGridView?.collectionViewLayout = layout
            self.avatarGridView?.register(DTForwardPreviewMultiCell.self, forCellWithReuseIdentifier: DTForwardPreviewMultiCell.reuseId())
        } else {
            self.lbSendTo?.text = Localized("FORWARD_MESSAGE_SEND_TO_SINGLE", comment: "")
            layout.itemSize = CGSize(width: avatarGridViewWidth, height: avatarWidth)
            layout.sectionInset = .zero
            self.avatarGridView?.collectionViewLayout = layout
            self.avatarGridView?.register(DTForwardPreviewSingleCell.self, forCellWithReuseIdentifier: DTForwardPreviewSingleCell.reuseId())
        }
        self.avatarGridView?.addObserver(self, forKeyPath: "contentSize", options: .new, context: nil)
        
        guard let delegate = self.delegate else {
            self.dismiss(animated: false)
            return
        }
        
        if delegate.responds(to: #selector(DTForwardPreviewDelegate.overviewOfMessage(for:))) {
            self.lbMessagePreview?.text = delegate.overviewOfMessage(for: self)
        } else {
            self.lbMessagePreview?.text = "[message]"
        }
        
        self.autoPinPreviewViewToKeyboard()
    
        applyTheme()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIView.animate(withDuration: 0.25) {
            self.view.backgroundColor = UIColor(white: 0, alpha: 0.3)
        }
        
    }
    
    override func applyTheme() {

        lbSendTo?.textColor = Theme.tprimaryColor
        previewView?.backgroundColor = Theme.bg2Color
        btnCancel?.setTitleColor(Theme.tprimaryColor, for: .normal)
        tfLeaveMessage?.backgroundColor = Theme.bg1Color;
        tfLeaveMessage?.keyboardAppearance = Theme.keyboardAppearance
        sepLine?.forEach { line in
            line.backgroundColor = Theme.lineColor
        }

        avatarGridView?.reloadData()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        if keyPath == "contentSize" {
            guard let sizeValue = change?[.newKey] as? NSValue else { return }
            self.collectionViewHeight?.constant = sizeValue.cgSizeValue.height
            let screenHeight = UIScreen.main.bounds.height
            self.previewOffsetY?.constant = (screenHeight - (self.previewView?.height ?? 0)) / 2
        }
    }
    
    override var canBecomeFirstResponder: Bool {
        return true
    }
        
    override func becomeFirstResponder() -> Bool {
        return super.becomeFirstResponder()
    }
        
    override func resignFirstResponder() -> Bool {
        return super.resignFirstResponder()
    }

    @IBAction func btnSendAction(_ sender: Any) {
        guard let delegate = self.delegate else {
            self.dismiss(animated: false)
            return
        }
        
        if delegate.responds(to: #selector(DTForwardPreviewDelegate.previewView(_:sendLeaveMessage:))) {
            delegate.previewView(self, sendLeaveMessage: self.tfLeaveMessage?.text)
        }
    }
    
    @IBAction func btnCancelAction(_ sender: Any) {

        self.tfLeaveMessage?.resignFirstResponder()
        UIView.animate(withDuration: 0.25) {
            self.view.backgroundColor = UIColor(white: 0, alpha: 0)
            self.previewView?.alpha = 0
        } completion: {_ in
            self.dismiss(animated: false, completion: nil)
        }
    }
    
    @IBAction func tapGestureAction(_ sender: UITapGestureRecognizer) {

        if let previewView = self.previewView, previewView.frame.contains(sender.location(in: self.view)) {
            return
        }
        self.tfLeaveMessage?.resignFirstResponder()
    }
}

@objc protocol DTForwardPreviewDelegate: NSObjectProtocol {
    
    func getThreadsToForwarding() -> [TSThread]
    
    func previewView(_ previewView: DTForwardPreviewViewController, sendLeaveMessage leaveMessage: String?)
    
    func overviewOfMessage(for previewView: DTForwardPreviewViewController) -> String
    
}

extension DTForwardPreviewViewController: UICollectionViewDelegate, UICollectionViewDataSource {
   
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        self.threads?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

        guard let threads = self.threads else {
            return UICollectionViewCell()
        }

        if (threads.count > 1) {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DTForwardPreviewMultiCell.reuseId(), for: indexPath) as! DTForwardPreviewMultiCell
            cell.setAvatarImage(thread: threads[indexPath.item])

            return cell
        }

        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DTForwardPreviewSingleCell.reuseId(), for: indexPath) as! DTForwardPreviewSingleCell
        cell.setAvatarImage(thread: threads[indexPath.item])

        return cell
    }
}

extension DTForwardPreviewViewController {
    
    private func autoPinPreviewViewToKeyboard() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardNotification(noti:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardNotification(noti:)), name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardNotification(noti:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardNotification(noti:)), name: UIResponder.keyboardDidHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardNotification(noti:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleKeyboardNotification(noti:)), name: UIResponder.keyboardDidChangeFrameNotification, object: nil)
    }
    
    @objc func handleKeyboardNotification(noti: Notification) {
        AssertIsOnMainThread()

        guard let keyboardEndFrameValue = noti.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardEndFrame = keyboardEndFrameValue.cgRectValue

        if screenHeight - keyboardEndFrame.origin.y > (screenHeight - (self.previewView?.height ?? 0)) / 2 {
            self.previewOffsetY?.constant = keyboardEndFrame.size.height + 20
        } else {
            self.previewOffsetY?.constant = (screenHeight - (self.previewView?.height ?? 0)) / 2
        }

        self.view.layoutIfNeeded()
    }
}

class DTForwardPreviewMultiCell: UICollectionViewCell {
    
    var avatarView: AvatarImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.avatarView = AvatarImageView()
        self.contentView.addSubview(self.avatarView)
        self.avatarView.autoPinEdgesToSuperviewEdges()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setAvatarImage(thread: TSThread, contactsManager: OWSContactsManager = Environment.shared.contactsManager) {
        
        if thread is TSContactThread {
            if thread.contactIdentifier() == TSAccountManager.sharedInstance().localNumber() {
                self.avatarView.self.dt_setImage(with: nil, placeholderImage: UIImage.init(named: "icon_note_to_self"))
            } else {
                self.avatarView.setImageWithRecipientId(thread.contactIdentifier())
            }
        } else {
            guard let groupThread = thread as? TSGroupThread else {
                owsFailDebug("Expected TSGroupThread but got different type")
                return
            }
            let avatarWidth = Int((avatarGridViewWidth - avatarMargin * (numberOfOneRow - 1)) / numberOfOneRow)
            self.avatarView.setImageWith(groupThread, diameter: UInt(avatarWidth), contactsManager: contactsManager)
        }
    }
    
    class func reuseId() -> String {
        return "DTForwardPreviewMultiCell"
    }
    
}

class DTForwardPreviewSingleCell: UICollectionViewCell {
    
    var avatarView: AvatarImageView!
    var lbName: UILabel!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.avatarView = AvatarImageView()
        self.contentView.addSubview(self.avatarView)
        
        self.avatarView.autoPinEdge(toSuperviewEdge: .leading)
        self.avatarView.autoPinEdge(toSuperviewEdge: .top)
        self.avatarView.autoPinEdge(toSuperviewEdge: .bottom)
        
        self.lbName = UILabel()
        self.lbName.font = .ows_dynamicTypeBody2
        self.lbName.lineBreakMode = .byTruncatingMiddle
        self.lbName.textColor = Theme.tprimaryColor
        self.contentView.addSubview(self.lbName)
        
        self.lbName.autoPinEdge(.leading, to: .trailing, of: self.avatarView, withOffset: 10)
        self.lbName.autoVCenterInSuperview()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setAvatarImage(thread: TSThread, contactsManager: OWSContactsManager = Environment.shared.contactsManager) {
        
        if thread is TSContactThread {
            if thread.contactIdentifier() == TSAccountManager.sharedInstance().localNumber() {
                self.avatarView.dt_setImage(with: nil, placeholderImage: UIImage.init(named: "icon_note_to_self"))
                self.lbName.text = MessageStrings.noteToSelf()
            } else {
                self.avatarView.setImageWithRecipientId(thread.contactIdentifier())
                self.databaseStorage.read { transaction in
                    self.lbName.text = thread.name(with: transaction)
                }
            }
        } else {
            var groupName: String
            let groupMemberCount = "(\(thread.recipientIdentifiers.count + 1))"
            let avatarWidth = Int((avatarGridViewWidth - avatarMargin * (numberOfOneRow - 1)) / numberOfOneRow)
            self.avatarView.image = OWSAvatarBuilder.buildImage(thread: thread, diameter: UInt(avatarWidth), contactsManager: contactsManager)
            if thread.name(with: nil).count == 0 {
                groupName = MessageStrings.newGroupDefaultTitle()
            } else {
                groupName = thread.name(with: nil)
            }
            let totalName = groupName + groupMemberCount
            let attributeName = NSMutableAttributedString(string: totalName)
            attributeName.addAttribute(.foregroundColor, value: UIColor.ows_gray40, range: NSMakeRange(groupName.utf16.count, groupMemberCount.count))
            self.lbName.attributedText = attributeName
        }
    }
    
    class func reuseId() -> String {
        return "DTForwardPreviewSingleCell"
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.lbName.textColor = Theme.tprimaryColor
    }
}

