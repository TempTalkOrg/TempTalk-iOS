//
//  DTTextSizeSettingItem.swift
//  Signal
//
//  Created by Henry on 2026/01/12.
//  Copyright © 2026 Difft. All rights reserved.
//

import Foundation
import TTMessaging

class DTTextSizeSettingItem: DTSettingItem, DTSettingItemProtocol {

    enum CodingKeys: String, CodingKey {
        case icon
        case title
        case description
        case type
        case cellStyle
        case textSizeLevel
    }

    enum TextSizeSettingItemType: Int {
        case blank = 0
        case `default` = 1   // 默认大小
        case larger = 2      // 大字体
        case preview = 100
    }

    typealias SettingType = TextSizeSettingItemType

    private var _type: TextSizeSettingItemType?
    var type: TextSizeSettingItemType? {
        return _type
    }

    var textSizeLevel: TextSizeLevel?

    override init(icon: String, title: String, description: String?, cellStyle: Int?, openSwitch: Bool?, plainText: String? = "") {
        super.init(icon: icon, title: title, description: description, cellStyle: cellStyle, openSwitch: openSwitch)
    }

    convenience init(icon: String, title: String, type: Int, description: String? = "", cellStyle: Int?, openSwitch: Bool?, textSizeLevel: Int?) {
        self.init(icon: icon, title: title, description: description, cellStyle: cellStyle, openSwitch: openSwitch)
        self._type = TextSizeSettingItemType(rawValue: type)
        if let level = textSizeLevel {
            self.textSizeLevel = TextSizeLevel(rawValue: level)
        }
    }

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let typeValue = try? container.decode(Int.self, forKey: .type),
           let itemType = TextSizeSettingItemType(rawValue: typeValue) {
            self._type = itemType
        }

        if let levelValue = try? container.decode(Int.self, forKey: .textSizeLevel),
           let level = TextSizeLevel(rawValue: levelValue) {
            self.textSizeLevel = level
        }
    }
}
