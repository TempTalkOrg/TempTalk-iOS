//
//  DTReactionHelper.swift
//  Wea
//
//  Created by Ethan on 2022/5/26.
//  Copyright © 2022 Difft. All rights reserved.
//

import UIKit
import TTServiceKit

@objcMembers
class DTReactionHelper: NSObject {
    
    class func emojis() -> [String] {
        DTEmojiConfig.serverEmojiConfig()
    }
    
    class func emojiTitlesForMessage(_ message: TSMessage, displayForBubble: Bool = false, transaction: SDSAnyReadTransaction) -> [String]? {
     
        guard let reactionMap = message.reactionMap else {
            return nil
        }
        let availableMap = reactionMap.filter {
            emojis().contains($0.key) && !$0.value.isEmpty
        }
        guard !availableMap.isEmpty else {
            return nil
        }
        
        //MARK: 按照emoji点击顺序排列
        let availableKeys = availableMap.keys.sorted {
            guard let value1 = availableMap[$0]?.first?.timestamp, let value2 = availableMap[$1]?.first?.timestamp else {
                return true
            }
            return value1 < value2
        }
        
        var emojiTitles = [String]()
        for emoji in availableKeys {
            guard let reactionSources = availableMap[emoji] else {
                continue
            }
            let reactionCount: Int = reactionSources.filter { !$0.isRemove }.count
            if reactionCount == 0 { continue }
            
            var stringCount = reactionCount > 999 ? "999+" : "\(reactionCount)"
            if displayForBubble {
                if reactionCount == 1, let singleSource = reactionSources.first {
                    stringCount = Environment.shared.contactsManager.displayName(forPhoneIdentifier: singleSource.source, transaction: transaction)
                }
                emojiTitles.append("\(emoji) \(stringCount)")
            } else {
                emojiTitles.append("\(emoji)(\(stringCount))")
            }
        }
        
        return emojiTitles
    }
    
    class func selectedEmojis(_ message: TSMessage) -> [String] {
      
        guard let reactionMap = message.reactionMap else {
            return []
        }
        let reactionKeys = Array(reactionMap.keys)
        var selectedEmojis = [String]()
        
        for emoji in emojis() {
            if reactionKeys.contains(emoji) {
                guard let reactionSources = reactionMap[emoji] else {
                    continue
                }
                for reactionSource in reactionSources {
                    if !reactionSource.isRemove && reactionSource.source == TSAccountManager.localNumber() {
                        selectedEmojis.append(emoji)
                        break
                    }
                }
            }
        }
        
        return selectedEmojis
    }
    
    class func reactionSources(for message: TSMessage, emoji: String) -> [DTReactionSource]? {

        guard let reactionMap = message.reactionMap else {
            return nil
        }
        
        let reactionKeys = Array(reactionMap.keys)
        guard reactionKeys.contains(emoji) else {
            return nil
        }
    
        guard var reactionSources = reactionMap[emoji] else {
            return nil
        }
        
        reactionSources.removeAll {
            $0.isRemove == true || $0.source.count == 0
        }
        
        return reactionSources
    }
    
    //MARK: 每次启动前清空reactionMessage表
    class func clearAllReactionMessage() {
        
        var reactionMessages = [DTReactionMessage]()
        self.databaseStorage.asyncRead { readTransaction in
            
            DTReactionMessage.anyEnumerate(transaction: readTransaction,
                                                batched: true,
                                                    block: { object, _ in
                
                    reactionMessages.append(object)
            });
            
        } completion: {
        
            if reactionMessages.count > 0 {
                self.databaseStorage.asyncWrite { writeTransaction in
                    
                    OWSLogger.info("remove \(reactionMessages.count) reactionMessages")
                    
                    reactionMessages.forEach {
                        $0.anyRemove(transaction:writeTransaction)
                    }
                }
            }
        }
    }
    
    
    //MARK: recently used emojis
    
    private let DTEmojiRecentlyUsedKey = "DTEmojiRecentlyUsedKey"
    var recentlyUsedStore = SDSKeyValueStore(collection: "DTRecentlyUsedEmoji")
    static let shared = DTReactionHelper()
    
    private var cachedRecentlyUsed: [String]?
    
    class func recentlyUsed() -> [String] {
        return shared.recentlyUsed()
    }
    
    class func lessUsed() -> [String] {
        return emojis().filter {
            !recentlyUsed().contains($0)
        }
    }

    func recentlyUsed() -> [String] {
        
        if let cachedRecentlyUsed {
            return cachedRecentlyUsed
        }
        
        if let storedUsed = storedRecentlyUsed() {
            return storedUsed
        }
        
        return Array(DTReactionHelper.emojis().prefix(7))
    }
    
    func storeRecentlyUsed(emoji: String) {
        guard !emoji.isEmpty else {
            return
        }
        
        var tmpUsed = [emoji]
        databaseStorage.asyncWrite { [self] transaction in
            if var storedUsed = storedRecentlyUsed(transaction: transaction) {
                storedUsed.removeAll { $0 == emoji }
                tmpUsed += storedUsed
                if tmpUsed.count < 7 {
                    let missingCount = 7 - tmpUsed.count
                    tmpUsed += Array(DTReactionHelper.emojis().prefix(missingCount))
                } else if tmpUsed.count > 7 {
                    let surplusCount = tmpUsed.count - 7
                    tmpUsed.removeLast(surplusCount)
                }
            } else {
                let allEmojisWithoutSame = DTReactionHelper.emojis().filter {
                    $0 != emoji
                }
                tmpUsed += Array(allEmojisWithoutSame.prefix(6))
            }
            let emojiString = tmpUsed.joined(separator: ",")
            recentlyUsedStore.setString(emojiString, key: DTEmojiRecentlyUsedKey, transaction: transaction)
        } completion: { [self] in
            cachedRecentlyUsed = tmpUsed
        }
    }
    
    func storedRecentlyUsed() -> [String]? {
        var recentlyUsed: [String]?
        databaseStorage.read { [self] transaction in
            recentlyUsed = storedRecentlyUsed(transaction: transaction)
        }
        return recentlyUsed
    }
    
    func storedRecentlyUsed(transaction: SDSAnyReadTransaction) -> [String]? {
        
        if let cachedRecentlyUsed {
            return cachedRecentlyUsed
        }
        
        guard let storedRecentlyUsed =  recentlyUsedStore.getString(DTEmojiRecentlyUsedKey, transaction: transaction), !storedRecentlyUsed.isEmpty else {
            return nil
        }
        
        return storedRecentlyUsed.components(separatedBy: ",")
    }
    
    func clearAllStoredEmojis() {
        
        databaseStorage.asyncWrite { [self] transaction in
            recentlyUsedStore.setString(nil, key: DTEmojiRecentlyUsedKey, transaction: transaction)
        }
    }
    
}
