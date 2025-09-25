//
//  ConversationSystemRenderItem.swift
//  Difft
//
//  Created by Jaymin on 2024/7/12.
//  Copyright © 2024 Difft. All rights reserved.
//

import Foundation
import TTMessaging
import TTServiceKit

class ConversationSystemRenderItem: ConversationCellRenderItem {
    static let lineViewHeight: CGFloat = 1
    static let iconSize: CGFloat = 20
    static let titleStackViewSpacing: CGFloat = 9
    static let buttonHeight: CGFloat = 30
    static let buttonPadding: CGFloat = 20
    static let bottomStackViewSpacing: CGFloat = 7
    static let bottomStackViewMargin: CGFloat = 5
    static let leftIconSize: CGFloat = 11
    static let leftIconTitleStackViewSpacing: CGFloat = 3
    
    var headerRenderItem: CVSystemHeaderRenderItem?
    
    var isShowLineView = false
    var lineViewMarginLeft: CGFloat = .zero
    var lineViewMarginRight: CGFloat = .zero
    
    var icon: UIImage? = nil
    var leftIcon: UIImage? = nil
    
    var titleConfig: CVLabelConfig = .empty
    var titleSize: CGSize = .zero
    
    enum ButtonAction {
        case nonBlockingIdentityChange(recipientId: String?)
        case groupCreationFailed(errorMessage: TSErrorMessage)
        case verificationStateChange(recipientId: String)
        
        var titleConfig: CVLabelConfig {
            var title: String
            switch self {
            case .nonBlockingIdentityChange:
                title = Localized("SYSTEM_MESSAGE_ACTION_VERIFY_SAFETY_NUMBER")
            case .groupCreationFailed:
                title = CommonStrings.retryButton()
            case .verificationStateChange:
                title = Localized("SHOW_SAFETY_NUMBER_ACTION")
            }
            return .unstyledText(title, font: .ows_dynamicTypeCaption1, textAlignment: .center)
        }
    }
    var buttonAction: ButtonAction? = nil
    var actionButtonSize: CGSize = .zero
    
    var bottomStackViewLayoutMargins: UIEdgeInsets = .zero
    
    override func configure() {
        configureForHeaderView()
        configureForLineView()
        configureForIconView()
        configureForTitleLabel()
        configureForActionButton()
        
        self.bottomStackViewLayoutMargins = .init(
            top: Self.bottomStackViewMargin,
            left: conversationStyle.fullWidthGutterLeading,
            bottom: Self.bottomStackViewMargin,
            right: conversationStyle.fullWidthGutterLeading
        )
        
        self.viewSize = measureSize()
    }
    
    override func dequeueCell(for collectionView: UICollectionView, indexPath: IndexPath) -> UICollectionViewCell {
        collectionView.dequeueReusableCell(withReuseIdentifier: ConversationSystemMessageCell.reuserIdentifier, for: indexPath)
    }
    
    private func configureForHeaderView() {
        guard viewItem.hasCellHeader else {
            return
        }
        self.headerRenderItem = CVSystemHeaderRenderItem(
            viewItem: viewItem,
            conversationStyle: conversationStyle
        )
    }
    
    private func configureForLineView() {
        let isDisappearingMessagesUpdateMessage = {
            guard let interaction = viewItem.interaction as? TSInfoMessage else {
                return false
            }
            return interaction.messageType == .typeDisappearingMessagesUpdate
        }()
        if isDisappearingMessagesUpdateMessage {
            isShowLineView = true
            lineViewMarginLeft = conversationStyle.headerGutterLeading
            lineViewMarginRight = conversationStyle.headerGutterTrailing
        } else {
            isShowLineView = false
        }
    }
    
