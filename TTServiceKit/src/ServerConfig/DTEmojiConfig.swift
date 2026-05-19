//
//  DTEmojiConfig.swift
//  TTServiceKit
//
//  Created by Ethan on 2022/9/14.
//

import UIKit

open class DTEmojiConfig: NSObject {
    
    private class func defultConfig() -> [String] {
        ["👍", "😄", "😢", "👌", "🎉", "😂", "❤️", "🤝", "👏", "✅", "🔥", "🙏"]
    }

    public class func serverEmojiConfig() -> [String] {
        var resultEmojis = defultConfig()
        DTServerConfigManager.shared().fetchConfigFromLocal(withSpaceName: "emojiReaction") { config, error in
            guard let config = config as? [String], error == nil else {
                return
            }
            resultEmojis = config
        }

        return resultEmojis
    }

    public class func serverEmojiConfig(transaction: SDSAnyReadTransaction) -> [String] {
        var resultEmojis = defultConfig()
        DTServerConfigManager.shared().fetchConfigFromLocal(withSpaceName: "emojiReaction", transaction: transaction) { config, error in
            guard let config = config as? [String], error == nil else {
                return
            }
            resultEmojis = config
        }
        return resultEmojis
    }
    
}
