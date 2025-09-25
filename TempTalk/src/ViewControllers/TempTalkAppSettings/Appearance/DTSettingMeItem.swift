//
//  DTSettingMeItem.swift
//  Signal
//
//  Created by hornet on 2023/5/25.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
class DTSettingMeItem: DTSettingItem , DTSettingItemProtocol {
    /// 因为要关联子类的 type属性 所以这个地方需要重建 CodingKeys
    enum CodingKeys : String, CodingKey {
        case icon
        case title
        case description
        case type
        case cellStyle
    }
    
    ///用于标记具体的cell
    enum SettingMeItemType: Int {
        case blank = 0
        case account = 1
        case privacy = 2
        case chat = 3
        case notifications = 4
        case linked_device = 5
        case theme = 6
        case language = 7
        case feedback = 8
        case about = 9
    }

    /// 关联协议中的 SettingType属性 并重写 type的 get 函数 为type赋值 
    typealias SettingType = SettingMeItemType
    private var _type: SettingMeItemType?
    var type: SettingMeItemType? {
        return _type
    }
    
    override init(icon: String, title: String, description: String?, cellStyle : Int?, openSwitch: Bool?, plainText: String? = ""){
        super.init(icon: icon, title: title, description: description, cellStyle: cellStyle, openSwitch:openSwitch)
    }

    convenience init(icon: String, title: String, type: Int, description: String? = "", cellStyle : Int?, openSwitch: Bool?) {
        self.init(icon:icon, title:title,description: description,cellStyle: cellStyle, openSwitch:openSwitch)
        self._type = SettingMeItemType(rawValue:type)
    }
    
    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let typeValue = try? container.decode(Int.self, forKey:.type),
           let itemType = SettingMeItemType(rawValue:typeValue) {
            self._type = itemType
        }
    }
}
