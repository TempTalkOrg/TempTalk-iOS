//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

import Foundation
import UIKit

@objc
public class ConversationStyle: NSObject {

    private let thread: TSThread

    // The width of the collection view.
    @objc public var viewWidth: CGFloat = 0 {
        didSet {
            AssertIsOnMainThread()

            updateProperties()
        }
    }

    @objc public let contentMarginTop: CGFloat = 24
    @objc public let contentMarginBottom: CGFloat = 24

    @objc public var gutterLeading: CGFloat = 0
    @objc public var gutterTrailing: CGFloat = 0

    @objc public var headerGutterLeading: CGFloat = 28
    @objc public var headerGutterTrailing: CGFloat = 28
    @objc public let headerViewDateHeaderVMargin: CGFloat = 23

    // These are the gutters used by "full width" views
    // like "contact offer" and "info message".
    @objc public var fullWidthGutterLeading: CGFloat = 0
    @objc public var fullWidthGutterTrailing: CGFloat = 0

    @objc public var errorGutterTrailing: CGFloat = 0

    @objc public var contentWidth: CGFloat {
        return viewWidth - (gutterLeading + gutterTrailing)
    }

    @objc public var fullWidthContentWidth: CGFloat {
       return viewWidth - (fullWidthGutterLeading + fullWidthGutterTrailing)
    }

    @objc public var headerViewContentWidth: CGFloat {
        return viewWidth - (headerGutterLeading + headerGutterTrailing)
    }

    @objc public var maxMessageWidth: CGFloat = 0

    @objc public var textInsetTop: CGFloat = 0
    @objc public var textInsetBottom: CGFloat = 0
    @objc public var textInsetHorizontal: CGFloat = 0

    // We want to align "group sender" avatars with the v-center of the
    // "last line" of the message body text - or where it would be for
    // non-text content.
    //
    // This is the distance from that v-center to the bottom of the
    // message bubble.
    @objc public var lastTextLineAxis: CGFloat = 0

