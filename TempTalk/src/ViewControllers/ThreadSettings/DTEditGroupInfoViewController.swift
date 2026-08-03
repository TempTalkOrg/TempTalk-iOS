//
//  DTEditGroupInfoViewController.swift
//  TempTalk
//
//  Created by Henry on 2026/04/23.
//  Copyright © 2026 Difft. All rights reserved.
//

import Foundation
import UIKit
import SnapKit
import TTMessaging
import TTServiceKit
import SignalCoreKit

@objc public protocol DTEditGroupInfoViewControllerDelegate: AnyObject {
    func editGroupInfoDidFinish()
}

@objc public class DTEditGroupInfoViewController: OWSViewController {

    // MARK: - Subviews

    private lazy var avatarImageView: DTAvatarImageView = {
        let imageView = DTAvatarImageView()
        imageView.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didClickAvatar))
        imageView.addGestureRecognizer(tapGesture)
        return imageView
    }()

    private lazy var avatarEditButton: EditAvatarButton = {
        let button = EditAvatarButton()
        button.onClick = { [weak self] in
            self?.didClickEditAvatarButton()
        }
        button.isHidden = true
        return button
    }()

    private lazy var avatarViewHelper: AvatarViewHelper = {
        let helper = AvatarViewHelper()
        helper.delegate = self
        return helper
    }()

    private var photoBrowser: DTImageBrowserView?

    private lazy var groupNameView: InfoEditingView = {
        let infoView = InfoEditingView()
        infoView.delegate = self
        return infoView
    }()

    // MARK: - State

    private lazy var updateGroupInfoApi = DTUpdateGroupInfoAPI()
    private lazy var updateGroupAvatarProcessor = DTGroupAvatarUpdateProcessor(groupThread: self.groupThread)

    @objc public weak var editDelegate: DTEditGroupInfoViewControllerDelegate?

    private var groupThread: TSGroupThread

    private var groupAvatar: UIImage? {
        didSet {
            let image = groupAvatar ?? UIImage(named: "empty-group-avatar")
            avatarImageView.image = image
            if let image {
                photoBrowser?.updateCurrentImage(image)
            }
        }
    }

    private var serverGroupId: String {
        TSGroupThread.transformToServerGroupId(withLocalGroupId: groupThread.groupModel.groupId) ?? ""
    }

    // MARK: - Init

    @objc public init(groupThread: TSGroupThread) {
        self.groupThread = groupThread
        super.init()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        applyTheme()
        reloadData()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(groupCryptoKeyDidArrive(_:)),
            name: DTGroupCryptoConstants.groupCryptoKeyDidArriveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(groupAvatarDidChange(_:)),
            name: .TSGroupThreadAvatarChanged,
            object: nil
        )
    }

    @objc private func groupCryptoKeyDidArrive(_ notification: Notification) {
        guard let gid = notification.userInfo?[DTGroupCryptoConstants.groupCryptoKeyGidKey] as? String,
              !gid.isEmpty,
              gid == groupThread.serverThreadId else {
            return
        }
        // InfoEditingView 按 isEditingField 保留用户输入，直接刷新即可
        reloadData(reloadThread: true)
    }

    @objc private func groupAvatarDidChange(_ notification: Notification) {
        guard let threadId = notification.userInfo?[TSGroupThread_NotificationKey_UniqueId] as? String,
              threadId == groupThread.uniqueId else {
            return
        }
        reloadData(reloadThread: true)
    }

    private func setupView() {
        title = Localized("EDIT_GROUP_DEFAULT_TITLE", comment: "The navbar title for the 'update group' view.")

        view.addSubview(avatarImageView)
        view.addSubview(avatarEditButton)
        view.addSubview(groupNameView)

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

        groupNameView.snp.makeConstraints { make in
            make.top.equalTo(avatarImageView.snp.bottom).offset(24)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.height.equalTo(52)
        }
    }

    public override func applyTheme() {
        super.applyTheme()
        view.backgroundColor = Theme.bgelevateColor
        groupNameView.applyTheme()
    }

    private func reloadData(reloadThread: Bool = false) {
        if reloadThread {
            var newThread: TSGroupThread?
            databaseStorage.read { transaction in
                newThread = TSGroupThread.anyFetchGroupThread(uniqueId: self.groupThread.uniqueId,
                                                              transaction: transaction)
            }
            if let newThread {
                groupThread = newThread
            }
        }

        let groupModel = groupThread.groupModel
        groupAvatar = groupModel.groupImage
        avatarEditButton.isHidden = !canEditAvatar

        let displayName = decryptedGroupName() ?? groupModel.groupName ?? ""
        groupNameView.configure(
            placeholder: Localized("GROUP_SETTING_GROUP_NAME", comment: "Placeholder / label for the group name field."),
            info: displayName,
            canEdit: canEditName
        )
    }

    /// 群名称：所有成员都可编辑
    private var canEditName: Bool {
        return true
    }

    /// 群头像：仅加密群可编辑（全员），非加密群禁止编辑
    private var canEditAvatar: Bool {
        return groupThread.groupModel.isEncryptedGroup
    }

    private func decryptedGroupName() -> String? {
        let groupModel = groupThread.groupModel
        guard groupModel.isEncryptedGroup else {
            return groupModel.groupName
        }
        var result: String?
        databaseStorage.read { transaction in
            let cachedEncryptedName = DTGroupBaseInfoEntity.anyFetch(uniqueId: self.groupThread.serverThreadId, transaction: transaction)?.encryptedName
            result = DTGroupCryptoDisplayHelper.shared.displayGroupName(
                gid: self.groupThread.serverThreadId,
                groupCryptoMode: groupModel.groupCryptoMode,
                encryptedName: cachedEncryptedName,
                originalName: groupModel.groupName,
                transaction: transaction
            )
        }
        return result
    }

    // MARK: - Actions

    @objc
    private func didClickAvatar() {
        view.endEditing(true)
        if canEditAvatar {
            avatarViewHelper.showChangeAvatarUI()
        } else {
            showPhotoBrowser(animated: true)
        }
    }

    @objc
    private func didClickEditAvatarButton() {
        view.endEditing(true)
        avatarViewHelper.showChangeAvatarUI()
    }
}

