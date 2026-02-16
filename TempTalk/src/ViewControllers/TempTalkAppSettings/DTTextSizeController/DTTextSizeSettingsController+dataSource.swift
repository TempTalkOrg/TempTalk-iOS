//
//  DTTextSizeSettingsController+dataSource.swift
//  Signal
//
//  Created by Henry on 2026/01/12.
//  Copyright © 2026 Difft. All rights reserved.
//

import Foundation

extension DTTextSizeSettingsController {

    func getDataSource() -> [[DTTextSizeSettingItem]] {
        // 文字大小选项 - 只保留两个
        let blankSection : [[String: Any]] = [
            ["icon":"",
             "title":"",
             "description":"",
             "cellStyle": 0
            ]
        ]
        let textSizeSection: [[String: Any]] = [
            ["icon": "",
             "title": Localized("TEXT_SIZE_DEFAULT"),
             "type": 1,
             "cellStyle": 6,
             "textSizeLevel": 0],  // default
            ["icon": "",
             "title": Localized("TEXT_SIZE_LARGER"),
             "type": 2,
             "cellStyle": 6,
             "textSizeLevel": 1]   // larger
        ]

        let dataSourceArr = [blankSection, textSizeSection]
        let dataSource = DTJsonParsesUtil.convert(dataSourceArr, to: DTTextSizeSettingItem.self)

        return dataSource
    }
}
