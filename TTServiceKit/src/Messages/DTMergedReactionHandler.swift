//
//  DTMergedReactionHandler.swift
//  TTServiceKit
//
//  Created by Kris.s on 2024/8/5.
//

import Foundation

struct DTReactionInfo: Codable {
    //reaction消息内容
    var content: String
    //是否remove
    var remove: Bool
    //为remove时，reaction原始消息的时间戳
    var originTimestamp: UInt64
}

@objc
public class DTMergedReactionHandler: NSObject {
    
    @objc
    public class func buildParams(reactionMessage: DTReactionMessage, removedReactionSource: DTReactionSource?) -> [String: Any]? {
        var originTimestamp: UInt64 = 0
        if let removedReactionSource = removedReactionSource {
            originTimestamp = removedReactionSource.timestamp
        }
        let reactionInfo = DTReactionInfo(content: reactionMessage.emoji, remove: reactionMessage.removeAction, originTimestamp: originTimestamp)
        
        if let jsonData = try? JSONEncoder().encode(reactionInfo),
           let jsonDict = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
           return jsonDict
        }
        return nil
    }
}