    @objc
    public required init(thread: TSThread) {

        self.thread = thread
        self.primaryColor = ConversationStyle.primaryColor(thread: thread)

        super.init()

        updateProperties()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(uiContentSizeCategoryDidChange),
                                               name: UIContentSizeCategory.didChangeNotification,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func uiContentSizeCategoryDidChange() {
        AssertIsOnMainThread()

        updateProperties()
    }

    // MARK: -

    @objc
    public func updateProperties() {
     
        gutterLeading = 40
        gutterTrailing = 12 + 16
        fullWidthGutterLeading = 16
        fullWidthGutterTrailing = 16
        headerGutterLeading = 28
        headerGutterTrailing = 28
        errorGutterTrailing = 16

        maxMessageWidth = floor(contentWidth)

        let messageTextFont = UIFont.ows_dynamicTypeBody

        let baseFontOffset: CGFloat = 11

        // Don't include the distance from the "cap height" to the top of the UILabel
        // in the top margin.
//        textInsetTop = max(0, round(baseFontOffset - (messageTextFont.ascender - messageTextFont.capHeight)))
        // Don't include the distance from the "baseline" to the bottom of the UILabel
        // (e.g. the descender) in the top margin. Note that UIFont.descender is a
        // negative value.
//        textInsetBottom = max(0, round(baseFontOffset - abs(messageTextFont.descender)))

//        if _isDebugAssertConfiguration(), UIFont.ows_dynamicTypeBody.pointSize == 17 {
//            assert(textInsetTop == 7)
//            assert(textInsetBottom == 7)
//        }

        textInsetTop = 10
        textInsetBottom = 10
        textInsetHorizontal = 12

        lastTextLineAxis = CGFloat(round(baseFontOffset + messageTextFont.capHeight * 0.5))

        self.primaryColor = ConversationStyle.primaryColor(thread: thread)
    }

    // MARK: Colors

    private class func primaryColor(thread: TSThread) -> UIColor {
        //TODO Open annotation
        /*
        guard let colorName = thread.conversationColorName else {
            return self.defaultBubbleColorIncoming
        }

        guard let color = UIColor.ows_conversationColor(colorName: colorName) else {
            return self.defaultBubbleColorIncoming
        }

        return color
        */
        return self.defaultBubbleColorIncoming
    }

    @objc
    public static var defaultBubbleColorIncoming: UIColor {
        Theme.conversationInputBackgroundColor
    }
    @objc
    public static var defaultTransltateColorIncoming: UIColor {
        Theme.translateBackgroundColor
    }

    @objc
    public var bubbleColorOutgoingFailed: UIColor { Theme.bubleOutgoingBackgroundColor }

    @objc
    public var bubbleColorOutgoingSending: UIColor { Theme.bubleOutgoingBackgroundColor }

    @objc
    public var bubbleColorOutgoingSent: UIColor { Theme.bubleOutgoingBackgroundColor }
    
    @objc
    public let bubbleColorOutgoingTranslateSent = UIColor.ows_darkSkyBlueTranslate

    @objc
    public let dateBreakTextColor = UIColor.ows_light60

    @objc
    public var primaryColor: UIColor

    @objc
    public func bubbleColor(message: TSMessage) -> UIColor {
        if message is TSIncomingMessage {
            return ConversationStyle.defaultBubbleColorIncoming
        } else if let outgoingMessage = message as? TSOutgoingMessage {
            switch outgoingMessage.messageState {
            case .failed:
                return bubbleColorOutgoingFailed
            case .sending:
                return bubbleColorOutgoingSending
            default:
                return bubbleColorOutgoingSent
            }
        } else {
            owsFailDebug("Unexpected message type: \(message)")
            return bubbleColorOutgoingSent
        }
    }
    @objc
    public func translateColor(message: TSMessage) -> UIColor {
        if message is TSIncomingMessage {
            return ConversationStyle.defaultTransltateColorIncoming
        } else if  message is TSOutgoingMessage {
            return ConversationStyle.defaultTransltateColorIncoming
        } else {
            owsFailDebug("Unexpected message type: \(message)")
            return bubbleColorOutgoingSent
        }
    }

    @objc
    public func bubbleColor(isIncoming: Bool) -> UIColor {
        if isIncoming {
            return ConversationStyle.defaultBubbleColorIncoming
        } else {
            return self.bubbleColorOutgoingSent
        }
    }

    @objc
    public static var bubbleTextColorIncoming : UIColor {
        return Theme.isDarkThemeEnabled ? UIColor(rgbHex: 0xEAECEF) : UIColor(rgbHex: 0x1E2329)
    }
     
    @objc
    public static var bubbleTextColorOutgoing : UIColor {
        return Theme.isDarkThemeEnabled ? UIColor(rgbHex: 0xEAECEF) : UIColor(rgbHex: 0x1E2329)
    }
    
    @objc
    public static var bubbleTranslateTextColorIncoming : UIColor {
        return Theme.isDarkThemeEnabled ? UIColor.ows_whiteAlpha70 : UIColor.ows_gray90
    }
    
    @objc
    public static var bubbleTranslateTextColorOutgoing : UIColor {
        return Theme.isDarkThemeEnabled ? UIColor.ows_whiteAlpha70 : UIColor.ows_gray90
    }
    
    @objc
    public static var bubbleTranslateSourceTextColorIncoming : UIColor {
        return Theme.isDarkThemeEnabled ? UIColor.ows_gray45 : UIColor.ows_gray45
    }
    
    @objc
    public static var bubbleTranslateSourceTextColoroutgoing : UIColor {
        return Theme.isDarkThemeEnabled ? UIColor.ows_gray45 : UIColor.ows_gray45
    }
    @objc
    public static var bubbleIndicatorImageViewTintTextColorOutgoing : UIColor {
        return Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xD1D1D2) : UIColor.ows_gray45
    }
    @objc
    public static var bubbleIndicatorImageViewTintTextColorIncoming : UIColor {
        return Theme.isDarkThemeEnabled ?  UIColor.color(rgbHex: 0xD1D1D2) : UIColor.ows_gray45
    }
    
