//
//  DTSettingThemeItem.swift
//  Signal
//
//  Created by hornet on 2023/6/1.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation

enum LanguageType: String {
    case english = "en"
    case chinese = "zh_CN"
}

class DTLanguageSettingItem : DTSettingItem , DTSettingItemProtocol {
    /// 因为要关联子类的 type属性 所以这个地方需要重建 CodingKeys
    enum CodingKeys : String, CodingKey {
        case icon
        case title
        case type
        case cellStyle
        case languageType
    }
    
    ///用于标记具体的cell 的id
    enum LanguageSettingItemType: Int {
        case blank = 0
        case english = 1
        case chinese = 2
    }
    
    /// 关联协议中的 SettingType属性 并重写 type的 get 函数 为type赋值
    typealias SettingType = LanguageSettingItemType
    private var _type: LanguageSettingItemType?
    var type: LanguageSettingItemType? {
        return _type
    }
    
    
    var languageType: LanguageType?
    
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
                     language: String) {
        self.init(icon:icon, title:title,description: description,cellStyle: cellStyle, openSwitch: openSwitch)
        _type = LanguageSettingItemType(rawValue:type ?? 1)
        languageType = LanguageType(rawValue: language)
    }
    
    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let typeValue = try? container.decode(Int.self, forKey:.type),
           let itemType = LanguageSettingItemType(rawValue:typeValue) {
            self._type = itemType
        }
        if let typeValue = try? container.decode(String.self, forKey:.languageType),
           let itemType = LanguageType(rawValue:typeValue) {
            self.languageType = itemType
        }
    }
}