    private func configureForIconView() {
        let interaction = viewItem.interaction
        let icon: UIImage? = {
            if let errorMessage = interaction as? TSErrorMessage {
                switch errorMessage.errorType {
                case .nonBlockingIdentityChange, .wrongTrustedIdentityKey:
                    return .init(named: "system_message_security")
                default:
                    return nil
                }
            }
            if let infoMessage = interaction as? TSInfoMessage {
                switch infoMessage.messageType {
                case .verificationStateChange:
                    if let changeMessage = infoMessage as? OWSVerificationStateChangeMessage {
                        let isVerified = changeMessage.verificationState == .verified
                        if !isVerified {
                            return nil
                        }
                    }
                    return .init(named: "system_message_verified")
                default:
                    return nil
                }
            }
            return nil
        }()
        self.icon = icon?.withRenderingMode(.alwaysTemplate)
        
        let leftIcon: UIImage? = {
            if let infoMessage = interaction as? TSInfoMessage {
                switch infoMessage.messageType {
                case .reportedMessage:
                    return .init(named: "system_message_reported")
                default:
                    return nil
                }
            }
            return nil
        }()
        self.leftIcon = leftIcon?.withRenderingMode(.alwaysTemplate)
    }
    
    private func configureForTitleLabel() {
        guard let infoMessage = viewItem.interaction as? TSInfoMessage else {
            titleConfig = .unstyledText(
                viewItem.systemMessageText ?? .empty,
                font: .ows_dynamicTypeCaption1,
                numberOfLines: 0,
                textAlignment: .center
            )
            return
        }
        
        switch infoMessage.messageType {
        case .recallMessage,
                .pinMessage,
                .callEnd,
                .groupReminder,
                .userPermissionForbidden,
                .meetingReminder,
                .groupRemoveMember,
                .groupMemberChangeMeetingAlert:
            titleConfig = .attributeText(
                infoMessage.customAttributedMessage ?? NSAttributedString(string: ""),
                font: .ows_dynamicTypeCaption1,
                numberOfLines: 0,
                textAlignment: .center
            )
        case .reportedMessage:
            titleConfig = .attributeText(
                NSAttributedString(string: infoMessage.customMessage ?? "" ),
                font: .ows_dynamicTypeCaption1,
                numberOfLines: 0,
                textAlignment: .center
            )
        default:
            titleConfig = .unstyledText(
                viewItem.systemMessageText ?? .empty,
                font: .ows_dynamicTypeCaption1,
                numberOfLines: 0,
                textAlignment: .center
            )
        }
    }
    
    private func configureForActionButton() {
        buttonAction = {
            let interaction = viewItem.interaction
            if let errorMessage = interaction as? TSErrorMessage {
                return actionForErrorMessage(errorMessage)
            }
            if let infoMessage = interaction as? TSInfoMessage {
                return actionForInfoMessage(infoMessage)
            }
            return nil
        }()
    }
    
    private func actionForErrorMessage(_ message: TSErrorMessage) -> ButtonAction? {
        switch message.errorType {
        case .nonBlockingIdentityChange:
            return .nonBlockingIdentityChange(recipientId: message.recipientId)
        case .groupCreationFailed:
            return .groupCreationFailed(errorMessage: message)
        default:
            return nil
        }
    }
    
    private func actionForInfoMessage(_ message: TSInfoMessage) -> ButtonAction? {
        switch message.messageType {
        case .verificationStateChange:
            guard let changeMessage = message as? OWSVerificationStateChangeMessage else {
                return nil
            }
            return .verificationStateChange(recipientId: changeMessage.recipientId)
        default:
            return nil
        }
    }
    
    private func measureSize() -> CGSize {
        var height: CGFloat = .zero
        let maxTextWidth: CGFloat = conversationStyle.viewWidth
        
        if let headerRenderItem {
            height += headerRenderItem.viewSize.height
        }
        
        if isShowLineView {
            height += Self.lineViewHeight + Self.bottomStackViewSpacing
        }
        
        if let _ = self.icon {
            height += Self.iconSize + Self.titleStackViewSpacing
        }
        
        titleSize = titleConfig.measure(maxWidth: conversationStyle.fullWidthContentWidth)
        height += titleSize.height
        
        // TODO: Jaymin 需要验证一下如果给定的 maxWidth 大于实际文本宽度，计算出来的 size.width 是否等于文本实际占用宽度
        if let buttonAction {
            actionButtonSize = buttonAction.titleConfig.measure(maxWidth: conversationStyle.fullWidthContentWidth)
            height += Self.bottomStackViewSpacing + Self.buttonHeight
        }
        
        height += Self.bottomStackViewMargin * 2
        
        return CGSizeCeil(CGSize(width: maxTextWidth, height: height))
    }
}
