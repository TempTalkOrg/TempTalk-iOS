//
//  DTEditContactRemarkViewController.swift
//  TempTalk
//
//  Created by Henry on 2026/04/27.
//  Copyright © 2026 Difft. All rights reserved.
//

import Foundation
import UIKit
import SnapKit
import TTMessaging
import TTServiceKit
import SignalCoreKit

@objc public protocol DTEditContactRemarkViewControllerDelegate: AnyObject {
    func editContactRemarkDidFinish()
}

/// 给联系人设置备注（昵称 + 头像）。仅本端可见，服务端密文存储。
/// 自己（localNumber）不允许进入此页面 —— 改自己的名字/头像应走 `DTEditPersonInfoController`。
@objc public class DTEditContactRemarkViewController: OWSViewController {

    // MARK: - Subviews

    private lazy var avatarImageView: DTAvatarImageView = {
        let imageView = DTAvatarImageView()
        imageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(didClickAvatar))
        imageView.addGestureRecognizer(tap)
        return imageView
    }()

    private lazy var avatarEditButton: ContactRemarkEditAvatarButton = {
        let button = ContactRemarkEditAvatarButton()
        button.onClick = { [weak self] in
            self?.didClickEditAvatarButton()
        }
        return button
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textAlignment = .center
        label.text = Localized("EDIT_CONTACT_REMARK_SUBTITLE",
                               comment: "Subtitle under the edit-contact-remark title.")
        return label
    }()

    private lazy var remarkNameView: ContactRemarkInfoEditingView = {
        let view = ContactRemarkInfoEditingView()
        view.delegate = self
        return view
    }()

    private lazy var avatarViewHelper: AvatarViewHelper = {
        let helper = AvatarViewHelper()
        helper.delegate = self
        return helper
    }()

    // MARK: - State

    private lazy var setConversationApi = DTSetConversationApi()

    @objc public weak var editDelegate: DTEditContactRemarkViewControllerDelegate?

    private let recipientId: String
    private var account: SignalAccount

    private var remarkAvatar: UIImage? {
        didSet {
            avatarImageView.image = remarkAvatar
        }
    }

    // MARK: - Init

    @objc public init(recipientId: String, account: SignalAccount) {
        assert(recipientId != TSAccountManager.sharedInstance().localNumber(),
               "DTEditContactRemarkViewController should never be opened for self.")
        self.recipientId = recipientId
        self.account = account
        super.init()
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupNav()
        setupView()
        applyTheme()
        reloadData()
    }

    private func setupNav() {
        let titleStack = UIStackView()
        titleStack.axis = .vertical
        titleStack.alignment = .center
        titleStack.spacing = 2

        let titleLabel = UILabel()
        titleLabel.text = Localized("CONTACT_EDIT_REMARK", comment: "")
        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = Theme.tprimaryColor
        titleStack.addArrangedSubview(titleLabel)

        subtitleLabel.textColor = Theme.tthirdColor
        titleStack.addArrangedSubview(subtitleLabel)

        navigationItem.titleView = titleStack
    }

    private func setupView() {
        view.addSubview(avatarImageView)
        view.addSubview(avatarEditButton)
        view.addSubview(remarkNameView)

        avatarImageView.snp.makeConstraints { make in
            make.width.height.equalTo(112)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(16)
            make.centerX.equalToSuperview()
        }

        avatarEditButton.snp.makeConstraints { make in
            make.width.height.equalTo(36)
            make.bottom.equalTo(avatarImageView).offset(2)
            make.trailing.equalTo(avatarImageView).offset(2)
        }

        remarkNameView.snp.makeConstraints { make in
            make.top.equalTo(avatarImageView.snp.bottom).offset(24)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.height.equalTo(48)
        }
    }

    public override func applyTheme() {
        super.applyTheme()
        view.backgroundColor = Theme.bgelevateColor
        subtitleLabel.textColor = Theme.tthirdColor
        remarkNameView.applyTheme()
    }

    private func reloadData() {
        let helper = DTConversationSettingHelper.sharedInstance()
        let decryptedRemark = helper.decryptRemark(account.contact?.remark ?? "",
                                                   receptid: recipientId)
        let remarkOnly = (decryptedRemark?.isEmpty == false) ? decryptedRemark : nil

        remarkNameView.configure(
            placeholder: Localized("CONTACT_REMARK", comment: "Remark placeholder."),
            info: remarkOnly,
            canEdit: true
        )

        // 新选头像上传完成前，优先展示本地预览图。
        if let localImage = remarkAvatar {
            avatarImageView.image = localImage
            return
        }

        avatarImageView.setImage(
            signalAccount: account,
            displayName: account.contactFullName(),
            completion: nil
        )
    }

    // MARK: - Actions

    @objc
    private func didClickAvatar() {
        view.endEditing(true)
        avatarViewHelper.showChangeAvatarUI()
    }

    @objc
    private func didClickEditAvatarButton() {
        view.endEditing(true)
        avatarViewHelper.showChangeAvatarUI()
    }
}

