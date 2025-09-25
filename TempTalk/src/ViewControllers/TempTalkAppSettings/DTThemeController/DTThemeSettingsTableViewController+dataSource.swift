//
//  DTThemeSettingsTableViewController+dataSource.swift
//  Signal
//
//  Created by hornet on 2023/6/1.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

extension DTThemeSettingsTableViewController {
    /// cellStyle 不同的值对应不同的cell类型
    ///blank = 0
    ///onlyAccessory = 1
    ///noAccessoryAndNoDescription = 2
    ///onlyDescription = 3
    ///accessoryAndDescription = 4
    ///onlySwitch = 5
    ///checkBox = 6
    ///plainTextType = 7
    ///注意可点击 cell的type 是需要递增且是唯一标识
    func getDataSource() -> [[DTThemeSettingItem]] {
        
        let topSpaceSectionDataSource : [[String: Any]] = [
            ["icon":"",
             "title":"",
             "description":"",
             "cellStyle": 0
            ]
        ]
        
        let firstSectionDataSource : [[String: Any]] = [
            ["icon":"",
             "title": Localized("APPEARANCE_SETTINGS_SYSTEM_THEME_NAME",comment: "Action title Notification"),
             "description":"",
             "type":1,
             "cellStyle":6,
             "themeMode":0
            ],
            
            ["icon":"",
             "title": Localized("APPEARANCE_SETTINGS_LIGHT_THEME_NAME",comment: "Action title Notification"),
             "description":"",
             "type": 2,
             "cellStyle":6,
             "themeMode":1
            ],
            
            ["icon":"",
             "title": Localized("APPEARANCE_SETTINGS_DARK_THEME_NAME",comment: "Action title Notification"),
             "description":"",
             "type": 3,
             "cellStyle":6,
             "themeMode":2
            ]
        ]
        
        let dataSource : [[[String: Any]]] = [topSpaceSectionDataSource, firstSectionDataSource]
        let dataSourceArr = DTJsonParsesUtil.convert(dataSource, to: DTThemeSettingItem.self)
        return dataSourceArr
    }
}