// MARK: - InfoEditingViewDelegate

extension DTEditGroupInfoViewController: InfoEditingViewDelegate {

    fileprivate func infoEditingView(_ view: InfoEditingView, didSubmit info: String?) {
        guard view === groupNameView else { return }
        let trimmed = info?.ows_stripped() ?? ""
        guard !trimmed.isEmpty else {
            showErrorAlert("RENAME_ERROR_CANNOT_EMPTY")
            return
        }
        let collapsed = trimmed.replacingOccurrences(
            of: "\\s+", with: " ", options: .regularExpression
        ).ows_stripped()
        guard !collapsed.isEmpty else {
            showErrorAlert("RENAME_ERROR_CANNOT_EMPTY")
            return
        }
        updateGroupName(collapsed)
    }

    private func updateGroupName(_ newName: String) {
        let groupModel = groupThread.groupModel
        let serverGid = serverGroupId
        let isEncryptedGroup = groupModel.isEncryptedGroup

        let updateInfo: [String: Any]
        let localEncryptedName: String?
        if isEncryptedGroup {
            var encryptedName: String?
            databaseStorage.read { transaction in
                encryptedName = DTGroupCryptoManager.shared.encryptGroupName(
                    gid: serverGid,
                    plainName: newName,
                    transaction: transaction
                )
            }
            guard let encryptedName else {
                DTToastHelper.toast(
                    withText: Localized("GROUP_CRYPTO_NO_KEY_TOAST", comment: ""),
                    in: view,
                    durationTime: 3,
                    afterDelay: 0.2
                )
                // 缺 R_group，input 还原成当前群名
                reloadData()
                return
            }
            updateInfo = ["encryptedName": encryptedName]
            localEncryptedName = encryptedName
        } else {
            updateInfo = ["name": newName]
            localEncryptedName = nil
        }

        DTToastHelper.show()

        updateGroupInfoApi.sendUpdateGroup(
            withGroupId: serverGid,
            updateInfo: updateInfo
        ) { [weak self] _ in
            DTToastHelper.hide()
            guard let self else { return }

            self.databaseStorage.asyncWrite { transaction in
                var needSendSystemMessage = false
                self.groupThread.anyUpdateGroupThread(transaction: transaction) { instance in
                    needSendSystemMessage = instance.groupModel.groupName != newName
                    instance.groupModel.groupName = newName
                }

                if isEncryptedGroup, let localEncryptedName {
                    DTGroupBaseInfoEntity.syncFields(
                        gid: serverGid,
                        name: newName,
                        encryptedName: localEncryptedName,
                        transaction: transaction
                    )
                }

                if needSendSystemMessage {
                    self.sendGroupNameDidChangeMessage(newName: newName, transaction: transaction)
                }

                transaction.addAsyncCompletionOnMain {
                    self.reloadData(reloadThread: true)
                    self.editDelegate?.editGroupInfoDidFinish()
                }
            }
        } failure: { [weak self] error in
            DTToastHelper.hide()
            DTToastHelper.show(withInfo: error.localizedDescription)
            self?.reloadData(reloadThread: true)
        }
    }