// MARK: - InfoEditingViewDelegate

extension DTEditContactRemarkViewController: ContactRemarkInfoEditingViewDelegate {

    fileprivate func infoEditingView(_ view: ContactRemarkInfoEditingView, didSubmit info: String?) {
        guard view === remarkNameView else { return }
        let trimmed = (info ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        submitRemarkName(trimmed)
    }

    private func submitRemarkName(_ remarkName: String) {
        let helper = DTConversationSettingHelper.sharedInstance()
        let aesString: String
        if !remarkName.isEmpty {
            aesString = helper.encryptRemark(remarkName, receptid: recipientId) ?? ""
        } else {
            aesString = ""
        }

        DTToastHelper.showHud(in: view)

        setConversationApi.requestConfigConractRemark(
            withConversationID: recipientId,
            remark: aesString
        ) { [weak self] entity in
            DTToastHelper.hide()
            guard let self else { return }

            self.databaseStorage.asyncWrite { transaction in
                guard let updated = SignalAccount.anyFetch(uniqueId: self.recipientId,
                                                           transaction: transaction) else {
                    return
                }
                let decrypted: String?
                if remarkName.isEmpty {
                    decrypted = ""
                } else {
                    decrypted = helper.decryptRemark(entity.remark,
                                                     receptid: self.recipientId)
                }
                updated.contact?.remark = decrypted ?? ""
                if let contactsManager = Environment.shared.contactsManager {
                    contactsManager.updateSignalAccount(
                        withRecipientId: self.recipientId,
                        withNewSignalAccount: updated,
                        with: transaction
                    )
                }
                self.account = updated

                transaction.addAsyncCompletionOnMain {
                    self.reloadData()
                    self.editDelegate?.editContactRemarkDidFinish()
                }
            }
        } failure: { [weak self] error in
            DTToastHelper.hide()
            DTToastHelper.toast(withText: error.localizedDescription)
            self?.reloadData()
        }
    }
}

// MARK: - AvatarViewHelperDelegate

extension DTEditContactRemarkViewController: AvatarViewHelperDelegate {

    public func avatarActionSheetTitle() -> String {
        ""
    }

    public func avatarDidChange(_ image: UIImage) {
        remarkAvatar = image
        submitRemarkAvatar(image)
    }

    public func fromViewController() -> UIViewController {
        self
    }

    public func hasClearAvatarAction() -> Bool {
        account.contact?.remarkAvatar != nil && !(account.contact?.remarkAvatar?.isEmpty ?? true)
    }

    @objc public func clearAvatarActionLabel() -> String {
        Localized("CONTACT_REMARK_RESTORE_AVATAR",
                  comment: "Label for action that restores the contact's original avatar.")
    }

    @objc public func clearAvatar() {
        clearRemarkAvatar()
    }
}

// MARK: - Remark avatar upload pipeline

extension DTEditContactRemarkViewController {

    fileprivate func submitRemarkAvatar(_ image: UIImage) {
        Logger.info("[Avatar] submit start")
        DTToastHelper.showHud(in: view)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.uploadRemarkAvatar(image)
        }
    }

    private func uploadRemarkAvatar(_ image: UIImage) {
        let targetSize = CGSize(width: 1024, height: 1024)
        let resized = image.size == targetSize ? image : image.resizedImage(toFillPixelSize: targetSize)

        guard let imageData = resized.jpegData(compressionQuality: 0.95) else {
            Logger.error("[Avatar] jpeg encode failed")
            handleAvatarUploadFailure(error: nil)
            return
        }

        let attachmentKey = SSKAES256Key.generateRandom()
        guard let encryptedData = SSKCryptography.encryptAESGCM(with: imageData, key: attachmentKey) else {
            Logger.error("[Avatar] aes encrypt failed")
            handleAvatarUploadFailure(error: nil)
            return
        }

        let fileName = "\(UUID().uuidString).jpg"
        let attachmentStream = TSAttachmentStream(
            contentType: OWSMimeTypeImageJpeg,
            byteCount: UInt64(encryptedData.count),
            sourceFilename: fileName,
            albumMessageId: nil,
            albumId: nil
        )
        guard let dataSource = DataSourceValue.dataSource(with: encryptedData, fileExtension: "jpg"),
              attachmentStream.write(dataSource) else {
            Logger.error("[Avatar] write attachment failed")
            handleAvatarUploadFailure(error: nil)
            return
        }

        let uploadOp = OWSUploadOperation(attachment: attachmentStream)
        uploadOp.syncrunForUploadOnly(
            success: { [weak self] attachmentId, _ in
                guard let self else { return }
                self.handleAttachmentUploaded(attachmentId: attachmentId, attachmentKey: attachmentKey, image: resized)
            },
            failure: { [weak self] error in
                self?.handleAvatarUploadFailure(error: error)
            }
        )
    }

