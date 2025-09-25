//
//  DTNotificationModel.swift
//  Signal
//
//  Created by hornet on 2023/5/26.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation

class DTNotificationItem: DTSettingItem , DTSettingItemProtocol {
    /// 因为要关联子类的 type属性 所以这个地方需要重建 CodingKeys
    enum CodingKeys : String, CodingKey {
        case icon
        case title
        case description
        case type
        case cellStyle
        
    }
    
    ///用于标记具体的cell 的id
    enum NotificationItemType: Int {
        case blank = 0
        case notification = 1
        case messageSound = 2
        case playWhileAppOpen = 3
        case displayContent = 4
    }

    /// 关联协议中的 SettingType属性 并重写 type的 get 函数 为type赋值
    typealias SettingType = NotificationItemType
    private var _type: NotificationItemType?
    var type: NotificationItemType? {
        return _type
    }
    
    
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
                     openSwitch: Bool) {
        self.init(icon:icon, title:title,description: description,cellStyle: cellStyle, openSwitch: openSwitch)
        _type = NotificationItemType(rawValue:type ?? 0)
    }
    
    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let typeValue = try? container.decode(Int.self, forKey:.type),
           let itemType = NotificationItemType(rawValue:typeValue) {
            self._type = itemType
        }
    }
}
