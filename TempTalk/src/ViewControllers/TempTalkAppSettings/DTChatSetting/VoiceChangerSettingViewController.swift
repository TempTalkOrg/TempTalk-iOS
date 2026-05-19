//
//  VoiceChangerSettingViewController.swift
//  Difft
//
//  Copyright © 2026 Difft. All rights reserved.
//

import Foundation
import UIKit
import TTServiceKit

protocol VoiceChangerSettingDelegate: AnyObject {
    func didSelectVoiceChangerPreset(_ preset: String)
}

class VoiceChangerSettingViewController: SettingBaseViewController {

    weak var delegate: VoiceChangerSettingDelegate?

    private let reuse_identifier_blank = "DTBlankCell_VoiceChanger"
    private let reuse_identifier_checkbox = "DTSettingCheckBoxCell_VoiceChanger"

    private let presets: [(key: String, emoji: String, nameKey: String)] = DTUpdateNoiseController.voicePresets

    private lazy var tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .plain)
        if #available(iOS 15.0, *) {
            table.sectionHeaderTopPadding = 0
        }
        table.delegate = self
        table.dataSource = self
        table.separatorStyle = .none
        table.estimatedRowHeight = 52
        table.rowHeight = UITableView.automaticDimension
        table.register(DTBlankCell.self, forCellReuseIdentifier: reuse_identifier_blank)
        table.register(DTSettingCheckBoxCell.self, forCellReuseIdentifier: reuse_identifier_checkbox)
        return table
    }()

    override func loadView() {
        super.loadView()
        view.addSubview(tableView)
        tableView.autoPinEdgesToSuperviewEdges()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = Localized("SETTINGS_CHAT_VOICE_CHANGER")
        applyTheme()
    }

    override func applyTheme() {
        super.applyTheme()
        view.backgroundColor = Theme.bgpageSecondaryColor
        tableView.backgroundColor = Theme.bgpageSecondaryColor
        tableView.reloadData()
    }
}

// MARK: - UITableViewDelegate, UITableViewDataSource

extension VoiceChangerSettingViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : presets.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 0 ? 26 : 52
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: reuse_identifier_blank, for: indexPath) as! DTBlankCell
            cell.applyTheme()
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: reuse_identifier_checkbox, for: indexPath) as! DTSettingCheckBoxCell

        let preset = presets[indexPath.row]
        let localizedName = Localized(preset.nameKey)
        let displayTitle = preset.emoji.isEmpty ? localizedName : "\(preset.emoji) \(localizedName)"

        if indexPath.row == 0 {
            cell.borderType = presets.count > 1 ? .top : .all
        } else if indexPath.row == presets.count - 1 {
            cell.borderType = .bottom
        } else {
            cell.borderType = .none
        }

        let item = VoiceChangerSettingItem(
            icon: "",
            title: displayTitle,
            description: "",
            cellStyle: SettingCellStyle.checkBox.rawValue,
            presetKey: preset.key
        )

        cell.selectionStyle = .none
        cell.reloadCell(model: item)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if indexPath.section == 0 { return }

        let preset = presets[indexPath.row]
        CallSettingsManager.shared.updateVoicePreset(preset.key)
        delegate?.didSelectVoiceChangerPreset(preset.key)
        tableView.reloadData()
    }
}

// MARK: - VoiceChangerSettingItem

class VoiceChangerSettingItem: DTSettingItem {
    var presetKey: String

    init(icon: String, title: String, description: String, cellStyle: Int, presetKey: String) {
        self.presetKey = presetKey
        super.init(icon: icon, title: title, description: description, cellStyle: cellStyle)
    }

    required init(from decoder: Decoder) throws {
        self.presetKey = ""
        try super.init(from: decoder)
    }
}
