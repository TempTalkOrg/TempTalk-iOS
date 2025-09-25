//
//  ConversationViewController+Translate.swift
//  Signal
//
//  Created by Jaymin on 2023/12/28.
//  Copyright © 2023 Difft. All rights reserved.
//

import Foundation
import TTServiceKit

// MARK: - Public

@objc extension ConversationViewController {
    
    /// 点击 menu 中翻译，展示翻译选项弹窗
    func showTranslateLanguageAlert(conversationViewItem: ConversationViewItem) {
        // 如果是media文件类型直接翻译
        if let message = conversationViewItem.interaction as? TSMessage,
            let attachmentId = message.attachmentIds.first  {
            var attachment: TSAttachment?
            databaseStorage.read { transaction in
                attachment = TSAttachment.anyFetch(uniqueId: attachmentId, transaction: transaction)
            }
            if let attachmentStream = attachment as? TSAttachmentStream, attachmentStream.attachmentType == .voiceMessage {
                self.translateMessage(targetLanguage: .chinese, conversationViewItem: conversationViewItem)
                return
            }
        }
        
        let actionSheet = ActionSheetController(title: nil, message: nil)
        actionSheet.addAction(OWSActionSheets.cancelAction)
        
        let englishAction = ActionSheetAction(
            title: Localized("SETTINGS_SECTION_TRANSLATE_LANGUAGE_ENGLISH", nil),
            style: .default
        ) { action in
            self.translateMessage(targetLanguage: .english, conversationViewItem: conversationViewItem)
        }
        actionSheet.addAction(englishAction)
        
        let chineseAction = ActionSheetAction(
            title: Localized("SETTINGS_SECTION_TRANSLATE_LANGUAGE_CHINESE", nil),
            style: .default
        ) { action in
            self.translateMessage(targetLanguage: .chinese, conversationViewItem: conversationViewItem)
        }
        actionSheet.addAction(chineseAction)
        
        dismissKeyBoard()
        presentActionSheet(actionSheet)
    }
    
    /// 点击 menu 关闭翻译，展示原文
    func showOriginalLanguage(conversationViewItem: ConversationViewItem) {
        guard let message = conversationViewItem.interaction as? TSMessage else {
            return
        }
        guard let translateMessage = message.translateMessage, 
                !translateMessage.translatedType.isEqualTo(languageType: .original) else {
            return
        }
        //改操作允许离线通过更新数据库
        DatabaseOfflineManager.shared.canOfflineUpdateDatabase  = true
        translateMessage.updateTranslateType(.original)
        // 语音消息还原
        if conversationViewItem.messageCellType() == .audio, !conversationViewItem.hasBodyText {
            translateMessage.updateTranslateState(.failed)
            translateMessage.tranChinseResult = ""
            translateMessage.tranEngLishResult = ""
        }
        databaseStorage.asyncWrite { transaction in
            message.anyUpdateMessage(transaction: transaction) { messageCopy in
                messageCopy.translateMessage = translateMessage
            }
        }
    }
    
    /// 点击 incoming message 右侧的翻译按钮
    func translateIncoming(conversationViewItem: ConversationViewItem) {
        guard let message = conversationViewItem.interaction as? TSIncomingMessage else {
            return
        }
        if let translateMessage = message.translateMessage { // 已翻译（可能翻译成功了，也可能失败）
            if translateMessage.isShowingEnglish || translateMessage.isShowingChinese { // 翻译成功，且正在展示翻译后的内容，需要展示原文
                translateMessage.updateTranslateType(.original)
                asyncUpdateMessage(message, withTranslateMessage: translateMessage)
                
            } else { // 这个地方表示翻译失败了或当前是原文展示，需要翻译成目标语言
                if isCurrentLanguageZh { // 当前是中文
                    if !translateMessage.tranChinseResult.isEmpty {
                        translateMessage.updateTranslateType(.chinese)
                        translateMessage.updateTranslateState(.sucessed)
                        asyncUpdateMessage(message, withTranslateMessage: translateMessage)
                    } else {
                        self.translateMessageWithoutCache(targetLanguage: .chinese, conversationViewItem: conversationViewItem)
                    }
                } else { // 当前是其他语言翻译成英文
                    if !translateMessage.tranEngLishResult.isEmpty {
                        translateMessage.updateTranslateType(.english)
                        translateMessage.updateTranslateState(.sucessed)
                        asyncUpdateMessage(message, withTranslateMessage: translateMessage)
                    } else {
                        self.translateMessageWithoutCache(targetLanguage: .english, conversationViewItem: conversationViewItem)
                    }
                }
            }
        } else { // 目前展示的是原文，且未翻译
            let targetLanguage: DTTranslateMessageType = isCurrentLanguageZh ? .chinese : .english
            translateMessageWithoutCache(targetLanguage: targetLanguage, conversationViewItem: conversationViewItem)
        }
    }
    