    @objc
    public func bubbleTextColor(message: TSMessage) -> UIColor {
        if message is TSIncomingMessage {
            return ConversationStyle.bubbleTextColorIncoming
        } else if message is TSOutgoingMessage {
            return ConversationStyle.bubbleTextColorOutgoing
        } else {
            owsFailDebug("Unexpected message type: \(message)")
            return ConversationStyle.bubbleTextColorOutgoing
        }
    }
    @objc
    public func bubbleTranslateTextColor(message: TSMessage) -> UIColor {
        if message is TSIncomingMessage {
            return ConversationStyle.bubbleTranslateTextColorIncoming
        } else if message is TSOutgoingMessage {
            return ConversationStyle.bubbleTranslateTextColorOutgoing
        } else {
            owsFailDebug("Unexpected message type: \(message)")
            return ConversationStyle.bubbleTextColorOutgoing
        }
    }
    
    @objc
    public func bubbleTranslateSourceTextColor(message: TSMessage) -> UIColor {
        if message is TSIncomingMessage {
            return ConversationStyle.bubbleTranslateSourceTextColorIncoming
        } else if message is TSOutgoingMessage {
            return ConversationStyle.bubbleTranslateSourceTextColoroutgoing
        } else {
            owsFailDebug("Unexpected message type: \(message)")
            return ConversationStyle.bubbleTextColorOutgoing
        }
    }
    @objc
    public func bubbleStatusIndicatorImageViewTintColor(message: TSMessage) -> UIColor {
        if message is TSIncomingMessage {
            return ConversationStyle.bubbleIndicatorImageViewTintTextColorIncoming
        } else if message is TSOutgoingMessage {
            return ConversationStyle.bubbleIndicatorImageViewTintTextColorOutgoing
        } else {
            owsFailDebug("Unexpected message type: \(message)")
            return ConversationStyle.bubbleTextColorOutgoing
        }
    }
    
    
    @objc
    public func bubbleTextColor(isIncoming: Bool) -> UIColor {
        if isIncoming {
            return ConversationStyle.bubbleTextColorIncoming
        } else {
            return ConversationStyle.bubbleTextColorOutgoing
        }
    }

    @objc
    public func bubbleSecondaryTextColor(isIncoming: Bool) -> UIColor {
        return bubbleTextColor(isIncoming: isIncoming).withAlphaComponent(0.7)
    }

    @objc
    public func quotedReplyBubbleColor(isIncoming: Bool) -> UIColor {
        if isIncoming {
            return bubbleColorOutgoingSent.withAlphaComponent(0.25)
        } else {
            return ConversationStyle.defaultBubbleColorIncoming.withAlphaComponent(0.75)
        }
    }

    @objc
    public func quotedReplyStripeColor(isIncoming: Bool) -> UIColor {
        if isIncoming {
            return bubbleColorOutgoingSent
        } else {
            return Theme.isDarkThemeEnabled ? UIColor.ows_gray90 : UIColor.ows_whiteAlpha80
        }
    }

    @objc
    public func quotingSelfHighlightColor() -> UIColor {
        // TODO:
        return UIColor.init(rgbHex: 0xB5B5B5)
    }

    @objc
    public func quotedReplyAuthorColor() -> UIColor {
        replyTextColor()
    }
    
    @objc
    public func topicReplyAuthorColor() -> UIColor {
        replyTextColor()
    }


    @objc
    public func replyTextColor() -> UIColor {
        Theme.isDarkThemeEnabled ? UIColor.color(rgbHex: 0xB7BDC6) : UIColor.color(rgbHex: 0x474D57)
    }

    @objc
    public func quotedReplyAttachmentColor() -> UIColor {
        Theme.isDarkThemeEnabled ? .ows_gray15 : UIColor.ows_gray90
    }
    
    public func deepCopy() -> ConversationStyle {
        return ConversationStyle(thread: self.thread)
    }
}
