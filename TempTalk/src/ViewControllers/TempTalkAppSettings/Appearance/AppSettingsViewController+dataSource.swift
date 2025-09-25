//
//  AppSettingsViewController+dataSource.swift
//  Signal
//
//  Created by hornet on 2023/6/5.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
import TTServiceKit
import TTMessaging

extension AppSettingsViewController {
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
    func getDataSource(transaction: SDSAnyReadTransaction) ->  [[DTSettingMeItem]] {
        
        var linkedCount = OWSDevice.anyCount(transaction: transaction);
        if linkedCount > 0 {
            linkedCount -= 1
        }
        
        if(linkedCount > 0){
            return self.uiDataSource(UInt(linkedCount))
        } else {
            return self.uiDataSource(nil)
        }
    }
    
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
    func uiDataSource(_ linkedDeviceNum: UInt?) -> [[DTSettingMeItem]] {
        var linkedDeviceItem: [String : Any]?
        var dataSourceArr  = [[[String: Any]]]()
        if let linkedDeviceNum = linkedDeviceNum, linkedDeviceNum > 0 {
            linkedDeviceItem = ["icon":"",
                                    "title":Localized("LINKED_DEVICES_TITLE",comment: ""),
                                    "description":"\(linkedDeviceNum)",
                                    "type":5,
                                    "cellStyle":4
            ]
        } else {
            linkedDeviceItem = ["icon":"",
                                    "title":Localized("LINKED_DEVICES_TITLE",comment: ""),
                                    "type":5,
                                "cellStyle":4
            ]
        }
    
        let firstSectionDataSource : [[String: Any]] = [
            ["icon":"",
             "title":Localized("SETTINGS_ITEM_ACCOUNT",comment: ""),
             "type":1 ,
             "cellStyle":1
            ],
            ["icon":"",
             "title":Localized("SETTINGS_PRIVACY_TITLE",comment: ""),
             "type":2,
             "cellStyle":1
            ] ,
            ["icon":"",
             "title":Localized("SETTINGS_CHAT",comment: ""),
             "type":3,
             "cellStyle":1
            ] ,
            ["icon":"",
             "title":Localized("SETTINGS_NOTIFICATIONS",comment: ""),
             "type":4,
             "cellStyle":1
            ],
            linkedDeviceItem!,
        ]
        
        let blankSection : [[String: Any]] = [
            ["icon":"",
             "title":"",
             "description":"",
             "cellStyle": 0
            ]
        ]
        let secondSectionDataSource : [[String: Any]] = [
            ["icon":"",
             "title":Localized("SETTINGS_ADVANCED_THEME",comment: ""),
             "description": Theme.isDarkThemeEnabled ? Localized("APPEARANCE_SETTINGS_DARK_THEME_NAME",comment: "") : Localized("APPEARANCE_SETTINGS_LIGHT_THEME_NAME",comment: "") ,
             "type":6,
             "cellStyle":4
            ],
            ["icon":"",
             "title":Localized("APPEARANCE_SETTINGS_LANGUAGE",comment: ""),
             "description": Localize.isChineseLanguage() ? Localized("APPEARANCE_SETTINGS_LANGUAGE_ZH",comment: "") : Localized("APPEARANCE_SETTINGS_LANGUAGE_EN",comment: "") ,
             "type":7,
             "cellStyle":4
            ],
        ]
        
        let thirdSectionDataSource : [[String: Any]] = [
            ["icon": "",
             "title": Localized("SETTINGS_ITEM_FEEDBACK", comment: ""),
             "type": 8,
             "cellStyle": 1
            ],
            ["icon": "",
             "title": Localized("SETTINGS_ITEM_ABOUT", comment: ""),
             "type": 9,
             "cellStyle": 1
            ],
        ]
        dataSourceArr.append(firstSectionDataSource)
        dataSourceArr.append(blankSection)
        dataSourceArr.append(secondSectionDataSource)
        dataSourceArr.append(blankSection)
        dataSourceArr.append(thirdSectionDataSource)
       let dataSource = DTJsonParsesUtil.convert(dataSourceArr, to: DTSettingMeItem.self)
        return dataSource
    }
}


