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

        sheet.addAction(ActionSheetAction(
            title: Localized("GROUP_CRYPTO_INFO_DISMISS", comment: "OK"),
            style: .cancel
        ))
        presentActionSheet(sheet)
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
}