    /// 查看更多翻译内容
    func showMoreTranslateResult(conversationItem: ConversationViewItem) {
        guard let message = conversationItem.interaction as? TSMessage else {
            return
        }
        guard let translateMessage = message.translateMessage else {
            return
        }
        let translateType = translateMessage.translatedType
        var translateResult: String?
        if translateType.isEqualTo(languageType: .chinese) {
            translateResult = translateMessage.tranChinseResult
        } else if translateType.isEqualTo(languageType: .english) {
            translateResult = translateMessage.tranEngLishResult
        }
        if let translateResult {
            let viewController = LongTextViewController(messageBody: translateResult)
            navigationController?.pushViewController(viewController, animated: true)
        }
    }
    
    /// 修改自动翻译设置
    func changeTranslateSetting() {
        if let translateSettingType = thread.translateSettingType?.intValue, translateSettingType == 0 {
            if DateUtil.isChinese() {
                changeTranslateSettingType(.chinese)
            } else {
                changeTranslateSettingType(.english)
            }
        } else {
            changeTranslateSettingType(.original)
        }
    }
}

// MARK: - Private

private extension ConversationViewController {
    func translateMessage(targetLanguage: DTTranslateMessageType, conversationViewItem: ConversationViewItem) {
        guard let message = conversationViewItem.interaction as? TSMessage else {
            return
        }
        //改操作允许离线通过更新数据库
        DatabaseOfflineManager.shared.canOfflineUpdateDatabase  = true
        self.databaseStorage.read { transaction in
            message.anyReload(transaction: transaction)
        }
        
        if conversationViewItem.messageCellType() == .audio {
            // 语音消息不缓存
            self.translateMessageWithoutCache(
                targetLanguage: targetLanguage,
                conversationViewItem: conversationViewItem
            )
            return
        }
        
        guard let translateMessage = message.translateMessage else {
            self.translateMessageWithoutCache(
                targetLanguage: targetLanguage,
                conversationViewItem: conversationViewItem
            )
            return
        }
        
        switch (targetLanguage, translateMessage.isTranslateEnglishSuccess, translateMessage.isTranslateChineseSuccess) {
        case (.english, true, _), (.chinese, _, true):
            translateMessage.updateTranslateState(.sucessed)
            translateMessage.updateTranslateType(targetLanguage)
            self.asyncUpdateMessage(message, withTranslateMessage: translateMessage)
        default:
            self.translateMessageWithoutCache(
                targetLanguage: targetLanguage,
                conversationViewItem: conversationViewItem
            )
        }
    }
    
    /// 根据消息类型翻译
    func translateMessageWithoutCache(targetLanguage: DTTranslateMessageType, conversationViewItem: ConversationViewItem) {
        guard let message = conversationViewItem.interaction as? TSMessage else {
            return
        }
        if let attachmentId = message.attachmentIds.first { // 表示附件类型
            translateAttachmentMessage(
                attachmentId: attachmentId,
                message: message,
                targetLanguage: targetLanguage
            )
        } else if message.isSingleForward(),
            let forwardingMessage = message.combinedForwardingMessage?.subForwardingMessages.first { // 转发消息类型
            translateSingleForwardMessage(
                message: message,
                forwardingMessage: forwardingMessage,
                conversationViewItem: conversationViewItem,
                targetLanguage: targetLanguage
            )
        } else {
            var contents = message.body
            if let cardUniqueId = message.cardUniqueId, !cardUniqueId.isEmpty {
                contents = conversationViewItem.card?.content
            }
            handleTranslateState(
                message: message,
                languageType: targetLanguage,
                translatedState: .translating,
                translateTipMessage: Localized("TRANSLATE_TIP_MESSAGE", "")
            )
            requestTranslateLanguage(
                message: message,
                sourceLanguage: nil,
                targetLanguage: targetLanguage,
                contents: contents ?? "",
                attachmentId: nil
            )
        }
    }
    
