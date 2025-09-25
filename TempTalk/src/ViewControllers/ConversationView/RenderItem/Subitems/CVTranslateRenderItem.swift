//
//  CVTranslateRenderItem.swift
//  Difft
//
//  Created by Jaymin on 2024/7/25.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit

class CVTranslateRenderItem: ConversationRenderItem {
    
    static let indicatorWidth: CGFloat = 12
    static let indicatorMargin: CGFloat = 5
    static let insetTopMargin: CGFloat = 5
    static let insetMargin: CGFloat = 12
    static let textFont: UIFont = .systemFont(ofSize: 16)
    
    var translateState: DTTranslateMessageStateType?
    var translateText: String?
    var translateAttributedText: NSAttributedString?
    var displayableText: DisplayableText?
    var translateSourceText: String = .empty
    
    var isShowSourceLabel: Bool {
        // 成功的时候展示source文本
        guard translateState == .sucessed else {
            return false
        }
        // 文本的翻译不展示source
        guard viewItem.messageCellType() == .audio else {
            return false
        }
        
        guard !viewItem.hasBodyText else {
            return false
        }
        
        return true
    }
    
    var isShowMoreButton: Bool {
        guard translateState == .sucessed else {
            return false
        }
        guard viewItem.showTranslateResultText else {
            return false
        }
        guard let displayableText, displayableText.isTextTruncated else {
            return false
        }
        return true
    }
    
    var containerColor: UIColor? {
        (viewItem.interaction as? TSMessage).map {
            conversationStyle.translateColor(message: $0)
        }
    }
    
    var textColor: UIColor? {
        (viewItem.interaction as? TSMessage).map {
            conversationStyle.bubbleTranslateTextColor(message: $0)
        }
    }
    
    var sourceTextColor: UIColor? {
        (viewItem.interaction as? TSMessage).map {
            conversationStyle.bubbleTranslateSourceTextColor(message: $0)
        }
    }
    
    override func configure() {
        guard let message = viewItem.interaction as? TSMessage else {
            return
        }
        guard let translateMessage = message.translateMessage else {
            return
        }
        
        self.translateState = DTTranslateMessageStateType(rawValue: translateMessage.translatedState.intValue)
        
        if translateMessage.translateStateEqualTo(.sucessed) {
            if translateMessage.translateLanguageEqualTo(.english) {
                self.displayableText = DisplayableText.displayableText(translateMessage.tranEngLishResult)
                
            } else if translateMessage.translateLanguageEqualTo(.chinese) {
                self.displayableText = DisplayableText.displayableText(translateMessage.tranChinseResult)
            }
        }
        
        self.translateText = {
            if translateMessage.translateLanguageEqualTo(.english), !translateMessage.tranEngLishResult.isEmpty {
                self.translateState = .sucessed
                return self.displayableText?.displayText ?? translateMessage.tranEngLishResult
            }
            if translateMessage.translateLanguageEqualTo(.chinese), !translateMessage.tranChinseResult.isEmpty {
                self.translateState = .sucessed
                return self.displayableText?.displayText ?? translateMessage.tranChinseResult
            }
            if translateMessage.translateStateEqualTo(.translating) || translateMessage.translateStateEqualTo(.failed) {
                return translateMessage.translateTipMessage
            }
            return nil
        }()
        
        if let translateText = self.translateText {
            self.translateAttributedText = attributedString(for: translateText)
        }
        
        self.translateSourceText = String(format: Localized("CONVERT_SOURCE_TEXT"), TSConstants.appDisplayName)
        
        self.viewSize = measureSize()
    }
    
    private func measureSize() -> CGSize {
        guard let message = viewItem.interaction as? TSMessage,
              let translateMessage = message.translateMessage,
              !translateMessage.translateLanguageEqualTo(.original) else {
            return .zero
        }
        
        guard let translateText, !translateText.isEmpty else {
            return .zero
        }
        
        // 最大宽度需要减去上、下、左、右的 margin
        var maxWidth = floor(conversationStyle.maxMessageWidth - conversationStyle.textInsetHorizontal * 2)
        var indicatorIconWidth = Self.indicatorWidth
        
        // 翻译中和翻译失败状态需要计算 loading 的宽度
        if translateMessage.translateStateEqualTo(.translating) || translateMessage.translateStateEqualTo(.failed) {
            indicatorIconWidth = Self.indicatorWidth + Self.indicatorMargin
            maxWidth -= indicatorIconWidth
        }
        
        // 计算翻译内容尺寸
        let maxSize = CGSize(width: maxWidth, height: .greatestFiniteMagnitude)
        var size = measureStringSize(string: translateText, maxSize: maxSize)
        size.height += Self.insetTopMargin * 2
        size.width += indicatorIconWidth + 2
        
        var bottomSize = measureStringSize(string: self.translateSourceText, maxSize: maxSize)
        if bottomSize.width > size.width {
            size.width = bottomSize.width
        }
        bottomSize.height = 0
        
        size.height += bottomSize.height + Self.insetTopMargin
        size.width += conversationStyle.textInsetHorizontal * 2 + 1
        
        return CGSizeCeil(size)
    }
    
