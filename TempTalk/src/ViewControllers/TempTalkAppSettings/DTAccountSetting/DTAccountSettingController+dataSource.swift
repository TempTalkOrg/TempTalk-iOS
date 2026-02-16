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
        // Load user information
        let idString = loadContactName()
        let email = loadEmail()
        let phoneNumber = loadPhoneNumber()

        // Build data source sections
        let topSpaceSection = buildTopSpaceSection()
        let accountSection = buildAccountSection(idString: idString, email: email, phoneNumber: phoneNumber)
        let bottomSection = buildBottomSection()

        // Combine all sections
        let dataSource = topSpaceSection + [accountSection] + bottomSection
        let dataSourceArr = DTJsonParsesUtil.convert(dataSource, to: DTAccountSettingItem.self)
        return dataSourceArr
    }

    // MARK: - Private Helper Methods

    private func loadContactName() -> String {
        guard let userid = self.signalAccount?.recipientId else {
            return ""
        }
        let customUid = self.contact?.customUid
        return NSString.displayUserId(withCustomUid: customUid, recipientId: userid)
    }

    private func loadEmail() -> String {
        guard let email = TSAccountManager.shared.loadStoredUserEmail(),
              DTParamsUtils.validateString(email).boolValue else {
            return Localized("SETTINGS_ITEM_UNLINK_TIP", comment: "Action desc Unlink")
        }
        return email
    }

    private func loadPhoneNumber() -> String {
        guard let phoneNumber = TSAccountManager.shared.loadStoredUserPhone(),
              DTParamsUtils.validateString(phoneNumber).boolValue else {
            return Localized("SETTINGS_ITEM_UNLINK_TIP", comment: "Action desc Unlink")
        }
        return phoneNumber
    }

    private func buildTopSpaceSection() -> [[[String: Any]]] {
        return [
            [
                buildBlankCell()
            ]
        ]
    }

    private func buildAccountSection(idString: String, email: String, phoneNumber: String) -> [[String: Any]] {
        return [
            buildContactNameCell(idString: idString),
            buildAllowSearchCell(),
            buildBlankCell(),
            buildEmailCell(email: email),
            buildPhoneNumberCell(phoneNumber: phoneNumber)
        ]
    }

    private func buildBottomSection() -> [[[String: Any]]] {
        return [
            [
                buildBlankCell()
            ],
            [
                buildLogoutCell()
            ]
        ]
    }

    // MARK: - Cell Builders

    private func buildContactNameCell(idString: String) -> [String: Any] {
        return [
            "icon": "",
            "title": Localized("SETTINGS_ITEM_ACCOUNT_ID", comment: "Action title Notification"),
            "description": idString,
            "type": 1,
            "cellStyle": 4
        ]
    }

    private func buildAllowSearchCell() -> [String: Any] {
        let isSearchEnabled = getSearchByCustomUidState()
        return [
            "icon": "",
            "title": Localized("SETTINGS_ITEM_ALLOW_SEARCH", comment: "Action title Allow search"),
            "description": "",
            "type": 5,
            "cellStyle": 5,
            "openSwitch": isSearchEnabled
        ]
    }

    private func buildEmailCell(email: String) -> [String: Any] {
        return [
            "icon": "",
            "title": Localized("SETTINGS_ITEM_ACCOUNT_EMAIL", comment: "Action title Notification"),
            "description": email,
            "type": 2,
            "cellStyle": 4
        ]
    }

    private func buildPhoneNumberCell(phoneNumber: String) -> [String: Any] {
        return [
            "icon": "",
            "title": Localized("SETTINGS_ITEM_ACCOUNT_PHONE", comment: "Action title Notification"),
            "description": phoneNumber,
            "type": 3,
            "cellStyle": 4
        ]
    }

    private func buildLogoutCell() -> [String: Any] {
        return [
            "icon": "",
            "title": Localized("SETTINGS_ITEM_LOGOUT", comment: "Action title Notification"),
            "description": "",
            "type": 4,
            "cellStyle": 1
        ]
    }

    private func buildBlankCell() -> [String: Any] {
        return [
            "icon": "",
            "title": "",
            "description": "",
            "cellStyle": 0
        ]
    }
    
    func canUsePasskeyAuth() -> Bool {
        let passkeyAuthSwitch = DTTokenKeychainStore.loadPassword(withAccountKey: ProfileInfoConstants.passkeysSwitchKey)
        return passkeyAuthSwitch == "1"
    }

    func getSearchByCustomUidState() -> Bool {
        return searchByCustomUidEnabled
    }

}