    /// 根据消息类型翻译 - 附件类型
    func translateAttachmentMessage(
        attachmentId: String,
        message: TSMessage,
        targetLanguage: DTTranslateMessageType
    ) {
        var attachment: TSAttachment?
        databaseStorage.read { transaction in
            attachment = TSAttachment.anyFetch(uniqueId: attachmentId, transaction: transaction)
        }
        if let attachmentStream = attachment as? TSAttachmentStream {
            var text: String?
            if let mediaURL = attachmentStream.mediaURL(),
                let data = try? Data(contentsOf: mediaURL) {
                text = String(data: data, encoding: .utf8)
            }
            if attachmentStream.contentType == OWSMimeTypeOversizeTextMessage, let text {
                let isOverMessageSize = text.count > kOversizeTextMessageSizelength
                let translatedState: DTTranslateMessageStateType = isOverMessageSize ? .failed : .translating
                let translateTipMessageKey = isOverMessageSize ? "TRANSLATE_TIP_MESSAGE_LONG_TEXT" : "TRANSLATE_TIP_MESSAGE"
                handleTranslateState(
                    message: message,
                    languageType: targetLanguage,
                    translatedState: translatedState,
                    translateTipMessage: Localized(translateTipMessageKey, "")
                )
            } else if attachmentStream.attachmentType == .voiceMessage {
//                if let translateMessage = message.translateMessage, translateMessage.translateStateEqualTo(.translating), !DTParamsUtils.validateString(translateMessage.tranChinseResult).boolValue, !DTParamsUtils.validateString(translateMessage.tranEngLishResult).boolValue {
//                    // 当前是翻译状态且没没用翻译结果，不需要再多次执行翻译
//                    Logger.info("\(logTag) current message is converting")
//                    return
//                }
                Logger.info("\(logTag) voiceMessage start converting")
                handleTranslateState(
                    message: message,
                    languageType: .chinese,
                    translatedState: .translating,
                    translateTipMessage: Localized("SPEECHTOTEXT_CONVERT_TIP_MESSAGE", "")
                )
                requestTranslateLanguage(
                    message: message,
                    sourceLanguage: nil,
                    targetLanguage: .chinese,
                    contents: "",
                    attachmentId: attachmentId
                )
            } else {
                if let contents = message.body { // 含消息体
                    handleTranslateState(
                        message: message,
                        languageType: targetLanguage,
                        translatedState: .translating,
                        translateTipMessage: Localized("TRANSLATE_TIP_MESSAGE", "")
                    )
                    requestTranslateLanguage(
                        message: message,
                        sourceLanguage: nil,
                        targetLanguage: targetLanguage,
                        contents: contents,
                        attachmentId: attachmentId
                    )
                } else { // 不含消息体 直接失败
                    handleTranslateState(
                        message: message,
                        languageType: targetLanguage,
                        translatedState: .failed,
                        translateTipMessage: Localized("TRANSLATE_TIP_MESSAGE_FAILED", "")
                    )
                }
            }
        } else {
            if let contents = message.body { // 含消息体
                handleTranslateState(
                    message: message,
                    languageType: targetLanguage,
                    translatedState: .translating,
                    translateTipMessage: Localized("TRANSLATE_TIP_MESSAGE", "")
                )
                requestTranslateLanguage(
                    message: message,
                    sourceLanguage: nil,
                    targetLanguage: targetLanguage,
                    contents: contents,
                    attachmentId: nil
                )
            } else { // 不含消息体 直接失败
                handleTranslateState(
                    message: message,
                    languageType: targetLanguage,
                    translatedState: .failed,
                    translateTipMessage: Localized("TRANSLATE_TIP_MESSAGE_FAILED", "")
                )
            }
        }
    }
    
