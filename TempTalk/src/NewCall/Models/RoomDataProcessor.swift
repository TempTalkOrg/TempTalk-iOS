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
    let callType: CallType?
    let canPublishAudio: Bool
    let canPublishVideo: Bool
    let canPublishScreen: Bool
}

class RoomDataProcessor {
    
    // 处理 Room 对象的 metadata，解析为 RoomMetadata
    static func parseMetadata(from room: Room) -> RoomMetadata? {
        parseMetadata(from: room.metadata)
    }

    static func parseMetadata(from metadataString: String?) -> RoomMetadata? {
        guard let metadataString, let jsonData = metadataString.data(using: .utf8) else {
            Logger.error ("Invalid or missing room metadata string.")
            return nil
        }
        
        do {
            // 解析 JSON 数据
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                let callType: CallType?
                if let rawCallType = jsonObject["callType"] as? String,
                   !rawCallType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Unknown future values must behave as a multi-party instant call.
                    callType = CallType(rawValue: rawCallType) ?? .instant
                } else {
                    callType = nil
                }

                // Missing/invalid capability fields retain the previous permissive behavior:
                // the old strict parser returned nil, so the toolbar did not block publishing.
                return RoomMetadata(
                    callType: callType,
                    canPublishAudio: jsonObject["canPublishAudio"] as? Bool ?? true,
                    canPublishVideo: jsonObject["canPublishVideo"] as? Bool ?? true,
                    canPublishScreen: jsonObject["canPublishScreen"] as? Bool ?? true
                )
            }
        } catch {
            Logger.error("Error parsing room metadata JSON: \(error)")
        }
        
        return nil
    }
}
