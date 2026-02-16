//
//  VoicePlaybackSpeedViewController.swift
//  Signal
//
//  Created by henry on 2026/01/08.
//  Copyright © 2026 Difft. All rights reserved.
//

import Foundation
import UIKit
import TTServiceKit

protocol VoicePlaybackSpeedDelegate: AnyObject {
    func didSelectPlaybackSpeed(_ speed: Float)
}

class VoicePlaybackSpeedViewController: SettingBaseViewController {

    weak var delegate: VoicePlaybackSpeedDelegate?

    private let reuse_identifier_blank = "DTBlankCell_VoiceSpeed"
    private let reuse_identifier_checkbox = "DTSettingCheckBoxCell_VoiceSpeed"

    private let speeds: [Float] = [1.0, 1.5, 2.0]
    private var selectedSpeed: Float = 1.0

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
        title = Localized("SETTINGS_CHAT_VOICE_PLAYBACK_SPEED")

        // 读取当前设置的速度
        selectedSpeed = MediaSavePolicyManager.shared.getPlaybackSpeed()

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

extension VoicePlaybackSpeedViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2  // 第一个 section 是空白间距，第二个 section 是速度选项
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1  // 空白 cell
        } else {
            return speeds.count
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 {
            return 26  // 顶部间距
        } else {
            return 52  // 正常 cell 高度
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // 第一个 section：空白间距
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: reuse_identifier_blank, for: indexPath) as! DTBlankCell
            cell.applyTheme()
            return cell
        }

        // 第二个 section：速度选项
        let cell = tableView.dequeueReusableCell(withIdentifier: reuse_identifier_checkbox, for: indexPath) as! DTSettingCheckBoxCell

        let speed = speeds[indexPath.row]
        let speedText: String
        if speed == 1.0 {
            speedText = "1x"
        } else if speed == 1.5 {
            speedText = "1.5x"
        } else {
            speedText = "2x"
        }

        // 设置边框类型
        if indexPath.row == 0 {
            cell.borderType = speeds.count > 1 ? .top : .all
        } else if indexPath.row == speeds.count - 1 {
            cell.borderType = .bottom
        } else {
            cell.borderType = .none
        }

        // 创建 item
        let item = VoiceSpeedSettingItem(
            icon: "",
            title: speedText,
            description: "",
            cellStyle: SettingCellStyle.checkBox.rawValue,
            speed: speed
        )

        cell.selectionStyle = .none
        cell.reloadCell(model: item)

        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        // 忽略空白 cell 的点击
        if indexPath.section == 0 {
            return
        }

        let speed = speeds[indexPath.row]
        selectedSpeed = speed

        // 保存到数据库
        MediaSavePolicyManager.shared.updatePlaybackSpeed(speed)

        // 通知 delegate
        delegate?.didSelectPlaybackSpeed(speed)

        // 刷新表格显示勾选标记
        tableView.reloadData()
    }
}

// MARK: - VoiceSpeedSettingItem

class VoiceSpeedSettingItem: DTSettingItem {
    var speed: Float = 1.0

    init(icon: String, title: String, description: String, cellStyle: Int, speed: Float) {
        self.speed = speed
        super.init(icon: icon, title: title, description: description, cellStyle: cellStyle)
    }

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
}
