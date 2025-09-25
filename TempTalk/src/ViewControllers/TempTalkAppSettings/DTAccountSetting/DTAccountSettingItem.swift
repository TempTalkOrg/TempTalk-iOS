//
//  DTAccountSettingItem.swift
//  Signal
//
//  Created by hornet on 2023/5/31.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation

class DTAccountSettingItem: DTSettingItem , DTSettingItemProtocol {
    /// 因为要关联子类的 type属性 所以这个地方需要重建 CodingKeys
    enum CodingKeys : String, CodingKey {
        case icon
        case title
        case description
        case type
        case openSwitch
        case cellStyle
        case plainText
    }
    
    ///用于标记具体的cell 的id
    enum AccountSettingItemType: Int {
        case blank = 0
        case id = 1
        case email = 2
        case phoneNumber = 3
        case logout = 4
    }

    /// 关联协议中的 SettingType属性 并重写 type的 get 函数 为type赋值
    typealias SettingType = AccountSettingItemType
    private var _type: AccountSettingItemType?
    var type: AccountSettingItemType? {
        return _type
    }
    
    override init(icon: String,
                  title: String,
                  description: String?,
                  cellStyle : Int?,
                  openSwitch: Bool?,
                  plainText: String?){
        super.init(icon: icon, title: title, description: description, cellStyle: cellStyle, openSwitch: openSwitch, plainText: plainText)
    }

    convenience init(icon: String,
                     title: String,
                     type: Int?,
                     description: String? = "",
                     cellStyle : Int?,
                     openSwitch: Bool,
                     plainText: String?) {
        self.init(icon:icon, title:title,description: description,cellStyle: cellStyle, openSwitch: openSwitch, plainText: plainText)
        _type = AccountSettingItemType(rawValue:type ?? 0)
    }
    
    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let typeValue = try? container.decode(Int.self, forKey:.type),
           let itemType = AccountSettingItemType(rawValue:typeValue) {
            self._type = itemType
        }
        if let typeValue = try? container.decode(String.self, forKey:.plainText) {
            self.plainText = typeValue
        }
    }
}
