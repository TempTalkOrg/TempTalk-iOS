//
//  NameGenerator.swift
//  TempTalk
//
//  Created by undefined on 21/12/24.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation

// 结构体定义用于解析JSON数据
struct NameData: Codable {
    let region: String
    let male: [String]
    let female: [String]
    let surnames: [String]
}

class NameGenerator {
    
    // 随机选择姓和名
    static func generateRandomName(isMale: Bool) -> String? {
        
        // 加载 JSON 数据
        let jsonData: Data? = {
            guard let fileURL = Bundle.main.url(forResource: "names", withExtension: "json") else {
                Logger.error("Error: Could not find names.json file.")
                return nil
            }
            
            do {
                return try Data(contentsOf: fileURL)
            } catch {
                Logger.error("Error: Failed to load names.json. \(error)")
                return nil
            }
        }()
        
        guard let data = jsonData else {
            return nil
        }
        
        // 解析JSON
        let decoder = JSONDecoder()
        let namesData: [NameData]
        
        do {
            namesData = try decoder.decode([NameData].self, from: data)
        } catch {
            Logger.error("Error: Failed to decode JSON data. \(error)")
            return nil
        }
        
        // 获取当前语言
        let currentLanguage = Locale.current.languageCode ?? "en"
        
        // 根据语言选择对应的地区
        let selectedRegionData = namesData.first { data in
            if currentLanguage == "zh" {
                return data.region == "China"
            } else {
                return data.region == "United States"
            }
        }
        
        guard let regionData = selectedRegionData else {
            Logger.error("Error: No data available for region \(currentLanguage == "zh" ? "China" : "United States")")
            return nil
        }
        
        let randomSurname = regionData.surnames.randomElement() ?? ""
        let firstNameList = isMale ? regionData.male : regionData.female
        let randomFirstName = firstNameList.randomElement() ?? ""
        
        if currentLanguage == "zh" {
            return "\(randomSurname)\(randomFirstName)"
        } else {
            return "\(randomFirstName) \(randomSurname)"
        }
    }
}

