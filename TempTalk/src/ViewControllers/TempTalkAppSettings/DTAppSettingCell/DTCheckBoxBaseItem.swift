//
//  DTCheckBoxBaseItem.swift
//  Signal
//
//  Created by hornet on 2023/6/1.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
class DTCheckBoxBaseItem : DTSettingItem , DTSettingItemProtocol {
    /// 因为要关联子类的 type属性 所以这个地方需要重建 CodingKeys
    enum CodingKeys : String, CodingKey {
        case icon
        case title
        case type
        case cellStyle
        case themeMode
    }
    
    ///用于标记具体的cell 的id
    enum CheckBoxBaseItemType: Int {
        case blank = 0
    }
    
    /// 关联协议中的 SettingType属性 并重写 type的 get 函数 为type赋值
    typealias SettingType = CheckBoxBaseItemType
    private var _type: CheckBoxBaseItemType?
    var type: CheckBoxBaseItemType? {
        return _type
    }
    
    var themeMode: ThemeMode?
    
    override init(icon: String,
                  title: String,
                  description: String?,
                  cellStyle : Int?,
                  openSwitch: Bool?,
                  plainText: String? = ""){
        super.init(icon: icon, title: title, description: description, cellStyle: cellStyle, openSwitch: openSwitch)
    }

    convenience init(icon: String,
                     title: String,
                     type: Int?,
                     description: String? = "",
                     cellStyle : Int?,
                     openSwitch: Bool,
                     mode: UInt) {
        self.init(icon:icon, title:title,description: description,cellStyle: cellStyle, openSwitch: openSwitch)
        _type = CheckBoxBaseItemType(rawValue:type ?? 0)
        themeMode = ThemeMode(rawValue: mode)
    }
    
    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let typeValue = try? container.decode(Int.self, forKey:.type),
           let itemType = CheckBoxBaseItemType(rawValue:typeValue) {
            self._type = itemType
        }
        if let typeValue = try? container.decode(UInt.self, forKey:.themeMode),
           let itemType = ThemeMode(rawValue:typeValue) {
            self.themeMode = itemType
        }
    }
}
