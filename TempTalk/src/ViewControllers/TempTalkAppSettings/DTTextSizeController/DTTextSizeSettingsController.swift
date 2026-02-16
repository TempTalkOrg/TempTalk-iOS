//
//  DTTextSizeSettingsController.swift
//  Signal
//
//  Created by Henry on 2026/01/12.
//  Copyright © 2026 Difft. All rights reserved.
//

import Foundation
import UIKit
import TTMessaging

@objc
class DTTextSizeSettingsController: SettingBaseViewController {

    let reuse_identifier_style_blank = "DTBlankCell_TextSize"
    let reuse_identifier_style_check_box = "DTCheckBoxCell_TextSize"
    let reuse_identifier_style_preview = "DTPreviewCell_TextSize"

    public lazy var mainTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.estimatedRowHeight = 52
        tableView.rowHeight = UITableView.automaticDimension
        tableView.register(DTBlankCell.self, forCellReuseIdentifier: reuse_identifier_style_blank)
        tableView.register(DTSettingCheckBoxCell.self, forCellReuseIdentifier: reuse_identifier_style_check_box)
        return tableView
    }()

    public lazy var dataSource: [[DTTextSizeSettingItem]] = {
        return getDataSource()
    }()

    override func loadView() {
        super.loadView()
        prepareView()
        prepareLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = Localized("SETTINGS_TEXT_SIZE_TITLE")
        prepareTheme()

        // 监听文字大小变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textSizeDidChange),
            name: .textSizeDidChange,
            object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.mainTableView.reloadData()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func textSizeDidChange() {
        // 刷新表格以更新预览和选中状态
        self.mainTableView.reloadData()
    }

    override func applyTheme() {
        super.applyTheme()
        view.backgroundColor = Theme.bgpageSecondaryColor
        mainTableView.backgroundColor = Theme.bgpageSecondaryColor
        self.mainTableView.reloadData()
    }

    func prepareTheme() {
        view.backgroundColor = Theme.bgpageSecondaryColor
        mainTableView.backgroundColor = Theme.bgpageSecondaryColor
    }

    func prepareView() {
        view.addSubview(mainTableView)
    }

    func prepareLayout() {
        mainTableView.autoPinEdgesToSuperviewEdges()
    }

    func changeTextSize(_ level: TextSizeLevel) {
        TextSizeManager.setCurrentLevel(level)
        // textSizeDidChange 会通过通知自动调用
    }
}

// MARK: - UITableViewDelegate & DataSource

extension DTTextSizeSettingsController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let count = self.dataSource[section].count
        return count
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        let count = self.dataSource.count
        return count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let settingItem = self.dataSource[indexPath.section][indexPath.row]
        if settingItem.cellStyle == .blank {
            return 26
        } else if settingItem.cellStyle == .preview {
            return UITableView.automaticDimension
        } else {
            return 52
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let settingItem: DTTextSizeSettingItem? = self.dataSource[indexPath.section][indexPath.row]
        guard let settingItem = settingItem else { return UITableViewCell() }

        if settingItem.cellStyle == .blank {
            let cell = tableView.dequeueReusableCell(withIdentifier: reuse_identifier_style_blank, for: indexPath) as? DTBlankCell
            guard let blankCell = cell else { return UITableViewCell() }
            blankCell.applyTheme()
            return blankCell

        } else if settingItem.cellStyle == .checkBox {
            let cell = tableView.dequeueReusableCell(withIdentifier: reuse_identifier_style_check_box, for: indexPath) as? DTSettingCheckBoxCell
            guard let checkBoxCell = cell else { return UITableViewCell() }

            // 设置圆角样式
            if indexPath.row == 0 {
                checkBoxCell.borderType = self.dataSource[indexPath.section].count > 1 ? .top : .all
            } else if indexPath.row == (self.dataSource[indexPath.section].count - 1) {
                checkBoxCell.borderType = .bottom
            } else {
                checkBoxCell.borderType = .none
            }

            checkBoxCell.selectionStyle = .none
            checkBoxCell.reloadCell(model: settingItem)
            return checkBoxCell

        } else {
            return UITableViewCell()
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let settingItem = self.dataSource[indexPath.section][indexPath.row]
        switch settingItem.type {
        case .some(.blank), .some(.preview):
            return
        case .some(.default):
            changeTextSize(.default)
        case .some(.larger):
            changeTextSize(.larger)
        case .none:
            return
        }
    }
}