    private func handleAttachmentUploaded(attachmentId: String, attachmentKey: SSKAES256Key, image: UIImage) {
        let avatarDict: [String: String] = [
            "attachmentId": attachmentId,
            "encAlgo": "AESGCM256",
            "encKey": attachmentKey.keyData.base64EncodedString()
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: avatarDict, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            Logger.error("[Avatar] json serialize failed")
            handleAvatarUploadFailure(error: nil)
            return
        }

        preCacheRemarkAvatar(attachmentId: attachmentId, image: image)

        let helper = DTConversationSettingHelper.sharedInstance()
        let aesString = helper.encryptRemark(jsonString, receptid: recipientId) ?? ""

        DispatchQueue.main.async { [weak self] in
            self?.sendRemarkAvatarUpdate(aesString: aesString, localDict: avatarDict as NSDictionary)
        }
    }

    /// 将本地选中的图片预写入 SDWebImage 缓存，key 与 `UIImageView+ContactAvatar`
    /// 的 `placeHolderImageCacherKey:` 一致，这样后续 conversation cell reload
    /// 时能直接命中缓存，无需重新下载。
    private func preCacheRemarkAvatar(attachmentId: String, image: UIImage) {
        guard let baseURL = URL(string: TSConstants.avatarStorageServerURL) else { return }
        let cacheKey = baseURL.appendingPathComponent(attachmentId).absoluteString
        let cache = Environment.shared.contactsManager.sdAvatarCache
        cache.storeImage(toMemory: image, forKey: cacheKey)
        if let jpegData = image.jpegData(compressionQuality: 0.85) {
            cache.storeImageData(toDisk: jpegData, forKey: cacheKey)
        }
    }

    fileprivate func sendRemarkAvatarUpdate(aesString: String, localDict: NSDictionary) {
        setConversationApi.requestConfigContactRemarkAvatar(
            withConversationID: recipientId,
            remarkAvatar: aesString
        ) { [weak self] _ in
            DispatchQueue.main.async {
                DTToastHelper.hide()
                self?.persistRemarkAvatar(localDict)
            }
        } failure: { [weak self] error in
            Logger.error("[Avatar] api failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                DTToastHelper.hide()
                DTToastHelper.toast(withText: error.localizedDescription)
                self?.reloadData()
            }
        }
    }

    private func persistRemarkAvatar(_ dict: NSDictionary) {
        databaseStorage.asyncWrite { [weak self] transaction in
            guard let self else { return }
            guard let updated = SignalAccount.anyFetch(uniqueId: self.recipientId,
                                                       transaction: transaction) else {
                return
            }
            updated.contact?.remarkAvatar = dict as? [AnyHashable: Any]
            if let contactsManager = Environment.shared.contactsManager {
                contactsManager.updateSignalAccount(
                    withRecipientId: self.recipientId,
                    withNewSignalAccount: updated,
                    with: transaction
                )
            }
            self.account = updated

            transaction.addAsyncCompletionOnMain {
                self.reloadData()
                self.editDelegate?.editContactRemarkDidFinish()
            }
        }
    }

    fileprivate func clearRemarkAvatar() {
        DTToastHelper.showHud(in: view)

        setConversationApi.requestConfigContactRemarkAvatar(
            withConversationID: recipientId,
            remarkAvatar: ""
        ) { [weak self] _ in
            DispatchQueue.main.async {
                DTToastHelper.hide()
                self?.persistClearedRemarkAvatar()
            }
        } failure: { [weak self] error in
            Logger.error("[Avatar] clear api failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                DTToastHelper.hide()
                DTToastHelper.toast(withText: error.localizedDescription)
            }
        }
    }

