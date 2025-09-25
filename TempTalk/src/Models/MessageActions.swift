//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation
import TTServiceKit

@objc
protocol MessageActionsDelegate: AnyObject {
    func messageActionsShowDetailsForItem(_ conversationViewItem: ConversationViewItem)
    func messageActionsQuoteToItem(_ conversationViewItem: ConversationViewItem)
    func messageActionsForwardItem(_ conversationViewItem: ConversationViewItem)
    func messageActionsRecallItem(_ conversationViewItem: ConversationViewItem)
    func messageActionsForwardItemToNote(_ conversationViewItem: ConversationViewItem)
    func messageActionsMultiSelectItem(_ conversationViewItem: ConversationViewItem)
    func messageActionsTranslateForItem(_ conversationViewItem: ConversationViewItem)
    func messageActionsOriginalTranslateForItem(_ conversationViewItem: ConversationViewItem)
    func messageActionsPinItem(_ conversationViewItem: ConversationViewItem)
    func messageActionDeleteItem(_ conversationViewItem: ConversationViewItem)
    func messageEmojiReactionItem(_ conversationViewItem: ConversationViewItem, emoji: String)
}

struct MenuActionBuilder {
    
    static func quote(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> MenuAction {
        return MenuAction(image: #imageLiteral(resourceName: "ic_quote"),
                          title: Localized("MESSAGE_ACTION_QUOTE", comment: "Action sheet button title"),
                          subtitle: nil,
                          block: { [weak delegate] (_) in
            delegate?.messageActionsQuoteToItem(conversationViewItem)
            
        })
    }
    
    static func copyText(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> MenuAction {
        return MenuAction(image: #imageLiteral(resourceName: "ic_longpress_copy"),
                          title: Localized("MESSAGE_ACTION_COPY_TEXT", comment: "Action sheet button title"),
                          subtitle: nil,
                          block: { (_) in
            conversationViewItem.copyTextAction()
        })
    }
    
    static func translateText(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> MenuAction {
        return MenuAction(image: #imageLiteral(resourceName: "ic_inputbar_translate"),
                          title: Localized("MESSAGE_ACTION_TRANSLATE_TEXT", comment: "Action sheet button title"),
                          subtitle: nil,
                          block: { [weak delegate] (_) in
            delegate?.messageActionsTranslateForItem(conversationViewItem)
        })
    }
    
    static func translateWithOriginalText(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> MenuAction {
        return MenuAction(image: #imageLiteral(resourceName: "ic_inputbar_translate"),
                          title: Localized("MESSAGE_ACTION_TRANSLATE_ORIGINE", comment: "Action sheet button title"),
                          subtitle: nil,
                          block: { [weak delegate] (_) in
            delegate?.messageActionsOriginalTranslateForItem(conversationViewItem)
        })
    }
    
    static func convertSpeechToText(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> MenuAction {
        return MenuAction(image: #imageLiteral(resourceName: "convert_speechtotext"),
                          title: Localized("MESSAGE_ACTION_SPEECHTOTEXT", comment: "Action sheet button title"),
                          subtitle: nil,
                          block: { [weak delegate] (_) in
            delegate?.messageActionsTranslateForItem(conversationViewItem)
        })
    }
    
    static func convertSpeechToTextWithOriginalText(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> MenuAction {
        return MenuAction(image: #imageLiteral(resourceName: "convert_speechtotext_origin"),
                          title: Localized("MESSAGE_ACTION_SPEECHTOTEXT_ORIGIN", comment: "Action sheet button title"),
                          subtitle: nil,
                          block: { [weak delegate] (_) in
            delegate?.messageActionsOriginalTranslateForItem(conversationViewItem)
        })
    }
    
    static func showDetails(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> MenuAction {
        return MenuAction(image: #imageLiteral(resourceName: "ic_longpress_more"),
                          title: Localized("MESSAGE_ACTION_DETAILS", comment: "Action sheet button title"),
                          subtitle: nil,
                          block: { [weak delegate] (_) in
            delegate?.messageActionsShowDetailsForItem(conversationViewItem)
        })
    }
    
    static func deleteMessage(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> MenuAction {
        return MenuAction(image: #imageLiteral(resourceName: "ic_trash"),
                          title: Localized("MESSAGE_ACTION_DELETE_MESSAGE", comment: "Action sheet button title"),
                          subtitle: Localized("MESSAGE_ACTION_DELETE_MESSAGE_SUBTITLE", comment: "Action sheet button subtitle"),
                          block: { [weak delegate] (_) in
            delegate?.messageActionDeleteItem(conversationViewItem)
        })
    }
    
    static func copyMedia(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> MenuAction {
        return MenuAction(image: #imageLiteral(resourceName: "ic_longpress_copy"),
                          title: Localized("MESSAGE_ACTION_COPY_MEDIA", comment: "Action sheet button title"),
                          subtitle: nil,
                          block: { (_) in
            conversationViewItem.copyMediaAction()
        })
    }
    
    static func saveMedia(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> MenuAction {
        return MenuAction(image: #imageLiteral(resourceName: "ic_download"),
                          title: Localized("MESSAGE_ACTION_SAVE_MEDIA", comment: "Action sheet button title"),
                          subtitle: nil,
                          block: { (_) in
            conversationViewItem.saveMediaAction()
        })
    }
    
    static func forward(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> MenuAction {
        return MenuAction(image: #imageLiteral(resourceName: "ic_forward"),
                          title: Localized("MESSAGE_ACTION_FORWARD", comment: "Action sheet button title"),
                          subtitle: nil,
                          block: { [weak delegate] (_) in
            delegate?.messageActionsForwardItem(conversationViewItem)
        })
    }
    
    static func recall(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> MenuAction {
        return MenuAction(image: #imageLiteral(resourceName: "ic_recall_action"),
                          title: Localized("MESSAGE_ACTION_RECALL", comment: ""),
                          subtitle: nil,
                          block: { [weak delegate] (_) in
            delegate?.messageActionsRecallItem(conversationViewItem)
        })
    }
    
    static func forwardToNote(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> MenuAction {
        return MenuAction(image: #imageLiteral(resourceName: "ic_saveNote"),
                          title: Localized("MESSAGE_ACTION_FORWARD_TO_NOTE", comment: "Action sheet button title"),
                          subtitle: nil,
                          block: { [weak delegate] (_) in
            delegate?.messageActionsForwardItemToNote(conversationViewItem)
        })
    }
    
    static func multiSelect(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> MenuAction {
        return MenuAction(image: #imageLiteral(resourceName: "ic_multi_select"),
                          title: Localized("MESSAGE_ACTION_MULTI_SELECT", comment: "Action sheet button title"),
                          subtitle: nil,
                          block: { [weak delegate] (_) in
            delegate?.messageActionsMultiSelectItem(conversationViewItem)
        })
    }
    
    static func pinMessage(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> MenuAction {
        let actionTitle = conversationViewItem.isPinned ? Localized("MESSAGE_ACTION_UNPIN_MESSAGE", comment: "Action sheet button title") : Localized("MESSAGE_ACTION_PIN_MESSAGE", comment: "Action sheet button title")
        let actionIcon = conversationViewItem.isPinned ? "ic_unpin" : "ic_pin"
        return MenuAction(image: #imageLiteral(resourceName: actionIcon),
                          title: actionTitle,
                          subtitle: nil,
                          block: { [weak delegate] (_) in
            delegate?.messageActionsPinItem(conversationViewItem)
        })
    }
    
}

@objcMembers
class ConversationViewItemActions: NSObject {
    
    class func emojiReaction(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> MenuEmojiAction {
        guard conversationViewItem.interaction is TSMessage else {
            OWSLogger.error("interaction is not TSMessage class")
            return MenuEmojiAction(emojis: DTReactionHelper.recentlyUsed(), block: {_ in })
        }
        
        let message = conversationViewItem.interaction as! TSMessage
        let selectedEmojis = DTReactionHelper.selectedEmojis(message)
        
        return MenuEmojiAction(emojis: DTReactionHelper.recentlyUsed(), selectedEmojis: selectedEmojis, block: { [weak delegate] emoji in
            delegate?.messageEmojiReactionItem(conversationViewItem, emoji: emoji)
        })
    }

    // TODO: 逻辑放到 conversationViewItem 里
    class func showRecallAction(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> Bool{
                
        if !(conversationViewItem.interaction is TSOutgoingMessage) {
            return false
        }
        
//        guard let conversationVC = delegate as? ConversationViewController else {
//            return false
//        }
//        let containsBot = conversationVC.recipientsContainsBot()
//        if containsBot {
//            return false
//        }
        let currentTimestamp = NSDate.ows_millisecondTimeStamp()
        let msgTimestamp = conversationViewItem.interaction.timestamp
        let recallThreshold = UInt64(DTRecallConfig.fetch().timeoutInterval)
        // 3.1.3 防止用户修改本地时间，导致 arithmetic-overflow crash
        if currentTimestamp < msgTimestamp {
            return false
        }
        return (currentTimestamp - msgTimestamp)/1000 < recallThreshold
        
//        return (!containsBot && conversationViewItem.interaction is TSOutgoingMessage && NSDate.ows_millisecondTimeStamp() - conversationViewItem.interaction.timestamp < Int(DTRecallConfig.fetch().timeoutInterval)*1000);
    }
    
    class func showDeleteAction(conversationViewItem: ConversationViewItem) -> Bool{
        if (conversationViewItem.interaction is TSOutgoingMessage) && conversationViewItem.thread.isNoteToSelf {
            return true
        }
        return false
    }
    
    // TODO: 逻辑放到 conversationViewItem 里
    class func shouldPin(conversationViewItem: ConversationViewItem) -> Bool {
        
        if !conversationViewItem.isGroupThread {
            return false
        }
        
        guard let message = conversationViewItem.interaction as? TSMessage else {
            return false
        }
        
        if message.isPinned {
            return true
        }
        
        if conversationViewItem.isCombindedForwardMessage {
            guard let forwardMessage = conversationViewItem.combinedForwardingMessage else {
                return false
            }
            
            // 和 mac 同步一下
            let forwardAttachmentIds = forwardMessage.allForwardingAttachmentIds()
            var forwardStreams: [TSAttachmentStream]!
            self.databaseStorage.read { transaction in
                forwardStreams = forwardMessage.forwardingAttachmentStreams(with:transaction)
            }
            return forwardAttachmentIds.count == forwardStreams.count
        }
                
        if conversationViewItem.hasMediaActionContent {
            if let attachmentStream = conversationViewItem.attachmentStream() {
                return !attachmentStream.isAudio()
            }
            return true
        }
        
        return true
    }
    
    @objc class func confidentialActions(conversationViewItem: ConversationViewItem ,delegate: MessageActionsDelegate) -> [MenuAction] {
        
        var actions: [MenuAction] = []
        let message = conversationViewItem.interaction
        guard  message is TSMessage else { return actions }
        
        if (showRecallAction(conversationViewItem: conversationViewItem, delegate: delegate)){
            let recallAction = MenuActionBuilder.recall(conversationViewItem: conversationViewItem, delegate: delegate)
            actions.append(recallAction)
        }
        
        let showDetailsAction = MenuActionBuilder.showDetails(conversationViewItem: conversationViewItem, delegate: delegate)
        actions.append(showDetailsAction)
        
        return actions
    }
    
    @objc class func textActions(conversationViewItem: ConversationViewItem ,delegate: MessageActionsDelegate) -> [MenuAction] {
        
        var actions: [MenuAction] = []
        let message = conversationViewItem.interaction
        guard  message is TSMessage else { return actions }
        
        let quoteAction = MenuActionBuilder.quote(conversationViewItem: conversationViewItem, delegate: delegate)
        actions.append(quoteAction)
        
        if conversationViewItem.hasBodyTextActionContent {
            let copyTextAction = MenuActionBuilder.copyText(conversationViewItem: conversationViewItem, delegate: delegate)
            actions.append(copyTextAction)
        }
        
        let forwardAction = MenuActionBuilder.forward(conversationViewItem: conversationViewItem, delegate: delegate)
        actions.append(forwardAction)
        
        if shouldPin(conversationViewItem: conversationViewItem) {
            let pinAction = MenuActionBuilder.pinMessage(conversationViewItem: conversationViewItem, delegate: delegate)
            actions.append(pinAction)
        }
        
        if conversationViewItem.hasBodyTextActionContent &&
            conversationViewItem.canShowTranslateAction() {
            if conversationViewItem.showTranslateAction() {
                let translateTextAction = MenuActionBuilder.translateText(conversationViewItem: conversationViewItem, delegate: delegate)
                actions.append(translateTextAction)
            } else {
                let translateTextAction = MenuActionBuilder.translateWithOriginalText(conversationViewItem: conversationViewItem, delegate: delegate)
                actions.append(translateTextAction)
            }
        }
        
        let multiSelectAction = MenuActionBuilder.multiSelect(conversationViewItem: conversationViewItem, delegate: delegate)
        actions.append(multiSelectAction)
        let forwardToNoteAction = MenuActionBuilder.forwardToNote(conversationViewItem: conversationViewItem, delegate: delegate)
        actions.append(forwardToNoteAction)
        
        if showDeleteAction(conversationViewItem: conversationViewItem) {
            let deleteAction = MenuActionBuilder.deleteMessage(conversationViewItem: conversationViewItem, delegate: delegate)
            actions.append(deleteAction)
        }
        
        if (showRecallAction(conversationViewItem: conversationViewItem, delegate: delegate)){
            let recallAction = MenuActionBuilder.recall(conversationViewItem: conversationViewItem, delegate: delegate)
            actions.append(recallAction)
        }
        
        let showDetailsAction = MenuActionBuilder.showDetails(conversationViewItem: conversationViewItem, delegate: delegate)
        actions.append(showDetailsAction)
        
        return actions
    }
    
    @objc class func cardActions(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> [MenuAction] {
        let quoteAction = MenuActionBuilder.quote(conversationViewItem: conversationViewItem, delegate: delegate)
        
        var copyTextAction: MenuAction?
        if conversationViewItem.hasBodyTextActionContent {
            copyTextAction = MenuActionBuilder.copyText(conversationViewItem: conversationViewItem, delegate: delegate)
        }
        
        var pinAction: MenuAction?
        if shouldPin(conversationViewItem: conversationViewItem) {
            pinAction = MenuActionBuilder.pinMessage(conversationViewItem: conversationViewItem, delegate: delegate)
        }
        
        var translateTextAction: MenuAction?
        if conversationViewItem.hasBodyTextActionContent &&
            conversationViewItem.canShowTranslateAction() {
            if conversationViewItem.showTranslateAction() {
                translateTextAction = MenuActionBuilder.translateText(conversationViewItem: conversationViewItem, delegate: delegate)
            } else {
                translateTextAction = MenuActionBuilder.translateWithOriginalText(conversationViewItem: conversationViewItem, delegate: delegate)
            }
        }
        
        let multiSelectAction = MenuActionBuilder.multiSelect(conversationViewItem: conversationViewItem, delegate: delegate)
        let forwardAction = MenuActionBuilder.forward(conversationViewItem: conversationViewItem, delegate: delegate)
        let forwardToNoteAction = MenuActionBuilder.forwardToNote(conversationViewItem: conversationViewItem, delegate: delegate)
        
        var deleteAction: MenuAction?
        if showDeleteAction(conversationViewItem: conversationViewItem) {
            deleteAction = MenuActionBuilder.deleteMessage(conversationViewItem: conversationViewItem, delegate: delegate)
        }
        
        var recallAction: MenuAction?
        if (showRecallAction(conversationViewItem: conversationViewItem, delegate: delegate)){
            recallAction = MenuActionBuilder.recall(conversationViewItem: conversationViewItem, delegate: delegate)
        }
        
        let showDetailsAction = MenuActionBuilder.showDetails(conversationViewItem: conversationViewItem, delegate: delegate)
        
        let actions: [MenuAction]
        if conversationViewItem.isGroupThread {
            actions = [
                quoteAction,
                copyTextAction,
                forwardAction,
                pinAction,
                translateTextAction,
                multiSelectAction,
                forwardToNoteAction,
                deleteAction,
                recallAction,
                showDetailsAction
            ].compactMap { $0 }
        } else {
            actions = [
                quoteAction,
                copyTextAction,
                forwardAction,
                translateTextAction,
                pinAction,
                multiSelectAction,
                forwardToNoteAction,
                deleteAction,
                recallAction,
                showDetailsAction
            ].compactMap { $0 }
        }
        return actions
    }
    
    @objc class func mediaActions(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> [MenuAction] {
        let quoteAction = MenuActionBuilder.quote(conversationViewItem: conversationViewItem, delegate: delegate)
        
        var pinAction: MenuAction?
        var copyMediaAction: MenuAction?
        var saveMediaAction: MenuAction?
        var speechToTextAction: MenuAction?
        var multiSelectAction: MenuAction?
        var forwardAction: MenuAction?
        var forwardToNoteAction: MenuAction?
        
        if conversationViewItem.hasMediaActionContent {
            var isAudio = false
            if let attachmentStream = conversationViewItem.attachmentStream() {
                isAudio = attachmentStream.isAudio()
            }
            
            if shouldPin(conversationViewItem: conversationViewItem) {
                pinAction = MenuActionBuilder.pinMessage(conversationViewItem: conversationViewItem, delegate: delegate)
            }
            
            if !isAudio {
                //版本支持转发未下载的附件后，附件是否可以复制需要加上文件是否已下载的判断
                if let _ = conversationViewItem.attachmentStream() {
                    copyMediaAction = MenuActionBuilder.copyMedia(conversationViewItem: conversationViewItem, delegate: delegate)
                }
            }
            
            if conversationViewItem.attachmentStream()?.attachmentType == .voiceMessage {
                if conversationViewItem.showTranslateAction() {
                    speechToTextAction = MenuActionBuilder.convertSpeechToText(conversationViewItem: conversationViewItem, delegate: delegate)
                } else {
                    speechToTextAction = MenuActionBuilder.convertSpeechToTextWithOriginalText(conversationViewItem: conversationViewItem, delegate: delegate)
                }
            }
            
            if conversationViewItem.canSaveMedia() {
                saveMediaAction = MenuActionBuilder.saveMedia(conversationViewItem: conversationViewItem, delegate: delegate)
            }
              
            if !isAudio {
                multiSelectAction = MenuActionBuilder.multiSelect(conversationViewItem: conversationViewItem, delegate: delegate)
                forwardAction = MenuActionBuilder.forward(conversationViewItem: conversationViewItem, delegate: delegate)
            }
            
            forwardToNoteAction = MenuActionBuilder.forwardToNote(conversationViewItem: conversationViewItem, delegate: delegate)
        }
        
        var deleteAction: MenuAction?
        if showDeleteAction(conversationViewItem: conversationViewItem) {
            deleteAction = MenuActionBuilder.deleteMessage(conversationViewItem: conversationViewItem, delegate: delegate)
        }
        
        var recallAction: MenuAction?
        if (showRecallAction(conversationViewItem: conversationViewItem, delegate: delegate)){
            recallAction = MenuActionBuilder.recall(conversationViewItem: conversationViewItem, delegate: delegate)
        }
        
        let showDetailsAction = MenuActionBuilder.showDetails(conversationViewItem: conversationViewItem, delegate: delegate)
        
        let actions: [MenuAction] = [
            quoteAction,
            copyMediaAction,
            forwardAction,
            pinAction,
            saveMediaAction,
            speechToTextAction,
            multiSelectAction,
            forwardToNoteAction,
            deleteAction,
            recallAction,
            showDetailsAction
        ].compactMap { $0 }
        
        return actions
    }
    
    @objc class func quotedMessageActions(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> [MenuAction] {
        
        let quoteAction = MenuActionBuilder.quote(conversationViewItem: conversationViewItem, delegate: delegate)
        
        var pinAction: MenuAction?
        if shouldPin(conversationViewItem: conversationViewItem) {
            pinAction = MenuActionBuilder.pinMessage(conversationViewItem: conversationViewItem, delegate: delegate)
        }
        
        var multiSelectAction: MenuAction?
        var forwardAction: MenuAction?
        var forwardToNoteAction: MenuAction?
        
        if let _ = conversationViewItem.attachmentStream() {
        } else {
            multiSelectAction = MenuActionBuilder.multiSelect(conversationViewItem: conversationViewItem, delegate: delegate)
            forwardAction = MenuActionBuilder.forward(conversationViewItem: conversationViewItem, delegate: delegate)
            forwardToNoteAction = MenuActionBuilder.forwardToNote(conversationViewItem: conversationViewItem, delegate: delegate)
        }
                
        var deleteAction: MenuAction?
        if showDeleteAction(conversationViewItem: conversationViewItem) {
            deleteAction = MenuActionBuilder.deleteMessage(conversationViewItem: conversationViewItem, delegate: delegate)
        }
        
        var recallAction: MenuAction?
        if (showRecallAction(conversationViewItem: conversationViewItem, delegate: delegate)){
            recallAction = MenuActionBuilder.recall(conversationViewItem: conversationViewItem, delegate: delegate)
        }
        
        let showDetailsAction = MenuActionBuilder.showDetails(conversationViewItem: conversationViewItem, delegate: delegate)
        
        let actions: [MenuAction] = [
            quoteAction,
            forwardAction,
            pinAction,
            multiSelectAction,
            forwardToNoteAction,
            deleteAction,
            recallAction,
            showDetailsAction
        ].compactMap { $0 }
        
        return actions
    }
    
    @objc class func combinedForwardingMessageActions(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> [MenuAction] {
        
        var actions: [MenuAction] = []
        
        let quoteAction = MenuActionBuilder.quote(conversationViewItem: conversationViewItem, delegate: delegate)
        actions.append(quoteAction)
        
        let forwardAction = MenuActionBuilder.forward(conversationViewItem: conversationViewItem, delegate: delegate)
        actions.append(forwardAction)
        
        let multiSelectAction = MenuActionBuilder.multiSelect(conversationViewItem: conversationViewItem, delegate: delegate)
        actions.append(multiSelectAction)
        
        let forwardToNoteAction = MenuActionBuilder.forwardToNote(conversationViewItem: conversationViewItem, delegate: delegate)
        actions.append(forwardToNoteAction)
        
        if shouldPin(conversationViewItem: conversationViewItem) {
            let pinAction = MenuActionBuilder.pinMessage(conversationViewItem: conversationViewItem, delegate: delegate)
            actions.append(pinAction)
        }
        
        if showDeleteAction(conversationViewItem: conversationViewItem) {
            let deleteAction = MenuActionBuilder.deleteMessage(conversationViewItem: conversationViewItem, delegate: delegate)
            actions.append(deleteAction)
        }
        if (showRecallAction(conversationViewItem: conversationViewItem, delegate: delegate)){
            let recallAction = MenuActionBuilder.recall(conversationViewItem: conversationViewItem, delegate: delegate)
            actions.append(recallAction)
        }

        let showDetailsAction = MenuActionBuilder.showDetails(conversationViewItem: conversationViewItem, delegate: delegate)
        actions.append(showDetailsAction)
        
        return actions
    }
    
    @objc class func contactShareMessageActions(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> [MenuAction] {
        
        var actions: [MenuAction] = []
        
        let quoteAction = MenuActionBuilder.quote(conversationViewItem: conversationViewItem, delegate: delegate)
        actions.append(quoteAction)
        
        let multiSelectAction = MenuActionBuilder.multiSelect(conversationViewItem: conversationViewItem, delegate: delegate)
        actions.append(multiSelectAction)
        
        let forwardAction = MenuActionBuilder.forward(conversationViewItem: conversationViewItem, delegate: delegate)
        actions.append(forwardAction)
        
        let forwardToNoteAction = MenuActionBuilder.forwardToNote(conversationViewItem: conversationViewItem, delegate: delegate)
        actions.append(forwardToNoteAction)
        
        if showDeleteAction(conversationViewItem: conversationViewItem) {
            let deleteAction = MenuActionBuilder.deleteMessage(conversationViewItem: conversationViewItem, delegate: delegate)
            actions.append(deleteAction)
        }
        if (showRecallAction(conversationViewItem: conversationViewItem, delegate: delegate)){
            let recallAction = MenuActionBuilder.recall(conversationViewItem: conversationViewItem, delegate: delegate)
            actions.append(recallAction)
        }
        
        let showDetailsAction = MenuActionBuilder.showDetails(conversationViewItem: conversationViewItem, delegate: delegate)
        actions.append(showDetailsAction)
        
        return actions
    }
    
    @objc class func infoMessageActions(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> [MenuAction] {
        let deleteAction = MenuActionBuilder.deleteMessage(conversationViewItem: conversationViewItem, delegate: delegate)
        
        return [deleteAction]
    }
    
    @objc class func taskMessageActions(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> [MenuAction] {
        
        var actions: [MenuAction] = []
        
        let quoteAction = MenuActionBuilder.quote(conversationViewItem: conversationViewItem, delegate: delegate)
        actions.append(quoteAction)
        
        //        let multiSelectAction = MenuActionBuilder.multiSelect(conversationViewItem: conversationViewItem, delegate: delegate)
        //        actions.append(multiSelectAction)
        //        let forwardAction = MenuActionBuilder.forward(conversationViewItem: conversationViewItem, delegate: delegate)
        //        actions.append(forwardAction)
        //        let forwardToNoteAction = MenuActionBuilder.forwardToNote(conversationViewItem: conversationViewItem, delegate: delegate)
        //        actions.append(forwardToNoteAction)

        if showDeleteAction(conversationViewItem: conversationViewItem) {
            let deleteAction = MenuActionBuilder.deleteMessage(conversationViewItem: conversationViewItem, delegate: delegate)
            actions.append(deleteAction)
        }
        
        let showDetailsAction = MenuActionBuilder.showDetails(conversationViewItem: conversationViewItem, delegate: delegate)
        actions.append(showDetailsAction)
        
        return actions
    }
    
    @objc class func voteMessageActions(conversationViewItem: ConversationViewItem, delegate: MessageActionsDelegate) -> [MenuAction] {
        
        var actions: [MenuAction] = []
        
        let quoteAction = MenuActionBuilder.quote(conversationViewItem: conversationViewItem, delegate: delegate)
        actions.append(quoteAction)

        //        let multiSelectAction = MenuActionBuilder.multiSelect(conversationViewItem: conversationViewItem, delegate: delegate)
        //        actions.append(multiSelectAction)
        //        let forwardAction = MenuActionBuilder.forward(conversationViewItem: conversationViewItem, delegate: delegate)
        //        actions.append(forwardAction)
        
        if showDeleteAction(conversationViewItem: conversationViewItem) {
            let deleteAction = MenuActionBuilder.deleteMessage(conversationViewItem: conversationViewItem, delegate: delegate)
            actions.append(deleteAction)
        }
        
        if (showRecallAction(conversationViewItem: conversationViewItem, delegate: delegate)){
            let recallAction = MenuActionBuilder.recall(conversationViewItem: conversationViewItem, delegate: delegate)
            actions.append(recallAction)
        }
        
        let showDetailsAction = MenuActionBuilder.showDetails(conversationViewItem: conversationViewItem, delegate: delegate)
        actions.append(showDetailsAction)
        
        return actions
    }
    
}

