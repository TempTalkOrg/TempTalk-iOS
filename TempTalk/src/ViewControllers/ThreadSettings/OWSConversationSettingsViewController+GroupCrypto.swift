//
//  OWSConversationSettingsViewController+GroupCrypto.swift
//  TempTalk
//

import UIKit

extension OWSConversationSettingsViewController {

    // MARK: - Upgrade Confirmation Sheet

    @objc func showUpgradeToEncryptedConfirmation() {
        let sheet = ActionSheetController(title: nil, message: nil)

        let headerView = buildEncryptedGroupInfoHeader(
            title: Localized("GROUP_CRYPTO_UPGRADE_TITLE", comment: "Enhance Encryption"),
            body: Localized("GROUP_CRYPTO_UPGRADE_DESC", comment: "Group info will be upgraded from in-transit encryption to end-to-end encryption.")
        )
        sheet.customHeader = headerView

        let upgradeAction = ActionSheetAction(
            title: Localized("GROUP_CRYPTO_UPGRADE_BUTTON", comment: "Turn On"),
            style: .default
        ) { [weak self] _ in
            self?.performUpgradeToEncrypted()
        }
        upgradeAction.titleColor = Theme.tinfoColor
        sheet.addAction(upgradeAction)
        sheet.addAction(OWSActionSheets.cancelAction)
        presentActionSheet(sheet)
    }

    // MARK: - Encrypted Group Info Dialog

    @objc func showEncryptedGroupInfo() {
        let sheet = ActionSheetController(title: nil, message: nil)

        let headerView = buildEncryptedGroupInfoHeader(
            title: Localized("GROUP_CRYPTO_INFO_TITLE", comment: "Encryption Enhanced"),
            body: Localized("GROUP_CRYPTO_INFO_DESC", comment: "Group info has been upgraded from in-transit encryption to end-to-end encryption.")
        )
        sheet.customHeader = headerView

        // Reset entry: owner/admin only, gated by the key-reset switch (independent of the
        // encryption master switch so the entry can be rolled out separately).
        if let groupThread = self.thread as? TSGroupThread {
            let cfg = DTGroupConfig.fetch()
            let resetEnabled = cfg.encryptionKeyResetEnabled
            let isOwnerOrAdmin = groupThread.groupModel.isSelfGroupOwner() || groupThread.groupModel.isSelfGroupModerator()
            if resetEnabled, isOwnerOrAdmin {
                let resetAction = ActionSheetAction(
                    title: Localized("GROUP_CRYPTO_RESET_KEY_ENTRY", comment: "Reset Encryption Key"),
                    style: .default
                ) { [weak self] _ in
                    self?.presentResetCryptoKeyDialog()
                }
                resetAction.titleColor = Theme.tinfoColor
                sheet.addAction(resetAction)
            }
        }

        sheet.addAction(ActionSheetAction(
            title: Localized("GROUP_CRYPTO_INFO_DISMISS", comment: "OK"),
            style: .cancel
        ))
        presentActionSheet(sheet)
    }

    // MARK: - Reset Encryption Key

