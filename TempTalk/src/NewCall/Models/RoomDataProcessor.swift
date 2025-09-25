//
//  RoomDataProcessor.swift
//  TempTalk
//
//  Created by Kris.s on 2025/2/27.
//  Copyright © 2025 Difft. All rights reserved.
//

import Foundation
import LiveKit

struct RoomMetadata {
    var canPublishAudio: Bool
    var canPublishVideo: Bool
}

class RoomDataProcessor {
    
    // 处理 Room 对象的 metadata，解析为 RoomMetadata
    static func parseMetadata(from room: Room) -> RoomMetadata? {
        guard let metadataString = room.metadata, let jsonData = metadataString.data(using: .utf8) else {
            Logger.error ("Invalid or missing room metadata string.")
            return nil
        }
        
        do {
            // 解析 JSON 数据
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                guard let canPublishAudio = jsonObject["canPublishAudio"] as? Bool,
                      let canPublishVideo = jsonObject["canPublishVideo"] as? Bool else {
                    Logger.error("Missing or invalid keys in room metadata.")
                    return nil
                }
                
                // 返回解析后的 RoomMetadata 对象
                return RoomMetadata(canPublishAudio: canPublishAudio, canPublishVideo: canPublishVideo)
            }
        } catch {
            Logger.error("Error parsing room metadata JSON: \(error)")
        }
        
        return nil
    }
}
