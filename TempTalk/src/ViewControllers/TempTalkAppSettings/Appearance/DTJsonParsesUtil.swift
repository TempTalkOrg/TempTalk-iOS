//
//  DTJasonParsesUtil.swift
//  Signal
//
//  Created by hornet on 2023/5/25.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
class DTJsonParsesUtil {
    static func convert<T>(_ data: [[String: Any]], to type: T.Type) -> [T] where T: Decodable {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data, options: [])
            let objects = try JSONDecoder().decode([T].self, from: jsonData)
            return objects
        } catch {
            Logger.error("Error decoding JSON: \(error.localizedDescription)")
            return []
        }
    }
    
    static func convert<T>(_ data: [[[String: Any]]], to type: T.Type) -> [[T]] where T: Decodable {
        var result = [[T]]()
        for section in data {
            var objects = [T]()
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: section, options: [])
                objects = try JSONDecoder().decode([T].self, from: jsonData)
            } catch {
                Logger.error("Error decoding JSON: \(error.localizedDescription)")
            }
            
            result.append(objects)
        }
        
        return result
    }
    
    static func toJSON(_ object: Any) -> String? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: object, options: []) else { return nil }
        return String(data: jsonData, encoding: .utf8)
    }
    
    static func toDictionary(from jsonString: String) -> [String : Any]? {
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        do {
            if let jsonDict = try JSONSerialization.jsonObject(with: jsonData, options : .allowFragments) as? [String : Any] {
                return jsonDict
            } else {
                return nil
            }
        } catch _ as NSError{
            return nil
        }
    }
}