    private func presentResetCryptoKeyDialog() {
        guard let groupThread = self.thread as? TSGroupThread else { return }
        let gid = groupThread.serverThreadId

        // Always-editable dialog (Android-parity): the owner/admin can change name/avatar regardless
        // of readability. `avatarMissing` only decides how a kept avatar maps to the rotate source.
        let currentName = currentDecryptedGroupName(groupThread: groupThread)
        var avatarMissing = false
        databaseStorage.read { transaction in
            let encryptedAvatar = DTGroupBaseInfoEntity.anyFetch(uniqueId: gid, transaction: transaction)?.encryptedAvatar
            guard let encryptedAvatar, !encryptedAvatar.isEmpty else { return }
            let decrypted = DTGroupCryptoManager.shared.decryptedGroupAvatar(gid: gid,
                                                                             encryptedAvatar: encryptedAvatar,
                                                                             transaction: transaction)
            avatarMissing = (decrypted == nil)
        }

        // Prefill with the group's current image; fall back to the member-initials grid the app shows
        // for image-less groups (parity with NewGroupViewController). nil only for tiny groups.
        // When the current avatar can't be decrypted (no key), ignore any stale cached groupImage and
        // show the generated default instead — a leftover old image would misrepresent the no-key state.
        let prefillAvatar = avatarMissing
            ? defaultMemberGridAvatar(groupThread: groupThread)
            : (groupThread.groupModel.groupImage ?? defaultMemberGridAvatar(groupThread: groupThread))

        let dialog = DTResetGroupCryptoKeyViewController(currentName: currentName,
                                                         prefillAvatar: prefillAvatar) { [weak self] name, avatar, avatarChanged in
            let avatarSource: RotateAvatarSource
            if avatarChanged {
                // User picked a new image (non-nil when avatarChanged is true) → upload it.
                avatarSource = avatar.map { .newImage($0) } ?? .keepCurrent
            } else if !avatarMissing {
                // Current avatar is readable and untouched → reuse it as-is.
                avatarSource = .keepCurrent
            } else {
                // Avatar was unreadable: keeping the default grid uploads it; nothing → drop.
                avatarSource = avatar.map { .newImage($0) } ?? .dropAvatar
            }
            // Dialog already dismissed itself → no page to pop (fromPage: nil).
            self?.performRotateCrypto(resolvedName: name, avatarSource: avatarSource, fromPage: nil)
        }
        dialog.modalPresentationStyle = .overFullScreen
        present(dialog, animated: false)
    }

    /// The name the device can actually decrypt; empty when undecryptable (no key) so the caller
    /// treats it as missing — symmetric with the avatar check. Deliberately bypasses
    /// displayGroupName/groupModel.groupName: a cached plaintext there would mask an undecryptable
    /// name and wrongly hide the name fill-in field.
    private func currentDecryptedGroupName(groupThread: TSGroupThread) -> String {
        let groupModel = groupThread.groupModel
        guard groupModel.isEncryptedGroup else {
            return groupModel.groupName ?? ""
        }
        let gid = groupThread.serverThreadId
        var decrypted: String?
        databaseStorage.read { transaction in
            let cachedEncryptedName = DTGroupBaseInfoEntity.anyFetch(uniqueId: gid, transaction: transaction)?.encryptedName
            decrypted = DTGroupCryptoManager.shared.decryptedGroupName(gid: gid,
                                                                       encryptedName: cachedEncryptedName,
                                                                       transaction: transaction)
        }
        guard let decrypted, !decrypted.isEmpty else { return "" }
        return decrypted
    }

    /// Builds the member-initials grid avatar the app renders for groups without a custom image
    /// (mirrors NewGroupViewController.generateNewGroupAvatar). Returns nil for groups too small to
    /// compose a grid (≤1 member), where the static placeholder is shown instead.
    private func defaultMemberGridAvatar(groupThread: TSGroupThread) -> UIImage? {
        let memberIds = groupThread.groupModel.groupMemberIds as? [String] ?? []
        guard memberIds.count > 1 else { return nil }

        var letters: [TTLetterItem] = []
        // Background is picked from the colors no member used, matching NewGroupViewController.
        var remainingColors = UIColor.ows_conversationThreadColorMap()
        databaseStorage.read { transaction in
            for memberId in memberIds {
                let recipientId = (memberId.lowercased() == "unknown" || memberId.isEmpty) ? "#" : memberId
                let colorName = TSThread.stableConversationColorName(for: recipientId)
                remainingColors.removeValue(forKey: colorName)
                let color = UIColor.ows_conversationColor(colorName: colorName) ?? .gray
                // contactsManagerRef is the protocol type; the raw-name lookup lives on the concrete
                // OWSContactsManager. Fall back to the id if the cast/lookup is unavailable.
                let displayName = (SSKEnvironment.shared.contactsManagerRef as? OWSContactsManager)?
                    .rawDisplayName(forPhoneIdentifier: recipientId, transaction: transaction) ?? recipientId
                letters.append(TTLetterItem(char: displayName, color: color))
            }
        }
        guard letters.count > 1 else { return nil }

        let fallbackPalette = Array(UIColor.ows_conversationThreadColorMap().values)
        let palette = remainingColors.isEmpty ? fallbackPalette : Array(remainingColors.values)
        let bgColor = palette.randomElement() ?? .gray
        return TTGroupAvatarGenerator.generate(with: letters, backgroundColor: bgColor, sizePx: 512)
    }