    private func persistClearedRemarkAvatar() {
        remarkAvatar = nil
        databaseStorage.asyncWrite { [weak self] transaction in
            guard let self else { return }
            guard let updated = SignalAccount.anyFetch(uniqueId: self.recipientId,
                                                       transaction: transaction) else {
                return
            }
            updated.contact?.remarkAvatar = nil
            if let contactsManager = Environment.shared.contactsManager {
                contactsManager.updateSignalAccount(
                    withRecipientId: self.recipientId,
                    withNewSignalAccount: updated,
                    with: transaction
                )
            }
            self.account = updated

            transaction.addAsyncCompletionOnMain {
                self.reloadData()
                self.editDelegate?.editContactRemarkDidFinish()
            }
        }
    }

    private func handleAvatarUploadFailure(error: Error?) {
        Logger.error("[Avatar] upload failed: \(error?.localizedDescription ?? "unknown")")
        DispatchQueue.main.async { [weak self] in
            DTToastHelper.hide()
            let message = error?.localizedDescription
                ?? Localized("CONTACT_REMARK_AVATAR_UPLOAD_FAILED",
                             comment: "Toast shown when uploading remark avatar fails.")
            DTToastHelper.toast(withText: message)
            self?.reloadData()
        }
    }
}

// MARK: - Editable info row (copied from DTEditGroupInfoViewController for isolation)

fileprivate protocol ContactRemarkInfoEditingViewDelegate: AnyObject {
    func infoEditingView(_ view: ContactRemarkInfoEditingView, didSubmit info: String?)
}

fileprivate class ContactRemarkInfoEditingView: UIView {

    private lazy var textField: UITextField = {
        let tf = UITextField()
        tf.font = .systemFont(ofSize: 16)
        tf.isEnabled = false
        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tf
    }()

    private lazy var editButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(Localized("BUTTON_EDIT", comment: ""), for: .normal)
        button.addTarget(self, action: #selector(editButtonDidClick), for: .touchUpInside)
        button.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        return button
    }()

    private lazy var submitButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setTitle(Localized("BUTTON_DONE", comment: ""), for: .normal)
        button.addTarget(self, action: #selector(submitButtonDidClick), for: .touchUpInside)
        button.isHidden = true
        return button
    }()

    weak var delegate: ContactRemarkInfoEditingViewDelegate?

    private(set) var isEditingField = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        applyTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        layer.cornerRadius = 8
        layer.masksToBounds = true

        addSubview(textField)
        addSubview(editButton)
        addSubview(submitButton)

        textField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.top.bottom.equalToSuperview()
            make.trailing.equalTo(editButton.snp.leading).offset(-10)
        }

        editButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }

        submitButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }
    }

    func beginEditing() {
        isEditingField = true
        editButton.isHidden = true
        submitButton.isHidden = false

        textField.isEnabled = true
        textField.becomeFirstResponder()
    }

    func endEditingField() {
        isEditingField = false
        editButton.isHidden = false
        submitButton.isHidden = true

        textField.resignFirstResponder()
        textField.isEnabled = false
    }

    func applyTheme() {
        backgroundColor = Theme.bgpopupColor
        textField.textColor = Theme.tprimaryColor
        textField.tintColor = Theme.primaryColor
        editButton.setTitleColor(Theme.tthirdColor, for: .normal)
        submitButton.setTitleColor(Theme.tinfoColor, for: .normal)
    }

    func configure(placeholder: String?, info: String?, canEdit: Bool) {
        if canEdit {
            if !isEditingField {
                editButton.isHidden = false
                submitButton.isHidden = true
                textField.text = info
            }
        } else {
            if isEditingField {
                endEditingField()
            }
            editButton.isHidden = true
            submitButton.isHidden = true
            textField.text = info
        }
        if let placeholder {
            textField.attributedPlaceholder = NSAttributedString(
                string: placeholder,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 16),
                    .foregroundColor: Theme.tdisableColor
                ]
            )
        } else {
            textField.placeholder = nil
        }
    }

    @objc
    private func editButtonDidClick() {
        beginEditing()
    }

    @objc
    private func submitButtonDidClick() {
        endEditingField()
        delegate?.infoEditingView(self, didSubmit: textField.text)
    }
}

// MARK: - Avatar edit overlay button

fileprivate class ContactRemarkEditAvatarButton: UIView {

    private lazy var iconImageView = UIImageView(image: UIImage(named: "edit_avatar_icon"))

    var onClick: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        backgroundColor = .clear
        addSubview(iconImageView)
        iconImageView.snp.makeConstraints { make in
            make.width.height.equalTo(28)
            make.center.equalToSuperview()
        }

        isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tapGesture)
    }

    @objc
    private func didTap() {
        onClick?()
    }
}
