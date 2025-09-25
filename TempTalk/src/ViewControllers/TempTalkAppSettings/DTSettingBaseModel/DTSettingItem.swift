//
//  DTSettingItem.swift
//  Signal
//
//  Created by hornet on 2023/5/25.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation

protocol DTSettingItemProtocol {
    associatedtype SettingType: RawRepresentable where Self.SettingType.RawValue == Int
    var type: SettingType? { get }
}

extension DTSettingItemProtocol {
    var type: SettingType? { return nil }
}

///用于标记cell的类型
enum SettingCellStyle: Int , Codable{
    case blank = 0
    case onlyAccessory = 1
    case noAccessoryAndNoDescription = 2
    case onlyDescription = 3
    case accessoryAndDescription = 4
    case onlySwitch = 5
    case checkBox = 6
    case plainTextType = 7
}

class DTSettingItem: Decodable {
    var icon: String
    var title: String
    var description: String?
    var cellStyle: SettingCellStyle?
    var openSwitch: Bool?
    var plainText: String?
    var tag: Int?
    
    init(icon: String, title: String, description: String?, cellStyle : Int? = 1, openSwitch : Bool? = false, plainText: String? = "") {
        self.icon = icon
        self.title = title
        self.description = description
        self.cellStyle = SettingCellStyle(rawValue:cellStyle ?? 1 )
        self.openSwitch = openSwitch
        self.plainText = plainText
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        icon = try container.decode(String.self, forKey:.icon)
        title = try container.decode(String.self, forKey:.title)
        description = try? container.decodeIfPresent(String.self, forKey:.description)
        /// cellStyle 转模型的过程中如果发现 cellStyle 为空则 给一个默认值 1 对应的 CellStyle 是 onlyAccessory 类型
        if let typeValue = try? container.decodeIfPresent(Int.self, forKey:.cellStyle) ?? 1{
            cellStyle = SettingCellStyle(rawValue: typeValue)
        }
        openSwitch =  try? container.decodeIfPresent(Bool.self, forKey:.openSwitch)
        plainText =  try? container.decodeIfPresent(String.self, forKey:.plainText)
    }
    
    enum CodingKeys : String, CodingKey {
        case icon
        case title
        case description
        case cellStyle
        case openSwitch
        case plainText
    }
}