    private func buildEncryptedGroupInfoHeader(title: String, body: String) -> UIView {
        let container = UIView()
        container.backgroundColor = Theme.bg1Color
        container.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 16, right: 24)

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 12
        container.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewMargins()

        let iconWrapper = UIView()
        let iconView = UIImageView(image: UIImage(named: "group_settings_crypto_Icon"))
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = Theme.isDarkThemeEnabled ? .white : UIColor(rgbHex: 0x5C5E6A)
        iconWrapper.addSubview(iconView)
        iconView.autoSetDimensions(to: CGSize(width: 56, height: 56))
        iconView.autoHCenterInSuperview()
        iconView.autoPinEdge(toSuperviewEdge: .top)
        iconView.autoPinEdge(toSuperviewEdge: .bottom)
        stackView.addArrangedSubview(iconWrapper)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = Theme.tprimaryColor
        titleLabel.textAlignment = .center
        stackView.addArrangedSubview(titleLabel)

        let descLabel = UILabel()
        descLabel.text = body
        descLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        descLabel.textColor = Theme.tsecondaryColor
        descLabel.textAlignment = .center
        descLabel.numberOfLines = 0
        stackView.addArrangedSubview(descLabel)

        return container
    }

    // MARK: - Perform Upgrade

    private func performUpgradeToEncrypted() {
        guard let groupThread = self.thread as? TSGroupThread else {
            Logger.error("[GroupCrypto] performUpgradeToEncrypted: could not resolve group thread")
            DTToastHelper.showInfo(Localized("GROUP_CRYPTO_UPGRADE_FAILED", comment: "Upgrade failed"))
            return
        }
        let groupModel = groupThread.groupModel
        let gid = groupThread.serverThreadId
        let groupName = groupModel.groupName ?? ""
        let memberUids = groupModel.groupMemberIds as? [String] ?? []

        DTToastHelper.show()

        let manager = DTGroupCryptoManager.shared

        var params: EncryptedGroupCreationParams?
        databaseStorage.read { transaction in
            let avatarJson = DTGroupBaseInfoEntity.anyFetch(uniqueId: gid, transaction: transaction)?.avatar
            Logger.info("[GroupCrypto] Upgrade prepare: gid: \(gid), hasAvatar: \(avatarJson?.isEmpty == false)")
            params = manager.prepareUpgradeToEncrypted(gid: gid,
                                                       groupName: groupName,
                                                       avatar: avatarJson,
                                                       memberUids: memberUids,
                                                       transaction: transaction)
        }

        guard let params else {
            DTToastHelper.hide()
            Logger.error("[GroupCrypto] Failed to prepare upgrade params for gid: \(gid)")
            DTToastHelper.showInfo(Localized("GROUP_CRYPTO_UPGRADE_FAILED",
                                                      comment: "Upgrade failed"))
            return
        }

        let request = params.toUpgradeRequest()

        Task { [weak self] in
            do {
                try await DTGroupCryptoAPIImpl().upgradeToEncrypted(groupId: gid, request: request)

                await MainActor.run {
                    self?.databaseStorage.write { transaction in
                        manager.saveRGroupIfNeeded(gid: gid,
                                                   rGroup: params.rGroup,
                                                   transaction: transaction)

                        groupThread.anyUpdateGroupThread(transaction: transaction) { gthread in
                            gthread.groupModel.groupCryptoMode = params.groupCryptoMode
                        }
                        if let baseInfo = DTGroupBaseInfoEntity.anyFetch(uniqueId: gid, transaction: transaction) {
                            baseInfo.anyUpdate(transaction: transaction) { entity in
                                entity.groupCryptoMode = params.groupCryptoMode
                                entity.encryptedName = params.encryptedName
                                entity.encryptedAvatar = params.encryptedAvatar
                            }
                        }

                        let upgradeInfoMessage = TSInfoMessage(timestamp: Date.ows_millisecondTimestamp(),
                                                               in: groupThread,
                                                               messageType: .groupCryptoUpgrade,
                                                               customMessage: Localized("GROUP_CRYPTO_UPGRADE_SYSTEM_MSG"))
                        upgradeInfoMessage.isShouldAffectThreadSorting = true
                        upgradeInfoMessage.anyInsert(transaction: transaction)
                    }

                    DTGroupKeyMessageHandler.shared.sendGroupKeyMessage(thread: groupThread,
                                                                        groupId: groupModel.groupId,
                                                                        rGroup: params.rGroup)

                    DTToastHelper.hide()
                    Logger.info("[GroupCrypto] Upgrade to encrypted succeeded for gid: \(gid)")
                    self?.perform(NSSelectorFromString("updateTableContents"))
                }
            } catch {
                await MainActor.run {
                    DTToastHelper.hide()
                    Logger.error("[GroupCrypto] Upgrade API failed: \(error)")
                    DTToastHelper.showInfo(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Perform Rotate

    /// gids with a rotate currently in flight. Set/cleared only on the main thread (every access below
    /// is on main), so no lock is needed. Blocks a double-tap from firing a second rotate with the same
    /// CAS base — the server would reject it and the user would see a spurious failure toast.
    private static var inFlightRotateGids = Set<String>()

    private func performRotateCrypto(resolvedName: String,
                                     avatarSource: RotateAvatarSource,
                                     fromPage: UIViewController?) {
        guard let groupThread = self.thread as? TSGroupThread else {
            Logger.error("[GroupCrypto] performRotateCrypto: could not resolve group thread")
            DTToastHelper.showInfo(Localized("GROUP_CRYPTO_RESET_FAILED", comment: "Reset failed"))
            return
        }
        let gid = groupThread.serverThreadId

        // Permission may have changed while the dialog/page was open — re-check at submit time.
        var stillAuthorized = false
        databaseStorage.read { transaction in
            let freshThread = TSGroupThread.anyFetchGroupThread(uniqueId: groupThread.uniqueId, transaction: transaction) ?? groupThread
            stillAuthorized = freshThread.groupModel.isSelfGroupOwner() || freshThread.groupModel.isSelfGroupModerator()
        }
        guard stillAuthorized else {
            Logger.info("[GroupCrypto] INITIATOR rotate blocked: no permission gid: \(gid)")
            DTToastHelper.showInfo(Localized("GROUP_CRYPTO_RESET_NO_PERMISSION", comment: "Only owners/admins can reset"))
            fromPage?.navigationController?.popViewController(animated: true)
            return
        }

        // Reject a re-entrant rotate for the same group (e.g. double-tap) — cleared on every terminal
        // path below and in rotateAndPersist.
        guard !Self.inFlightRotateGids.contains(gid) else {
            Logger.info("[GroupCrypto] Rotate already in flight for gid: \(gid), ignoring duplicate")
            return
        }
        Self.inFlightRotateGids.insert(gid)

        Logger.info("[GroupCrypto] INITIATOR start rotate gid: \(gid)")

        let trimmed = resolvedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let groupName = trimmed.isEmpty ? Localized("NEW_GROUP_DEFAULT_TITLE", comment: "Default group name when unnamed") : trimmed

        DTToastHelper.show()

        switch avatarSource {
        case .newImage(let image):
            // 3.4 avatar fill-in: upload the picked image to obtain its plaintext avatar JSON,
            // then rotate with that JSON (re-encrypted under the new key in prepareRotateCrypto).
            guard let data = image.pngData(),
                  let dataSource = DataSourceValue.dataSource(with: data, fileExtension: "png") else {
                Self.inFlightRotateGids.remove(gid)
                DTToastHelper.hide()
                DTToastHelper.showInfo(Localized("GROUP_CRYPTO_RESET_FAILED", comment: "Reset failed"))
                return
            }
            let processor = DTGroupAvatarUpdateProcessor(groupThread: groupThread)
            processor.uploadAttachment(dataSource,
                                       contentType: OWSMimeTypeImagePng,
                                       sourceFilename: nil) { [weak self] plainAvatarJson in
                DispatchQueue.main.async {
                    Logger.info("[GroupCrypto] INITIATOR avatar uploaded gid: \(gid)")
                    self?.rotateAndPersist(groupThread: groupThread,
                                           gid: gid,
                                           groupName: groupName,
                                           keepCurrentAvatar: false,
                                           avatarJsonOverride: plainAvatarJson,
                                           fromPage: fromPage)
                }
            } failure: { error in
                DispatchQueue.main.async {
                    Self.inFlightRotateGids.remove(gid)
                    DTToastHelper.hide()
                    Logger.error("[GroupCrypto] Avatar upload failed during rotate: \(error)")
                    DTToastHelper.showInfo(Localized("GROUP_CRYPTO_RESET_FAILED", comment: "Reset failed"))
                }
            }
        case .keepCurrent:
            rotateAndPersist(groupThread: groupThread, gid: gid, groupName: groupName,
                             keepCurrentAvatar: true, avatarJsonOverride: nil, fromPage: fromPage)
        case .dropAvatar:
            rotateAndPersist(groupThread: groupThread, gid: gid, groupName: groupName,
                             keepCurrentAvatar: false, avatarJsonOverride: nil, fromPage: fromPage)
        }
    }

    /// Prepares rotate params (re-encrypting name/avatar under the fresh key) and performs the
    /// rotate + local persistence + key broadcast. When `keepCurrentAvatar` is true the currently
    /// decryptable avatar is reused; otherwise `avatarJsonOverride` (nil → no avatar) is used.
    private func rotateAndPersist(groupThread: TSGroupThread,
                                  gid: String,
                                  groupName: String,
                                  keepCurrentAvatar: Bool,
                                  avatarJsonOverride: String?,
                                  fromPage: UIViewController?) {
        let groupModel = groupThread.groupModel
        let memberUids = groupModel.groupMemberIds as? [String] ?? []
        let manager = DTGroupCryptoManager.shared

        var params: EncryptedGroupCreationParams?
        databaseStorage.read { transaction in
            let plainAvatar: String?
            if keepCurrentAvatar {
                // Recover the current avatar with the held key, then re-encrypt under the new key.
                let encryptedAvatar = DTGroupBaseInfoEntity.anyFetch(uniqueId: gid, transaction: transaction)?.encryptedAvatar
                plainAvatar = manager.decryptedGroupAvatar(gid: gid,
                                                           encryptedAvatar: encryptedAvatar,
                                                           transaction: transaction)
            } else {
                plainAvatar = avatarJsonOverride
            }
            params = manager.prepareRotateCrypto(gid: gid,
                                                 groupName: groupName,
                                                 avatar: plainAvatar,
                                                 memberUids: memberUids,
                                                 transaction: transaction)
        }

        guard let params else {
            Self.inFlightRotateGids.remove(gid)
            DTToastHelper.hide()
            Logger.error("[GroupCrypto] Failed to prepare rotate params for gid: \(gid)")
            DTToastHelper.showInfo(Localized("GROUP_CRYPTO_RESET_FAILED", comment: "Reset failed"))
            return
        }

        Task { [weak self] in
            do {
                let baseKeyVersion = try await Self.fetchServerCryptoKeyVersion(gid: gid)
                let newKeyVersion = try await DTGroupCryptoAPIImpl().rotateCrypto(groupId: gid,
                                                                                  request: params.toUpgradeRequest(),
                                                                                  baseKeyVersion: baseKeyVersion)

                await MainActor.run {
                    self?.databaseStorage.write { transaction in
                        manager.saveOrRotateRGroup(gid: gid,
                                                   rGroup: params.rGroup,
                                                   version: newKeyVersion,
                                                   transaction: transaction)

                        if let baseInfo = DTGroupBaseInfoEntity.anyFetch(uniqueId: gid, transaction: transaction) {
                            baseInfo.anyUpdate(transaction: transaction) { entity in
                                entity.encryptedName = params.encryptedName
                                entity.encryptedAvatar = params.encryptedAvatar
                            }
                        }

                        let resetInfoMessage = TSInfoMessage(timestamp: Date.ows_millisecondTimestamp(),
                                                             in: groupThread,
                                                             messageType: .groupCryptoUpgrade,
                                                             customMessage: Localized("GROUP_CRYPTO_RESET_SYSTEM_MSG"))
                        resetInfoMessage.isShouldAffectThreadSorting = true
                        resetInfoMessage.anyInsert(transaction: transaction)

                        // New key is stored; decrypt the new name/avatar immediately.
                        DTGroupKeyMessageHandler.refreshEncryptedGroupDisplay(gid: gid, transaction: transaction)
                    }

                    DTGroupKeyMessageHandler.shared.sendGroupKeyMessage(thread: groupThread,
                                                                        groupId: groupModel.groupId,
                                                                        rGroup: params.rGroup)

                    DTToastHelper.hide()
                    DTToastHelper.showInfo(Localized("GROUP_CRYPTO_RESET_SUCCESS_TOAST", comment: "Encryption key reset"))
                    Logger.info("[GroupCrypto] Rotate crypto succeeded for gid: \(gid), newKeyVersion: \(newKeyVersion)")

                    fromPage?.navigationController?.popViewController(animated: true)
                    self?.perform(NSSelectorFromString("updateTableContents"))
                    // Title shows the (decrypted) group name — re-decrypt it from the freshly stored
                    // ciphertext/key so the nav title updates in place (was only refreshing on re-entry).
                    self?.perform(NSSelectorFromString("refreshTitle"))
                    Self.inFlightRotateGids.remove(gid)
                }
            } catch {
                await MainActor.run {
                    Self.inFlightRotateGids.remove(gid)
                    DTToastHelper.hide()
                    Logger.error("[GroupCrypto] Rotate API failed: \(error)")
                    DTToastHelper.showInfo(Localized("GROUP_CRYPTO_RESET_FAILED", comment: "Reset failed"))
                }
            }
        }
    }

    /// Fetches the server's authoritative current groupCryptoKeyVersion via a fresh GET. This is the only
    /// reliable CAS baseline for rotate: the local group_crypto_keys version is the held key's generation
    /// (may lag or be absent), not the server's current version. Throws if the GET fails so a rotate is
    /// never sent with an unknown/stale base (better to abort than to trip the server CAS guard blindly).
    private static func fetchServerCryptoKeyVersion(gid: String) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            DTGetGroupInfoAPI().sendRequest(withGroupId: gid, success: { entity in
                continuation.resume(returning: entity.groupCryptoKeyVersion)
            }, failure: { error in
                continuation.resume(throwing: error ?? OWSGenericError("[GroupCrypto] GET groupInfo failed for rotate CAS base"))
            })
        }
    }
}

/// Avatar handling for a crypto-key rotate.
private enum RotateAvatarSource {
    /// Reuse the currently decryptable avatar (3.3 / name-only fill-in).
    case keepCurrent
    /// 3.4 avatar fill-in: a freshly picked image to upload and re-encrypt.
    case newImage(UIImage)
    /// 3.4 avatar was unreadable and the user kept the default → rotate carries no avatar.
    case dropAvatar
}