    private func measureStringSize(string: String, maxSize: CGSize) -> CGSize {
        guard !string.isEmpty else {
            return .zero
        }
        let attributedString = attributedString(for: string)
        return attributedString.boundingRect(
            with: maxSize,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        ).size
    }
    
    func attributedString(for string: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: string)
        guard !string.isEmpty else {
            return attributedString
        }
        
        let range = NSMakeRange(0, attributedString.length)
        attributedString.addAttribute(
            .font,
            value: Self.textFont,
            range: range
        )
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 2
        paragraphStyle.firstLineHeadIndent = 0
        paragraphStyle.headIndent = 0
        attributedString.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: range
        )
        
        return attributedString
    }
    
}

// MARK: -

extension CVTranslateRenderItem {
    
    enum TranslateError: Error {
        case unrecognizedLanguage
        case createTranslateMessageFailed
    }
    
    private var translateApi: DTTranslateApi {
        DTTranslateProcessor.sharedInstance().translateApi
    }
    
    var translatingAttributedText: NSAttributedString {
        let text = Localized("TRANSLATE_TIP_MESSAGE")
        return attributedString(for: text)
    }
    
    var translateFailedAttributedText: NSAttributedString {
        let text = Localized("TRANSLATE_TIP_MESSAGE_FAILED")
        return attributedString(for: text)
    }
    
    func stopTranslatingMessage() {
        guard let message = viewItem.interaction as? TSMessage else {
            return
        }
        guard let translateMessage = message.translateMessage, translateMessage.translateStateEqualTo(.translating) else {
            return
        }
        translateMessage.updateTranslateState(.failed)
        translateMessage.updateTranslateLanguage(.original)
        translateMessage.tranChinseResult = ""
        translateMessage.tranEngLishResult = ""
        
        databaseStorage.asyncWrite { transaction in
            message.anyUpdateMessage(transaction: transaction) { messageCopy in
                messageCopy.translateMessage = translateMessage
            }
        }
    }
    
    func retryTranslateFailedMessage() -> Promise<Void> {
        guard let message = viewItem.interaction as? TSMessage,
              let translateMessage = message.translateMessage,
              !translateMessage.translateStateEqualTo(.sucessed) else {
            return .value(())
        }
        guard let targetLanguage = DTTranslateMessageType(rawValue: translateMessage.translatedType.intValue) else {
            return .init(error: TranslateError.unrecognizedLanguage)
        }
        let contents = translateApi.getTargetTranferContents(message)
        return Promise { future in
            self.translateApi.sendRequest(
                withSourceLang: nil,
                targetLang: targetLanguage,
                contents: contents,
                thread: self.viewItem.thread,
                attachmentId: message.attachmentIds.first ?? ""
            ) { [weak self] entity in
                
                guard let self else { return }
                guard let translateMessage = DTTranslateMessage() else {
                    future.reject(TranslateError.createTranslateMessageFailed)
                    return
                }
                translateMessage.updateTranslateState(.sucessed)
                switch targetLanguage {
                case .english:
                    translateMessage.updateTranslateLanguage(.english)
                    translateMessage.tranEngLishResult = entity.data.translatedText
                case .chinese:
                    translateMessage.updateTranslateLanguage(.chinese)
                    translateMessage.tranChinseResult = entity.data.translatedText
                default:
                    break
                }
                self.databaseStorage.write { transaction in
                    message.anyUpdateMessage(transaction: transaction) { messageCopy in
                        messageCopy.translateMessage = translateMessage
                    }
                }
                future.resolve()
                
            } failure: { error in
                future.reject(error)
            }
        }
    }
    
}

// MARK: -

extension DTTranslateMessage {
    func translateStateEqualTo(_ state: DTTranslateMessageStateType) -> Bool {
        self.translatedState.intValue == state.rawValue
    }
    
    func translateLanguageEqualTo(_ language: DTTranslateMessageType) -> Bool {
        self.translatedType.intValue == language.rawValue
    }
    
    func updateTranslateState(_ state: DTTranslateMessageStateType) {
        self.translatedState = NSNumber(value: state.rawValue)
    }
    
    func updateTranslateLanguage(_ language: DTTranslateMessageType) {
        self.translatedType = NSNumber(value: language.rawValue)
    }
}
