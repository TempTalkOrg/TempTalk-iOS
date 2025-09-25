//
//  File.swift
//  Signal
//
//  Created by hornet on 2023/5/31.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
extension DTAccountSettingController {
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
    func getDataSource() -> [[DTAccountSettingItem]] {
        var idString: String?
        if let userid = self.signalAccount?.recipientId {
            idString = NSString.base58EncodedString(userid)
        }
        var email = TSAccountManager.shared.loadStoredUserEmail()
        if(!DTParamsUtils.validateString(email).boolValue){
            email = Localized("SETTINGS_ITEM_UNLINK_TIP",comment: "Action desc Unlink")
        }
        var phoneNumber = TSAccountManager.shared.loadStoredUserPhone()
        if(!DTParamsUtils.validateString(phoneNumber).boolValue){
            phoneNumber = Localized("SETTINGS_ITEM_UNLINK_TIP",comment: "Action desc Unlink")
        }
        
        let topSpaceSectionDataSource : [[[String: Any]]] = [
            [
                ["icon":"",
                 "title":"",
                 "description":"",
                 "cellStyle": 0
                ]
            ]
        ]
        
        var firstSectionDataSource : [[String: Any]] = [
            
            ["icon":"",
             "title": Localized("SETTINGS_ITEM_ACCOUNT_ID",comment: "Action title Notification"),
             "description":idString ?? "",
             "type":1,
             "cellStyle": 3
            ],
        ]
        let emailData : [String: Any] = ["icon":"",
                                         "title": Localized("SETTINGS_ITEM_ACCOUNT_EMAIL",comment: "Action title Notification"),
                                         "description":email!,
                                         "type":2,
                                         "cellStyle": 4
        ]
        
        
        
        firstSectionDataSource.append(emailData)
        let phoneNumberData : [String: Any] = ["icon":"",
                                               "title": Localized("SETTINGS_ITEM_ACCOUNT_PHONE",comment: "Action title Notification"),
                                               "description":phoneNumber!,
                                               "type":3,
                                               "cellStyle": 4,
        ]
        firstSectionDataSource.append(phoneNumberData)
        var dataSource  = [[[String: Any]]]()
        let bottomSectionDataSource : [[[String : Any]]] =
        [
            [
                ["icon":"",
                 "title":"",
                 "description":"",
                 "cellStyle": 0
                ],
            ],
            [
                ["icon":"",
                 "title": Localized("SETTINGS_ITEM_LOGOUT",comment: "Action title Notification"),
                 "description":"",
                 "type":4,
                 "cellStyle": 1
                ],
            ]
        ]
        
        dataSource.insert(firstSectionDataSource, at: 0)
        dataSource = topSpaceSectionDataSource + dataSource + bottomSectionDataSource
        let dataSourceArr = DTJsonParsesUtil.convert(dataSource, to: DTAccountSettingItem.self)
        return dataSourceArr
    }
    
    func canUsePasskeyAuth() -> Bool {
        let passkeyAuthSwitch = DTTokenKeychainStore.loadPassword(withAccountKey: ProfileInfoConstants.passkeysSwitchKey)
        let isOpenPasskeyAuthSwith = passkeyAuthSwitch == "1" ? true : false
        return isOpenPasskeyAuthSwith
    }
    
}