    /// 根据消息类型翻译 - 转发类型
    func translateSingleForwardMessage(
        message: TSMessage,
        forwardingMessage: DTCombinedForwardingMessage,
        conversationViewItem: ConversationViewItem,
        targetLanguage: DTTranslateMessageType
    ) {
        let attachmentStream = conversationViewItem.attachmentStream()
        var text: String?
        if let mediaURL = attachmentStream?.mediaURL(),
            let data = try? Data(contentsOf: mediaURL) {
            text = String(data: data, encoding: .utf8)
        }
        if let attachmentStream, attachmentStream.contentType == OWSMimeTypeOversizeTextMessage, let text,
           text.count > kOversizeTextMessageSizelength { //处理长文本
            handleTranslateState(
                message: message,
                languageType: targetLanguage,
                translatedState: .failed,
                translateTipMessage: Localized("TRANSLATE_TIP_MESSAGE_LONG_TEXT", "")
            )
            return
        }
        var contents = message.body
        if let forwardingContent = forwardingMessage.body, !forwardingContent.isEmpty {
            contents = forwardingContent
        }
        guard let contents, !contents.isEmpty else {
            return
        }
        handleTranslateState(
            message: message,
            languageType: targetLanguage,
            translatedState: .translating,
            translateTipMessage: Localized("TRANSLATE_TIP_MESSAGE", "")
        )
        requestTranslateLanguage(
            message: message,
            sourceLanguage: nil,
            targetLanguage: targetLanguage,
            contents: contents,
            attachmentId: nil
        )
    }
    
    /// 通过 api 翻译
    func requestTranslateLanguage(
        message: TSMessage,
        sourceLanguage: String?,
        targetLanguage: DTTranslateMessageType,
        contents: String,
        attachmentId: String? = nil
    ) {
        translateApi.sendRequest(
            withSourceLang: sourceLanguage,
            targetLang: targetLanguage,
            contents: contents,
            thread: self.thread,
            attachmentId: attachmentId ?? ""
        ) { [weak self] entity in
            
            guard let self else { return }
            
            var tmpMessage: TSMessage?
            self.databaseStorage.asyncRead(block: { transaction in
                tmpMessage = TSMessage.anyFetchMessage(
                    uniqueId: message.uniqueId,
                    transaction: transaction
                )
            }, completionQueue: .main) {
                if let tmpMessage, (tmpMessage.isKind(of: TSIncomingMessage.self) || tmpMessage.isKind(of: TSOutgoingMessage.self)) {
                    // 主要防止消息被撤回消息类型发生改变
                    let translateMessage: DTTranslateMessage = tmpMessage.translateMessage?.copy() as? DTTranslateMessage ?? DTTranslateMessage()
                    translateMessage.updateTranslateState(.sucessed)
                    let translateSingleEntity = entity.data
                    switch targetLanguage {
                    case .english:
                        translateMessage.updateTranslateType(targetLanguage)
                        translateMessage.tranEngLishResult = translateSingleEntity.translatedText
                    case .chinese:
                        translateMessage.updateTranslateType(targetLanguage)
                        translateMessage.tranChinseResult = translateSingleEntity.translatedText
                    default:
                        break
                    }
                    if !DTParamsUtils.validateString(translateSingleEntity.translatedText).boolValue {
                        translateMessage.updateTranslateType(.original)
                    }
                    self.asyncUpdateMessage(message, withTranslateMessage: translateMessage)
                } else {
                    self.handleTranslateState(
                        message: message,
                        languageType: targetLanguage,
                        translatedState: .failed,
                        translateTipMessage: message.hasAttachments() ? Localized("SPEECHTOTEXT_CONVERT_TIP_MESSAGE_FAILED", "") : Localized("TRANSLATE_TIP_MESSAGE_FAILED", "")
                    )
                }
            }
            
        } failure: { error in
            self.handleTranslateState(
                message: message,
                languageType: targetLanguage,
                translatedState: .failed,
                translateTipMessage: message.hasAttachments() ? Localized("SPEECHTOTEXT_CONVERT_TIP_MESSAGE_FAILED", "") : Localized("TRANSLATE_TIP_MESSAGE_FAILED", "")
            )
            DTToastHelper.toast(withText: message.hasAttachments() ? Localized("SPEECHTOTEXT_CONVERT_TIP_MESSAGE_FAILED", "") : Localized("TRANSLATE_TIP_MESSAGE_FAILED", ""), durationTime: 2.5)
        }

    }
    
