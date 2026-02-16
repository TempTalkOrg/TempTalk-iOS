//
//  DTSaveToAlbumSettingController.swift
//  TempTalk
//
//  Created by henry on 2026/01/04.
//  Copyright © 2026 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

@objc
class DTSaveToAlbumSettingController: OWSTableViewController {

    @objc var thread: TSThread?

    private var currentPolicy: MediaSavePolicy = .defaultPolicy

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bgpageSecondaryColor;
        tableView.backgroundColor = Theme.bgpageSecondaryColor;
        self.title = Localized("CONVERSATION_SETTINGS_SAVE_TO_ALBUM", comment: "")

        // 获取当前策略
        if let thread = thread {
            currentPolicy = MediaSavePolicyManager.shared.getConversationSavePolicy(threadId: thread.uniqueId)
        }

        updateTableContents()
    }
    
    override func applyTheme() {
        super.applyTheme()
        view.backgroundColor = Theme.bgpageSecondaryColor;
        tableView.backgroundColor = Theme.bgpageSecondaryColor;
    }

    private func updateTableContents() {
        let contents = OWSTableContents()

        // 选项 section
        let optionSection = OWSTableSection()

        // Default (Off) 选项
        let globalStatus = MediaSavePolicyManager.shared.getSaveToPhotoStatus()
        let defaultTitle = globalStatus ?
            Localized("CONVERSATION_SETTINGS_SAVE_TO_ALBUM_DEFAULT_ON", comment: "") :
            Localized("CONVERSATION_SETTINGS_SAVE_TO_ALBUM_DEFAULT_OFF", comment: "")

        optionSection.add(OWSTableItem(
            text: defaultTitle,
            actionBlock: { [weak self] in
                self?.selectPolicy(.defaultPolicy)
            },
            accessoryType: currentPolicy == .defaultPolicy ? .checkmark : .none
        ))

        // Always 选项
        optionSection.add(OWSTableItem(
            text: Localized("CONVERSATION_SETTINGS_SAVE_TO_ALBUM_ALWAYS", comment: ""),
            actionBlock: { [weak self] in
                self?.selectPolicy(.always)
            },
            accessoryType: currentPolicy == .always ? .checkmark : .none
        ))

        // Never 选项
        optionSection.add(OWSTableItem(
            text: Localized("CONVERSATION_SETTINGS_SAVE_TO_ALBUM_NEVER", comment: ""),
            actionBlock: { [weak self] in
                self?.selectPolicy(.never)
            },
            accessoryType: currentPolicy == .never ? .checkmark : .none
        ))

        contents.addSection(optionSection)

        // 提示信息 section（放在表格下面）
        let tipSection = OWSTableSection()
        tipSection.add(OWSTableItem(customCellBlock: { [weak self] in
            return self?.tipFooterCell() ?? UITableViewCell()
        }, customRowHeight: UITableView.automaticDimension, actionBlock: nil))
        contents.addSection(tipSection)

        self.contents = contents
    }

    private func tipFooterCell() -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "tipCell")
        cell.contentView.backgroundColor = Theme.defaultColor
        cell.selectionStyle = .none
        cell.preservesSuperviewLayoutMargins = true
        cell.contentView.preservesSuperviewLayoutMargins = true

        let tipLabel = UILabel()
        tipLabel.numberOfLines = 0
        tipLabel.text = Localized("CONVERSATION_SETTINGS_SAVE_TO_ALBUM_TIP", comment: "")
        tipLabel.textColor = Theme.isDarkThemeEnabled ? UIColor(rgbHex: 0xB7BDC6) : UIColor(rgbHex: 0x848E9C)
        tipLabel.font = UIFont.systemFont(ofSize: 12)
        tipLabel.textAlignment = .left
        cell.contentView.addSubview(tipLabel)

        tipLabel.translatesAutoresizingMaskIntoConstraints = false
        tipLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 8)
        tipLabel.autoPinEdge(toSuperviewEdge: .left, withInset: 32.5)
        tipLabel.autoPinEdge(toSuperviewEdge: .right, withInset: 30.5)
        tipLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: 8)

        return cell
    }

    private func selectPolicy(_ policy: MediaSavePolicy) {
        if currentPolicy == policy {
            return
        }

        currentPolicy = policy
        if let thread = thread {
            MediaSavePolicyManager.shared.updateConversationSavePolicy(threadId: thread.uniqueId, policy: policy)
        }

        updateTableContents()
    }
}

extension DTSaveToAlbumSettingController : OWSNavigationChildController {
    
    public var navbarBackgroundColorOverride: UIColor? { Theme.bgpageSecondaryColor }

    public var childForOWSNavigationConfiguration: OWSNavigationChildController? { nil }

    public var preferredNavigationBarStyle: OWSNavigationBarStyle { .solid }

    public var navbarTintColorOverride: UIColor? { nil }

    public var prefersNavigationBarHidden: Bool {
        return false
    }

    public var shouldCancelNavigationBack: Bool { false }
}