    private func sendGroupNameDidChangeMessage(newName: String, transaction: SDSAnyWriteTransaction) {
        var sourceName: String?
        if let localNumber = TSAccountManager.shared.localNumber(with: transaction) {
            sourceName = TextSecureKitEnv.shared().contactsManager.displayName(
                forPhoneIdentifier: localNumber,
                transaction: transaction
            )
        }

        let customMessage: String
        if let sourceName, !sourceName.isEmpty {
            customMessage = String(
                format: Localized("GROUP_NAME_CHANGED_SYSTEM_MSG", comment: ""),
                sourceName,
                newName
            )
        } else {
            customMessage = String(
                format: Localized("GROUP_TITLE_CHANGED", comment: ""),
                newName
            )
        }

        let infoMessage = TSInfoMessage(
            timestamp: NSDate.ows_millisecondTimeStamp(),
            in: groupThread,
            messageType: .typeGroupUpdate,
            customMessage: customMessage
        )
        infoMessage.isShouldAffectThreadSorting = false
        infoMessage.anyInsert(transaction: transaction)
    }

    private func showErrorAlert(_ msgKey: String) {
        showAlert(
            .alert,
            title: Localized("COMMON_NOTICE_TITLE", ""),
            msg: Localized(msgKey, ""),
            cancelTitle: nil,
            confirmTitle: Localized("MESSAGE_ACTION_DELETE_MESSAGE_OK", ""),
            confirmStyle: .default,
            confirmHandler: nil
        )
    }
}

// MARK: - AvatarViewHelperDelegate

extension DTEditGroupInfoViewController: AvatarViewHelperDelegate {

    public func avatarActionSheetTitle() -> String {
        Localized("NEW_GROUP_ADD_PHOTO_ACTION",
                  comment: "Action Sheet title prompting the user for a group avatar")
    }

    public func avatarDidChange(_ image: UIImage) {
        groupAvatar = image
        updateGroupAvatar(image)
    }

    public func fromViewController() -> UIViewController {
        self
    }

    public func hasClearAvatarAction() -> Bool {
        false
    }

    private func showPhotoBrowser(animated: Bool) {
        let item = DTImageViewModel()
        item.thumbView = avatarImageView
        item.largeImageSize = CGSize(width: 180, height: 180)
        item.receptid = groupThread.serverThreadId
        item.thread = groupThread
        item.image = groupAvatar
        let browser = DTImageBrowserView(groupItems: [item])
        if let window = view.window {
            browser.present(fromImageView: avatarImageView,
                            toContainer: window,
                            animated: animated,
                            completion: nil)
        }
        photoBrowser = browser
    }

    private func updateGroupAvatar(_ image: UIImage) {
        guard canEditAvatar else {
            DTToastHelper.show(withInfo: Localized("GROUP_SETTING_NO_EDIT_AVATAR_PERMISSION", comment: ""))
            return
        }

        guard let data = image.pngData() else {
            Logger.error("Failed to process avatar image")
            return
        }
        guard let dataSource = DataSourceValue.dataSource(with: data, fileExtension: "png") else {
            Logger.error("Failed to create image data source")
            return
        }

        DTToastHelper.show()

        updateGroupAvatarProcessor.update(
            withAttachment: dataSource,
            contentType: OWSMimeTypeImagePng,
            sourceFilename: nil
        ) { [weak self] _ in
            DTToastHelper.hide()
            guard let self else { return }

            self.databaseStorage.asyncWrite { transaction in
                self.groupThread.anyUpdateGroupThread(transaction: transaction) { instance in
                    instance.groupModel.groupImage = image
                }
                self.sendGroupAvatarDidChangeMessage(transaction: transaction)

                transaction.addAsyncCompletionOnMain {
                    self.reloadData(reloadThread: true)
                    self.groupThread.fireAvatarChangedNotification()
                    self.editDelegate?.editGroupInfoDidFinish()
                }
            }
        } failure: { [weak self] error in
            DTToastHelper.hide()
            DTToastHelper.show(withInfo: error.localizedDescription)
            self?.reloadData(reloadThread: true)
        }
    }

    private func sendGroupAvatarDidChangeMessage(transaction: SDSAnyWriteTransaction) {
        let infoMessage = TSInfoMessage(
            timestamp: NSDate.ows_millisecondTimeStamp(),
            in: groupThread,
            messageType: .typeGroupUpdate,
            customMessage: Localized("GROUP_AVATAR_CHANGED", comment: "")
        )
        infoMessage.isShouldAffectThreadSorting = false
        infoMessage.anyInsert(transaction: transaction)
    }
}

// MARK: - Info editing row

fileprivate protocol InfoEditingViewDelegate: AnyObject {
    func infoEditingView(_ view: InfoEditingView, didSubmit info: String?)
}

fileprivate class InfoEditingView: UIView {

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

    weak var delegate: InfoEditingViewDelegate?

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

        if let placeholder = textField.attributedPlaceholder {
            let newPlaceholder = NSMutableAttributedString(attributedString: placeholder)
            newPlaceholder.setAttributes(
                [.foregroundColor: Theme.tdisableColor],
                range: NSRange(location: 0, length: newPlaceholder.length)
            )
            textField.attributedPlaceholder = newPlaceholder
        }
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

// MARK: - Edit avatar button (bottom-right overlay)

fileprivate class EditAvatarButton: UIView {

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