    /// 同步翻译状态
    func handleTranslateState(
        message: TSMessage,
        languageType: DTTranslateMessageType,
        translatedState: DTTranslateMessageStateType,
        translateTipMessage: String?
    ) {
        //改操作允许离线通过更新数据库
        DatabaseOfflineManager.shared.canOfflineUpdateDatabase  = true
        databaseStorage.asyncWrite { transaction in
            let translateMessage: DTTranslateMessage  = TSMessage.anyFetchMessage(
                uniqueId: message.uniqueId,
                transaction: transaction
            )?.translateMessage ?? DTTranslateMessage()
            translateMessage.updateTranslateState(translatedState)
            translateMessage.updateTranslateType(languageType)
            translateMessage.translateTipMessage = translateTipMessage ?? .empty
            
            message.anyUpdateMessage(transaction: transaction) { messageCopy in
                messageCopy.translateMessage = translateMessage
            }
        }
    }
    
    /// 同步 translate message
    func asyncUpdateMessage(_ message: TSMessage, withTranslateMessage translateMessage: DTTranslateMessage) {
        databaseStorage.asyncWrite { writeTransaction in
            message.anyUpdateMessage(transaction: writeTransaction) { messageCopy in
                if let cardUniqueId = messageCopy.cardUniqueId, !cardUniqueId.isEmpty {
                    translateMessage.cardVersion = messageCopy.cardVersion
                }
                messageCopy.translateMessage = translateMessage
            }
        }
    }
    
    /// 修改自动翻译设置
    func changeTranslateSettingType(_ type: DTTranslateMessageType) {
        databaseStorage.write { writeTransaction in
            let upinfo = DTGroupUtils.getTranslateSettingChangedInfoString(withUserChange: type)
            if !upinfo.isEmpty {
                let now = Date.ows_millisecondTimestamp()
                let infoMessage = TSInfoMessage(
                    timestamp: now,
                    in: self.thread,
                    messageType: .typeGroupUpdate,
                    customMessage: upinfo
                )
                infoMessage.anyInsert(transaction: writeTransaction)
            }
            
            self.thread.anyUpdate(transaction: writeTransaction) { instance in
                instance.updateTranslateSettingType(type)
            }
        }
    }
    
    /// 判断当前语言是否是中文
    private var isCurrentLanguageZh: Bool {
        let languages = NSLocale.preferredLanguages
        guard let currentLanguage = languages.first, currentLanguage.contains("zh") else {
            return false
        }
        return true
    }
    
    /// 翻译 api
    private var translateApi: DTTranslateApi {
        DTTranslateProcessor.sharedInstance().translateApi
    }
}

fileprivate extension DTTranslateMessage {
    var isTranslateEnglishSuccess: Bool {
        translatedState.isEqualTo(translateState: .sucessed) &&
        !tranEngLishResult.isEmpty
    }
    
    var isTranslateChineseSuccess: Bool {
        translatedState.isEqualTo(translateState: .sucessed) &&
        !tranChinseResult.isEmpty
    }
    
    var isShowingEnglish: Bool {
        isTranslateEnglishSuccess &&
        translatedType.isEqualTo(languageType: .english)
    }
    
    var isShowingChinese: Bool {
        isTranslateChineseSuccess &&
        translatedType.isEqualTo(languageType: .chinese)
    }
    
    func updateTranslateType(_ type: DTTranslateMessageType) {
        translatedType = NSNumber(value: type.rawValue)
    }
}

fileprivate extension TSThread {
    func updateTranslateSettingType(_ type: DTTranslateMessageType) {
        translateSettingType = NSNumber(value: type.rawValue)
    }
}

fileprivate extension NSNumber {
    func isEqualTo(languageType: DTTranslateMessageType) -> Bool {
        self.intValue == languageType.rawValue
    }
    
    func isEqualTo(translateState: DTTranslateMessageStateType) -> Bool {
        self.intValue == translateState.rawValue
    }
}
