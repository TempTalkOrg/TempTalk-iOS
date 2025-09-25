//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "ConversationViewItem.h"
#import "OWSAudioMessageView.h"
#import "OWSMessageHeaderView.h"
#import "TempTalk-Swift.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <SignalCoreKit/NSString+OWS.h>
#import <TTMessaging/OWSUnreadIndicator.h>
#import <TTServiceKit/OWSContact.h>
#import <TTServiceKit/TSInteraction.h>
#import <CoreServices/CoreServices.h>
#import <TTMessaging/ThreadUtil.h>

NS_ASSUME_NONNULL_BEGIN

NSString *NSStringForOWSMessageCellType(OWSMessageCellType cellType)
{
    switch (cellType) {
        case OWSMessageCellType_TextMessage:
            return @"OWSMessageCellType_TextMessage";
        case OWSMessageCellType_OversizeTextMessage:
            return @"OWSMessageCellType_OversizeTextMessage";
        case OWSMessageCellType_StillImage:
            return @"OWSMessageCellType_StillImage";
        case OWSMessageCellType_AnimatedImage:
            return @"OWSMessageCellType_AnimatedImage";
        case OWSMessageCellType_Audio:
            return @"OWSMessageCellType_Audio";
        case OWSMessageCellType_Video:
            return @"OWSMessageCellType_Video";
        case OWSMessageCellType_GenericAttachment:
            return @"OWSMessageCellType_GenericAttachment";
        case OWSMessageCellType_DownloadingAttachment:
            return @"OWSMessageCellType_DownloadingAttachment";
        case OWSMessageCellType_Unknown:
            return @"OWSMessageCellType_Unknown";
        case OWSMessageCellType_ContactShare:
            return @"OWSMessageCellType_ContactShare";
        case OWSMessageCellType_Card:
            return @"OWSMessageCellType_Card";
        case OWSMessageCellType_CombinedForwarding:
            return @"OWSMessageCellType_CombinedForwarding";
    }
}

@interface DTWeakRefrence : NSObject

@property (nonatomic, weak, readonly, nullable) id obj;

- (instancetype)initWithObj:(nonnull id)obj;

@end

@implementation DTWeakRefrence

- (instancetype)initWithObj:(id)obj {
    if (self = [super init]) {
        _obj = obj;
    }
    return self;
}

@end

#pragma mark -

@interface ConversationInteractionViewItem ()

#pragma mark - OWSAudioPlayerDelegate

@property (nonatomic) AudioPlaybackState audioPlaybackState;
@property (nonatomic) CGFloat audioProgressSeconds;
@property (nonatomic) CGFloat audioDurationSeconds;
@property (nonatomic) NSMutableArray<DTWeakRefrence *> *audioMessageViews;

#pragma mark - View State

@property (nonatomic) BOOL hasViewState;
@property (nonatomic) OWSMessageCellType messageCellType;
@property (nonatomic, nullable) DisplayableText *displayableBodyText;
@property (nonatomic, nullable) DisplayableText *displayableQuotedText;
@property (nonatomic, nullable) OWSQuotedReplyModel *quotedReply;
@property (nonatomic, readonly, nullable) NSString *quotedAttachmentMimetype;
@property (nonatomic, readonly, nullable) NSString *quotedRecipientId;
@property (nonatomic, nullable) TSAttachmentStream *attachmentStream;
@property (nonatomic, nullable) TSAttachmentPointer *attachmentPointer;
@property (nonatomic, nullable) ContactShareViewModel *contactShare;
@property (nonatomic, nullable) NSArray <DTMention *> *mentions;
@property (nonatomic) CGSize mediaSize;
@property (nonatomic, nullable) DTCombinedForwardingMessage *combinedForwardingMessage;
@property (nonatomic, nullable) DTCombinedForwardingMessage *combinedSubMessage;

@property (nonatomic, nullable) NSString *systemMessageText;
// 长文本（转附件文本）长度
@property (nonatomic, assign) NSUInteger oversizeTextLength;

@end

#pragma mark -

@implementation ConversationInteractionViewItem

@synthesize interaction = _interaction;
@synthesize thread = _thread;
@synthesize avatar = _avatar;
@synthesize displayName = _displayName;
@synthesize conversationStyle = _conversationStyle;
@synthesize conversationViewMode = _conversationViewMode;
@synthesize didCellMediaFailToLoad = _didCellMediaFailToLoad;
@synthesize isFirstInCluster = _isFirstInCluster;
@synthesize isLastInCluster = _isLastInCluster;
@synthesize isUseForMessageList = _isUseForMessageList;
@synthesize senderName = _senderName;
@synthesize shouldHideFooter = _shouldHideFooter;
@synthesize shouldShowDate = _shouldShowDate;
@synthesize shouldShowSenderAvatar = _shouldShowSenderAvatar;
@synthesize unreadIndicator = _unreadIndicator;
@synthesize emojiTitles = _emojiTitles;
@synthesize card = _card;
@synthesize cardAttrString = _cardAttrString;
@synthesize gifElements = _gifElements;
@synthesize needsUpdate = _needsUpdate;
@synthesize hadAutoDownloaded = _hadAutoDownloaded;
@synthesize hasAutoRetryTranslate = _hasAutoRetryTranslate;

- (instancetype)initWithInteraction:(TSInteraction *)interaction
                             thread:(TSThread *)thread
               conversationViewMode:(ConversationViewMode) conversationViewMode
                        transaction:(SDSAnyReadTransaction *)transaction
                  conversationStyle:(ConversationStyle *)conversationStyle
{
    OWSAssertDebug(interaction);
    OWSAssertDebug(transaction);
    OWSAssertDebug(conversationStyle);

    self = [super init];

    if (!self) {
        return self;
    }

    _interaction = interaction;
    _thread = thread;
    _conversationStyle = conversationStyle;
    _conversationViewMode = conversationViewMode;
    _audioMessageViews = @[].mutableCopy;
    [self ensureViewState:transaction];
    
    return self;
}

#pragma mark - Dependencies

- (OWSContactsManager *)contactsManager
{
    return Environment.shared.contactsManager;
}

- (void)replaceInteraction:(TSInteraction *)interaction transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(interaction);

    _interaction = interaction;

    self.hasViewState = NO;
    self.messageCellType = OWSMessageCellType_Unknown;
    self.displayableBodyText = nil;
    self.attachmentStream = nil;
    self.attachmentPointer = nil;
    self.mediaSize = CGSizeZero;
    self.displayableQuotedText = nil;
    self.quotedReply = nil;
    self.combinedForwardingMessage = nil;
    self.systemMessageText = nil;

    [self clearCachedLayoutState];

    [self ensureViewState:transaction];
}

- (NSString *)itemId {
    return self.interaction.uniqueId;
}

- (BOOL)isGroupThread {
    return self.thread.isGroupThread;
}

- (BOOL)hasBodyText
{
    return _displayableBodyText != nil;
}

//是否展示翻译的结果
- (BOOL)showTranslateResultText
{
    if (![self.interaction isKindOfClass:TSMessage.class]) {
        return NO;
    }
    TSMessage *message = (TSMessage *)self.interaction;
    if (!message.translateMessage) {
        return NO;
    }
    DTTranslateMessage *translateMessage = message.translateMessage;
    if (translateMessage && [translateMessage.translatedType intValue]  == DTTranslateMessageTypeChinese && translateMessage.tranChinseResult.length) {
        return YES;
    }
    if (translateMessage && [translateMessage.translatedType intValue]  == DTTranslateMessageTypeEnglish && translateMessage.tranEngLishResult.length) {
        return YES;
    }
    
    return NO;
}

- (BOOL)hasQuotedText
{
    return _displayableQuotedText != nil;
}

- (BOOL)hasQuotedAttachment
{
    return self.quotedAttachmentMimetype.length > 0;
}

- (BOOL)isQuotedReply
{
    return self.hasQuotedAttachment || self.hasQuotedText;
}

- (BOOL)isCombindedForwardMessage
{
    return self.combinedForwardingMessage && self.combinedForwardingMessage.subForwardingMessages.count > 0;
}

- (BOOL)isSingleForward {
    return self.combinedForwardingMessage && self.combinedForwardingMessage.subForwardingMessages.count == 1;
}

- (BOOL)hasPerConversationExpiration
{
    if (self.interaction.interactionType != OWSInteractionType_OutgoingMessage
        && self.interaction.interactionType != OWSInteractionType_IncomingMessage) {
        return NO;
    }

    TSMessage *message = (TSMessage *)self.interaction;
    return message.hasPerConversationExpiration;
}

- (BOOL)shouldShowTranslateView {
    TSMessage *tmpmessage  = (TSMessage *)self.interaction;
    if (tmpmessage.translateMessage.translatedType.intValue != DTTranslateMessageTypeOriginal ) {
        return true;
    } else {
        return false;
    }
}

- (BOOL)hasCellHeader
{
    return self.shouldShowDate || self.unreadIndicator;
}

- (BOOL)canShowTranslateAction {
    return true;
}

- (BOOL)showTranslateAction {
    if (![self.interaction isKindOfClass:[TSMessage class]]) {return false;}
    TSMessage *message = (TSMessage *)self.interaction;
    if (message.translateMessage && [message.translateMessage.translatedState isEqual:@(DTTranslateMessageStateTypeSucessed)] ) {
        if(![message.translateMessage.translatedType isEqual:@(DTTranslateMessageTypeOriginal)]){
            return false;
        }
    }
    return true;
}

- (void)setConversationViewMode:(ConversationViewMode)conversationViewMode {
    _conversationViewMode = conversationViewMode;
}

- (void)setDisplayName:(NSString *)displayName {
    if ([_displayName isEqualToString:displayName]) {
        return;
    }
    
    _displayName = displayName;
}

- (void)setAvatar:(NSDictionary *)avatar {
    if ([_avatar isEqual:avatar]) {
        return;
    }
    
    _avatar = avatar;
}

- (void)setShouldShowDate:(BOOL)shouldShowDate
{
    if (_shouldShowDate == shouldShowDate) {
        return;
    }

    _shouldShowDate = shouldShowDate;

    [self clearCachedLayoutState];
}

- (void)setShouldShowSenderAvatar:(BOOL)shouldShowSenderAvatar
{
    if (_shouldShowSenderAvatar == shouldShowSenderAvatar) {
        return;
    }

    _shouldShowSenderAvatar = shouldShowSenderAvatar;

    [self clearCachedLayoutState];
}

- (void)setSenderName:(nullable NSAttributedString *)senderName
{
    if ([NSObject isNullableObject:senderName equalTo:_senderName]) {
        return;
    }

    _senderName = senderName;

    [self clearCachedLayoutState];
}

- (void)setShouldHideFooter:(BOOL)shouldHideFooter
{
    if (_shouldHideFooter == shouldHideFooter) {
        return;
    }

    _shouldHideFooter = shouldHideFooter;

    [self clearCachedLayoutState];
}

- (void)setIsFirstInCluster:(BOOL)isFirstInCluster
{
    if (_isFirstInCluster == isFirstInCluster) {
        return;
    }
    
    _isFirstInCluster = isFirstInCluster;
    
    [self setNeedsUpdate];
}

- (void)setIsLastInCluster:(BOOL)isLastInCluster
{
    if (_isLastInCluster == isLastInCluster) {
        return;
    }
    
    _isLastInCluster = isLastInCluster;
    
    [self setNeedsUpdate];
}

- (void)setUnreadIndicator:(nullable OWSUnreadIndicator *)unreadIndicator
{
    if ([NSObject isNullableObject:_unreadIndicator equalTo:unreadIndicator]) {
        return;
    }

    _unreadIndicator = unreadIndicator;

    [self clearCachedLayoutState];
}

- (void)clearCachedLayoutState
{
    // Any change which requires relayout requires cell update.
    [self setNeedsUpdate];
}

- (void)clearNeedsUpdate
{
    _needsUpdate = NO;
}

- (void)setNeedsUpdate
{
    _needsUpdate = YES;
}

- (ConversationCell *)dequeueCellForCollectionView:(UICollectionView *)collectionView
                                             indexPath:(NSIndexPath *)indexPath
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(collectionView);
    OWSAssertDebug(indexPath);
    OWSAssertDebug(self.interaction);

    switch (self.interaction.interactionType) {
        case OWSInteractionType_Unknown:
        case OWSInteractionType_Offer:
            OWSFailDebug(@"%@ Unknown interaction type.", self.logTag);
            return [collectionView dequeueReusableCellWithReuseIdentifier:[ConversationUnknownCell reuserIdentifier]
                                                                    forIndexPath:indexPath];
        case OWSInteractionType_IncomingMessage:
            return [collectionView dequeueReusableCellWithReuseIdentifier:[ConversationIncomingMessageCell reuseIdentifier]
                                                             forIndexPath:indexPath];
        case OWSInteractionType_OutgoingMessage:
            return [collectionView dequeueReusableCellWithReuseIdentifier:[ConversationOutgoingMessageCell reuseIdentifier]
                                                             forIndexPath:indexPath];
        case OWSInteractionType_Error:
        case OWSInteractionType_Info:
            return [collectionView dequeueReusableCellWithReuseIdentifier:[ConversationSystemMessageCell reuserIdentifier]
                                                             forIndexPath:indexPath];
        case OWSInteractionType_UnreadIndicator:
            return [collectionView dequeueReusableCellWithReuseIdentifier:[ConversationUnreadIndicatorCell reuserIdentifier]
                                                             forIndexPath:indexPath];
            break;
    }
}

#pragma mark - OWSAudioPlayerDelegate

- (void)associateAudioMessageView:(OWSAudioMessageView *)audioMessageView
{
    NSArray *oldArray = [self.audioMessageViews copy];
    for (DTWeakRefrence *refrence in oldArray) {
        if (refrence.obj == nil || ![refrence.obj isKindOfClass:[OWSAudioMessageView class]]) {
            [self.audioMessageViews removeObject:refrence];
        }
    }
    DTWeakRefrence *refrence = [[DTWeakRefrence alloc] initWithObj:audioMessageView];
    [self.audioMessageViews addObject:refrence];
}

- (void)setAudioPlaybackState:(AudioPlaybackState)audioPlaybackState
{
    _audioPlaybackState = audioPlaybackState;

    NSArray *messageViews = [self.audioMessageViews copy];
    for (DTWeakRefrence *refrence in messageViews) {
        if (refrence.obj != nil && [refrence.obj isKindOfClass:[OWSAudioMessageView class]]) {
            OWSAudioMessageView *audioView = (OWSAudioMessageView *)refrence.obj;
            if (audioView.superview != nil && audioView.window != nil) {
                [audioView updateContents];
            }
        }
    }
    
    if (audioPlaybackState == AudioPlaybackState_Stopped ||
        audioPlaybackState == AudioPlaybackState_Paused) {
        OWSLogDebug(@"voice paused or stopped to rm.");
        if (self.attachmentStream.isVoiceMessage) {
            [self.attachmentStream removeVoicePlaintextFile];
        }
    }
}

- (void)setAudioProgress:(CGFloat)progress duration:(CGFloat)duration
{
    OWSAssertIsOnMainThread();

    self.audioProgressSeconds = progress;

    NSArray *messageViews = [self.audioMessageViews copy];
    for (DTWeakRefrence *refrence in messageViews) {
        if (refrence.obj != nil && [refrence.obj isKindOfClass:[OWSAudioMessageView class]]) {
            OWSAudioMessageView *audioView = (OWSAudioMessageView *)refrence.obj;
            if (audioView.superview != nil && audioView.window != nil) {
                [audioView updateContents];
            }
        }
    }
}

#pragma mark - Displayable Text

// TODO: Now that we're caching the displayable text on the view items,
//       I don't think we need this cache any more.
- (NSCache *)displayableTextCache
{
    static NSCache *cache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cache = [NSCache new];
        // Cache the results for up to 1,000 messages.
        cache.countLimit = 1000;
    });
    return cache;
}

- (DisplayableText *)displayableBodyTextForText:(NSString *)text interactionId:(NSString *)interactionId
{
    OWSAssertDebug(text);
    OWSAssertDebug(interactionId.length > 0);

    NSString *displayableTextCacheKey = [@"body-" stringByAppendingString:interactionId];

    return [self displayableTextForCacheKey:displayableTextCacheKey
                                  textBlock:^{
                                      return text;
                                  }];
}

- (DisplayableText *)displayableBodyTextForOversizeTextAttachment:(TSAttachmentStream *)attachmentStream
                                                    interactionId:(NSString *)interactionId
{
    OWSAssertDebug(attachmentStream);
    OWSAssertDebug(interactionId.length > 0);

    NSString *displayableTextCacheKey = [@"oversize-body-" stringByAppendingString:interactionId];

    return [self displayableTextForCacheKey:displayableTextCacheKey
                                  textBlock:^{
                                      NSData *textData = [NSData dataWithContentsOfURL:attachmentStream.mediaURL];
                                      NSString *text =
                                          [[NSString alloc] initWithData:textData encoding:NSUTF8StringEncoding];
                                      return text;
                                  }];
}

- (DisplayableText *)displayableQuotedTextForText:(NSString *)text interactionId:(NSString *)interactionId
{
    OWSAssertDebug(text);
    OWSAssertDebug(interactionId.length > 0);

    self.oversizeTextLength = text.length;
    NSString *displayableTextCacheKey = [@"quoted-" stringByAppendingString:interactionId];

    return [self displayableTextForCacheKey:displayableTextCacheKey
                                  textBlock:^{
                                      return text;
                                  }];
}

- (DisplayableText *)displayableTextForCacheKey:(NSString *)displayableTextCacheKey
                                      textBlock:(NSString * (^_Nonnull)(void))textBlock
{
    OWSAssertDebug(displayableTextCacheKey.length > 0);

    DisplayableText *_Nullable displayableText = [[self displayableTextCache] objectForKey:displayableTextCacheKey];
    if (!displayableText) {
        NSString *text = textBlock();
        displayableText = [DisplayableText displayableText:text];
        [[self displayableTextCache] setObject:displayableText forKey:displayableTextCacheKey];
    }
    return displayableText;
}

#pragma mark - View State

- (nullable TSAttachment *)firstAttachmentIfAnyOfMessage:(TSMessage *)message
                                             transaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(transaction);

    BOOL messageAttachmentExist = message.attachmentIds.count > 0;
    BOOL forwardMessageAttachmentExist = NO;
    if (self.isCombindedForwardMessage) {
        forwardMessageAttachmentExist = message.combinedForwardingMessage.subForwardingMessages.firstObject.forwardingAttachmentIds.count > 0;
    }
    if (!messageAttachmentExist && !forwardMessageAttachmentExist) {
        return nil;
    }
    NSString *_Nullable attachmentId = nil;
    if (messageAttachmentExist) {
        attachmentId = message.attachmentIds.firstObject;
    }
    if (forwardMessageAttachmentExist) {
        attachmentId = message.combinedForwardingMessage.subForwardingMessages.firstObject.forwardingAttachmentIds.firstObject;
    }
    
    if (attachmentId.length == 0) {
        return nil;
    }
    return [TSAttachment anyFetchWithUniqueId:attachmentId transaction:transaction];
}

- (void)ensureViewState:(nullable SDSAnyReadTransaction *)transaction
{
    OWSAssertIsOnMainThread();
    OWSAssertDebug(transaction);
    OWSAssertDebug(!self.hasViewState);
        
    switch (self.interaction.interactionType) {
        case OWSInteractionType_Unknown:
        case OWSInteractionType_Offer:
        case OWSInteractionType_UnreadIndicator:
            return;
        case OWSInteractionType_Error:
        case OWSInteractionType_Info:
            self.systemMessageText = [self systemMessageTextWithTransaction:transaction];
//            OWSAssertDebug(self.systemMessageText.length > 0);
            if (!self.systemMessageText.length) {
                OWSLogError(@"systemMessageText.length = 0");
            }
            return;
        case OWSInteractionType_IncomingMessage:
            {
                TSIncomingMessage *message = (TSIncomingMessage *)self.interaction;
                NSString *authorId = [message messageAuthorId];
                SignalAccount *account = [self.contactsManager signalAccountForRecipientId:authorId transaction:transaction];
                self.avatar = account.contact.avatar;
                self.displayName = account.contactFullName;
            }
            break;
        case OWSInteractionType_OutgoingMessage:
        {
            NSString *authorId = [[TSAccountManager shared] localNumberWithTransaction:transaction];
            SignalAccount *account = [self.contactsManager signalAccountForRecipientId:authorId transaction:transaction];
            self.avatar = account.contact.avatar;
            self.displayName = account.contactFullName;
        }
            break;
        default:
            OWSFailDebug(@"Unknown interaction type.");
            return;
    }
    
    if (![self.interaction isKindOfClass:[TSOutgoingMessage class]]
        && ![self.interaction isKindOfClass:[TSIncomingMessage class]]) {
        // Only text & attachment messages have "view state".
        return;
    }

    self.hasViewState = YES;

    TSMessage *message = (TSMessage *)self.interaction;
    if (message.mentions) {
        self.mentions = message.mentions;
    }
    
//    self.emojiTitles = [DTReactionHelper emojiTitlesForMessage:message displayForBubble:YES transaction:transaction];
    
    self.combinedForwardingMessage = message.combinedForwardingMessage;
    if(self.combinedForwardingMessage){
        [self ensureCombinedForwardingMessage:self.combinedForwardingMessage transaction:transaction];
    }
    if (message.combinedForwardingMessage && (message.combinedForwardingMessage.subForwardingMessages.count > 1 || (message.combinedForwardingMessage.subForwardingMessages.count == 1 && message.combinedForwardingMessage.subForwardingMessages[0].subForwardingMessages.count > 0))) {
        self.messageCellType = OWSMessageCellType_CombinedForwarding;
        return;
    }
    if (message.contactShare) {
        self.contactShare =
            [[ContactShareViewModel alloc] initWithContactShareRecord:message.contactShare transaction:transaction];
        self.messageCellType = OWSMessageCellType_ContactShare;
        return;
    }
    if (message.card) {
        self.card = message.card;
        NSString *messageBody = message.body;
        if(DTParamsUtils.validateString(message.cardUniqueId)){
            DTCardMessageEntity *latestCard = [DTCardMessageEntity anyFetchWithUniqueId:message.cardUniqueId
                                                                            transaction:transaction];
            if(latestCard && latestCard.version > self.card.version){
//                self.card = latestCard;
                messageBody = latestCard.content;
            }
        }
        self.displayableBodyText = [self displayableBodyTextForText:messageBody interactionId:message.uniqueId ?: [NSString stringWithFormat:@"%lld", message.timestamp]];
        self.messageCellType = OWSMessageCellType_Card;
        return;
    }
    if (message.combinedForwardingMessage.subForwardingMessages.count == 1) {
        if (message.combinedForwardingMessage.subForwardingMessages.firstObject.card) {
            self.card = message.combinedForwardingMessage.subForwardingMessages.firstObject.card;
            self.displayableBodyText = [self displayableBodyTextForText:message.body interactionId:message.uniqueId ?: [NSString stringWithFormat:@"%lld", message.timestamp]];
            self.messageCellType = OWSMessageCellType_Card;
            return;
        } else if (DTParamsUtils.validateArray(message.combinedForwardingMessage.subForwardingMessages.firstObject.forwardingMentions)) {
            self.mentions = message.combinedForwardingMessage.subForwardingMessages.firstObject.forwardingMentions;
        }
    }
    
//    if(message.combinedForwardingMessage.subForwardingMessages.count == 1 &&
//       message.combinedForwardingMessage.subForwardingMessages.firstObject.card){
//        self.card = message.combinedForwardingMessage.subForwardingMessages.firstObject.card;
//        self.displayableBodyText = [self displayableBodyTextForText:message.body interactionId:message.uniqueId ?: [NSString stringWithFormat:@"%lld", message.timestamp]];
//        self.messageCellType = OWSMessageCellType_Card;
//        return;
//    }
    TSAttachment *_Nullable attachment = [self firstAttachmentIfAnyOfMessage:message transaction:transaction];
    if (attachment) {
        if ([attachment isKindOfClass:[TSAttachmentStream class]]) {
            self.attachmentStream = (TSAttachmentStream *)attachment;

            if ([attachment.contentType isEqualToString:OWSMimeTypeOversizeTextMessage]) {
                self.messageCellType = OWSMessageCellType_OversizeTextMessage;
                self.displayableBodyText = [self displayableBodyTextForOversizeTextAttachment:self.attachmentStream
                                                                                interactionId:message.uniqueId];
                
            } else if ([self.attachmentStream isAnimated] || [self.attachmentStream isImage] ||
                [self.attachmentStream isVideo]) {
                if ([self.attachmentStream isAnimated]) {
                    self.messageCellType = OWSMessageCellType_AnimatedImage;
                } else if ([self.attachmentStream isImage]) {
                    self.messageCellType = OWSMessageCellType_StillImage;
                } else if ([self.attachmentStream isVideo]) {
                    self.messageCellType = OWSMessageCellType_Video;
                } else {
                    OWSFailDebug(@"%@ unexpected attachment type.", self.logTag);
                    self.messageCellType = OWSMessageCellType_GenericAttachment;
                    return;
                }
                self.mediaSize = [self.attachmentStream imageSize];
                if (self.mediaSize.width <= 0 || self.mediaSize.height <= 0) {
                    self.messageCellType = OWSMessageCellType_GenericAttachment;
                }
            } else if ([self.attachmentStream isAudio]) {
                if (self.attachmentStream.isVoiceMessage) {
                    [self.attachmentStream removeVoicePlaintextFile];
                }
                CGFloat audioDurationSeconds = [self.attachmentStream audioDurationSeconds];
                if (audioDurationSeconds > 0) {
                    self.audioDurationSeconds = audioDurationSeconds;
                    self.messageCellType = OWSMessageCellType_Audio;
                } else {
                    self.messageCellType = OWSMessageCellType_GenericAttachment;
                }
            } else {
                self.messageCellType = OWSMessageCellType_GenericAttachment;
            }
        } else if ([attachment isKindOfClass:[TSAttachmentPointer class]]) {
            self.messageCellType = OWSMessageCellType_DownloadingAttachment;
            self.attachmentPointer = (TSAttachmentPointer *)attachment;
        } else {
            OWSFailDebug(@"%@ Unknown attachment type", self.logTag);
        }
    }

    BOOL containSignleTextCombinedMessage = NO;
    if (message.combinedForwardingMessage.subForwardingMessages.count > 0) {
        NSString *subMessageBody = message.combinedForwardingMessage.subForwardingMessages.firstObject.body;
        if (subMessageBody && subMessageBody.length > 0) {
            containSignleTextCombinedMessage = YES;
        }
    }
    
    // Ignore message body for oversize text attachments
    if (((message.body.length > 0 && !message.combinedForwardingMessage) || containSignleTextCombinedMessage) && self.messageCellType != OWSMessageCellType_OversizeTextMessage) {
        if (self.hasBodyText) {
            OWSLogError(@"%@ oversize text message has unexpected caption.", self.logTag);
        }

        // If we haven't already assigned an attachment type at this point, message.body isn't a caption,
        // it's a stand-alone text message.
        if (self.messageCellType == OWSMessageCellType_Unknown) {
            OWSAssertDebug(message.attachmentIds.count == 0);
            self.messageCellType = OWSMessageCellType_TextMessage;
        }
        
        NSString *bodyText = containSignleTextCombinedMessage ? message.combinedForwardingMessage.subForwardingMessages.firstObject.body : message.body;
        self.displayableBodyText = [self displayableBodyTextForText:bodyText interactionId:message.uniqueId ?: [NSString stringWithFormat:@"%lld", message.timestamp]];
        OWSAssertDebug(self.displayableBodyText);
    }

    if (self.messageCellType == OWSMessageCellType_Unknown) {
        // Messages of unknown type (including messages with missing attachments)
        // are rendered like empty text messages, but without any interactivity.
        DDLogWarn(@"%@ Treating unknown message as empty text message: %@ %llu", self.logTag, message.class, message.timestamp);
        self.messageCellType = OWSMessageCellType_TextMessage;
        self.displayableBodyText = [[DisplayableText alloc] initWithFullText:@"" displayText:@"" isTextTruncated:NO];
    }

    if (message.quotedMessage) {
        self.quotedReply =
            [[OWSQuotedReplyModel alloc] initWithQuotedMessage:message.quotedMessage transaction:transaction];
        self.quotedReply.authorName = [self.contactsManager displayNameForPhoneIdentifier:self.quotedReply.authorId transaction:transaction];
        TSMessage *origionMessage = [self origionMessageWithQuotedMessage:message.quotedMessage transaction:transaction];
        NSString *quotedBody = nil;
        if (origionMessage != nil) {
            if (origionMessage.isSingleForward) {
                // 如果转发的是卡片消息，展示 quotedBody 时需要移除 markdown 样式
                DTCombinedForwardingMessage *subForwardingMessage = origionMessage.combinedForwardingMessage.subForwardingMessages[0];
                if (DTParamsUtils.validateString(subForwardingMessage.card.content)) {
                    quotedBody = [subForwardingMessage.body removeMarkdownStyle];
                } else {
                    quotedBody = subForwardingMessage.body;
                }
            } else {
                if ([message conformsToProtocol:@protocol(OWSPreviewText)]) {
                    id<OWSPreviewText> previewable = (id<OWSPreviewText>)origionMessage;
                    quotedBody = [previewable previewTextWithTransaction:transaction];
                }
            }
        } else {
            quotedBody = self.quotedReply.body;
        }
        if (quotedBody > 0) {
            self.displayableQuotedText =
                [self displayableQuotedTextForText:quotedBody interactionId:message.uniqueId];
        }
    }
}

- (void)ensureCombinedForwardingMessage:(DTCombinedForwardingMessage *)message
                            transaction:(nullable SDSAnyReadTransaction *)transaction {
    
    if(message.subForwardingMessages.count <= 0) return;
    
    [message.subForwardingMessages enumerateObjectsUsingBlock:^(DTCombinedForwardingMessage * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if(obj.authorId.length){
            NSString *displayName = [self.contactsManager rawDisplayNameForPhoneIdentifier:obj.authorId transaction:transaction];
            obj.authorName = displayName;
        }
        if (obj.forwardingAttachmentIds.count > 0) {
            __block TSAttachment *attachment = [TSAttachment anyFetchWithUniqueId:obj.forwardingAttachmentIds.firstObject transaction:transaction];
            if([attachment isKindOfClass:[TSAttachmentStream class]]){
                TSAttachmentStream *attachmentStream = (TSAttachmentStream *)attachment;
                obj.attachmentsDescription = attachmentStream.description ?: Localized(@"UNKNOWN_ATTACHMENT_LABEL", @"");
            }
        }
        [self ensureCombinedForwardingMessage:obj transaction:transaction];
    }];
}

- (TSMessage *)origionMessageWithQuotedMessage:(TSQuotedMessage *)quoteMessage transaction:(SDSAnyReadTransaction *)transaction {
    
        
    NSError *error;
    NSArray<TSMessage *> *messages = (NSArray<TSMessage *> *)[InteractionFinder
        interactionsWithTimestamp:quoteMessage.timestamp
                           filter:^(TSInteraction *interaction) {
                                if([interaction isKindOfClass:[TSIncomingMessage class]] ||
                                   [interaction isKindOfClass:[TSOutgoingMessage class]]){
                                    return YES;
                                }
                            
                                return NO;
                           }
                      transaction:transaction
                            error:&error];
    
    __block TSMessage *origionMessage = nil;
    [messages enumerateObjectsUsingBlock:^(TSMessage * _Nonnull message, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([message isKindOfClass:TSIncomingMessage.class]) {
            TSIncomingMessage *incomingMessage = (TSIncomingMessage *)message;
            if ([incomingMessage.authorId isEqualToString:quoteMessage.authorId]) {
                origionMessage = message;
                *stop = YES;
            }
        } else if ([message isKindOfClass:TSOutgoingMessage.class]) {
            origionMessage = message;
            *stop = YES;
        }
    }];
    
    return origionMessage;
}

- (NSString *)systemMessageTextWithTransaction:(SDSAnyReadTransaction *)transaction
{
    OWSAssertDebug(transaction);
    
    switch (self.interaction.interactionType) {
        case OWSInteractionType_Error: {
            TSErrorMessage *errorMessage = (TSErrorMessage *)self.interaction;
            return [errorMessage previewTextWithTransaction:transaction];
        }
        case OWSInteractionType_Info: {
            TSInfoMessage *infoMessage = (TSInfoMessage *)self.interaction;
            if ([infoMessage isKindOfClass:[OWSVerificationStateChangeMessage class]]) {
                OWSVerificationStateChangeMessage *verificationMessage
                = (OWSVerificationStateChangeMessage *)infoMessage;
                BOOL isVerified = verificationMessage.verificationState == OWSVerificationStateVerified;
                NSString *displayName =
                [self.contactsManager displayNameForPhoneIdentifier:verificationMessage.recipientId transaction:transaction];
                NSString *titleFormat = (isVerified
                                         ? (verificationMessage.isLocalChange
                                            ? Localized(@"VERIFICATION_STATE_CHANGE_FORMAT_VERIFIED_LOCAL",
                                                                @"Format for info message indicating that the verification state was verified "
                                                                @"on "
                                                                @"this device. Embeds {{user's name or phone number}}.")
                                            : Localized(@"VERIFICATION_STATE_CHANGE_FORMAT_VERIFIED_OTHER_DEVICE",
                                                                @"Format for info message indicating that the verification state was verified "
                                                                @"on "
                                                                @"another device. Embeds {{user's name or phone number}}."))
                                         : (verificationMessage.isLocalChange
                                            ? Localized(@"VERIFICATION_STATE_CHANGE_FORMAT_NOT_VERIFIED_LOCAL",
                                                                @"Format for info message indicating that the verification state was "
                                                                @"unverified on "
                                                                @"this device. Embeds {{user's name or phone number}}.")
                                            : Localized(@"VERIFICATION_STATE_CHANGE_FORMAT_NOT_VERIFIED_OTHER_DEVICE",
                                                                @"Format for info message indicating that the verification state was "
                                                                @"unverified on "
                                                                @"another device. Embeds {{user's name or phone number}}.")));
                return [NSString stringWithFormat:titleFormat, displayName];
            } else {
                return [infoMessage systemMessageTextWithTransaction:transaction];
            }
        }
        default:
            OWSFailDebug(@"not a system message.");
            return nil;
    }
}

- (nullable NSString *)quotedAttachmentMimetype
{
    return self.quotedReply.contentType;
}

- (nullable NSString *)quotedRecipientId
{
    return self.quotedReply.authorId;
}

- (OWSMessageCellType)messageCellType
{
//    OWSAssertIsOnMainThread();

    return _messageCellType;
}

- (nullable DisplayableText *)displayableBodyText
{
//    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.hasViewState);

    OWSAssertDebug(_displayableBodyText);
    OWSAssertDebug(_displayableBodyText.displayText);
    OWSAssertDebug(_displayableBodyText.fullText);

    return _displayableBodyText;
}

- (nullable TSAttachmentStream *)attachmentStream
{
//    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.hasViewState);

    return _attachmentStream;
}

- (nullable TSAttachmentPointer *)attachmentPointer
{
//    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.hasViewState);

    return _attachmentPointer;
}

- (CGSize)mediaSize
{
//    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.hasViewState);

    return _mediaSize;
}

- (nullable DisplayableText *)displayableQuotedText
{
//    OWSAssertIsOnMainThread();
    OWSAssertDebug(self.hasViewState);

    OWSAssertDebug(_displayableQuotedText);
    OWSAssertDebug(_displayableQuotedText.displayText);
    OWSAssertDebug(_displayableQuotedText.fullText);

    return _displayableQuotedText;
}

- (void)copyTextAction
{
    switch (self.messageCellType) {
        case OWSMessageCellType_TextMessage:
        case OWSMessageCellType_OversizeTextMessage:
        case OWSMessageCellType_StillImage:
        case OWSMessageCellType_AnimatedImage:
        case OWSMessageCellType_Audio:
        case OWSMessageCellType_Video:
        case OWSMessageCellType_GenericAttachment: {
            OWSAssertDebug(self.displayableBodyText);
            NSMutableArray <NSString *> *copyItems = @[].mutableCopy;
            NSString *fullText = self.displayableBodyText.fullText;
            if (DTParamsUtils.validateString(self.displayableBodyText.fullText)) {
                [copyItems addObject:fullText];
                
                NSString *jsonMentions = [self convertMentionsToJson];
                if (DTParamsUtils.validateString(jsonMentions)) {
                    [copyItems addObject:jsonMentions];
                }
            }
            if (copyItems.count > 0) {
                [UIPasteboard.generalPasteboard setStrings:copyItems];
            }
            break;
        }
        case OWSMessageCellType_Card: {
            NSString *copyText;
            if (self.isSingleForward) {
                copyText = self.card.content;
            } else {
                copyText = self.displayableBodyText.fullText;
            }
            [UIPasteboard.generalPasteboard setString:copyText];
            break;
        }
        case OWSMessageCellType_DownloadingAttachment: {
            OWSFailDebug(@"%@ Can't copy not-yet-downloaded attachment", self.logTag);
            break;
        }
        case OWSMessageCellType_Unknown: {
            OWSFailDebug(@"%@ No text to copy", self.logTag);
            break;
        }
        case OWSMessageCellType_ContactShare:
        case OWSMessageCellType_CombinedForwarding: {
            // TODO: Implement copy contact.
            OWSFailDebug(@"%@ Not implemented yet", self.logTag);
            break;
        }
    }
}

- (nullable NSString *)convertMentionsToJson {
    
    if (!DTParamsUtils.validateArray(self.mentions)) {
        return nil;
    }
    
    NSError *error;
    NSArray *mentions = [MTLJSONAdapter JSONArrayFromModels:self.mentions error:&error];
    if (error) {
        OWSLogDebug(@"%@ metions to array error:\n%@", self.logTag, error.localizedFailureReason);
        return nil;
    }
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:mentions options:NSJSONWritingSortedKeys error:&error];
    if (error) {
        OWSLogDebug(@"%@ metions to json error:\n%@", self.logTag, error.localizedFailureReason);
        return nil;
    }
    
    NSString *jsonMentions = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    return jsonMentions;
}

- (nullable NSAttributedString *)buildAndConfigCardAttrString {
    return nil;
}

- (void)copyMediaAction
{
    switch (self.messageCellType) {
        case OWSMessageCellType_Unknown:
        case OWSMessageCellType_TextMessage:
        case OWSMessageCellType_OversizeTextMessage:
        case OWSMessageCellType_ContactShare:
        case OWSMessageCellType_Card:
        case OWSMessageCellType_CombinedForwarding: {
            OWSFailDebug(@"%@ No media to copy", self.logTag);
            break;
        }
        case OWSMessageCellType_StillImage:
        case OWSMessageCellType_AnimatedImage:
        case OWSMessageCellType_Audio:
        case OWSMessageCellType_Video:
        case OWSMessageCellType_GenericAttachment: {
            NSString *utiType = [MIMETypeUtil utiTypeForMIMEType:self.attachmentStream.contentType];
            if (!utiType) {
                OWSFailDebug(@"%@ Unknown MIME type: %@", self.logTag, self.attachmentStream.contentType);
                utiType = (NSString *)kUTTypeGIF;
            }
            NSData *data = [NSData dataWithContentsOfURL:[self.attachmentStream mediaURL]];
            if (!data) {
                OWSFailDebug(@"%@ Could not load attachment data: %@", self.logTag, [self.attachmentStream mediaURL]);
                return;
            }
            [UIPasteboard.generalPasteboard setData:data forPasteboardType:utiType];
            break;
        }
        case OWSMessageCellType_DownloadingAttachment: {
            OWSFailDebug(@"%@ Can't copy not-yet-downloaded attachment", self.logTag);
            break;
        }
    }
}

- (void)shareTextAction
{
    switch (self.messageCellType) {
        case OWSMessageCellType_TextMessage:
        case OWSMessageCellType_OversizeTextMessage:
        case OWSMessageCellType_StillImage:
        case OWSMessageCellType_AnimatedImage:
        case OWSMessageCellType_Audio:
        case OWSMessageCellType_Video:
        case OWSMessageCellType_GenericAttachment: {
            OWSAssertDebug(self.displayableBodyText);
            [AttachmentSharing showShareUIForText:self.displayableBodyText.fullText];
            break;
        }
        case OWSMessageCellType_DownloadingAttachment: {
            OWSFailDebug(@"%@ Can't share not-yet-downloaded attachment", self.logTag);
            break;
        }
        case OWSMessageCellType_CombinedForwarding:
        case OWSMessageCellType_Card:
        case OWSMessageCellType_Unknown: {
            OWSFailDebug(@"%@ No text to share", self.logTag);
            break;
        }
        case OWSMessageCellType_ContactShare: {
            OWSFailDebug(@"%@ share contact not implemented.", self.logTag);
            break;
        }
    }
}

- (void)shareMediaAction
{
    switch (self.messageCellType) {
        case OWSMessageCellType_Unknown:
        case OWSMessageCellType_TextMessage:
        case OWSMessageCellType_OversizeTextMessage:
        case OWSMessageCellType_ContactShare:
        case OWSMessageCellType_Card:
        case OWSMessageCellType_CombinedForwarding:
            OWSFailDebug(@"No media to share.");
            break;
        case OWSMessageCellType_StillImage:
        case OWSMessageCellType_AnimatedImage:
        case OWSMessageCellType_Audio:
        case OWSMessageCellType_Video:
        case OWSMessageCellType_GenericAttachment:
            [AttachmentSharing showShareUIForAttachment:self.attachmentStream];
            break;
        case OWSMessageCellType_DownloadingAttachment: {
            OWSFailDebug(@"%@ Can't share not-yet-downloaded attachment", self.logTag);
            break;
        }
    }
}

- (BOOL)canSaveMedia
{
    switch (self.messageCellType) {
        case OWSMessageCellType_Unknown:
        case OWSMessageCellType_TextMessage:
        case OWSMessageCellType_OversizeTextMessage:
        case OWSMessageCellType_ContactShare:
        case OWSMessageCellType_Card:
        case OWSMessageCellType_CombinedForwarding:
            return NO;
        case OWSMessageCellType_StillImage:
        case OWSMessageCellType_AnimatedImage:
            return YES;
        case OWSMessageCellType_Audio:
            return NO;
        case OWSMessageCellType_Video:
            return UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(self.attachmentStream.mediaURL.path);
        case OWSMessageCellType_GenericAttachment:
            return NO;
        case OWSMessageCellType_DownloadingAttachment: {
            return NO;
        }
    }
}

- (void)saveMediaAction
{
    switch (self.messageCellType) {
        case OWSMessageCellType_Unknown:
        case OWSMessageCellType_TextMessage:
        case OWSMessageCellType_OversizeTextMessage:
        case OWSMessageCellType_ContactShare:
        case OWSMessageCellType_Card:
        case OWSMessageCellType_CombinedForwarding:
            OWSFailDebug(@"%@ Cannot save text data.", self.logTag);
            break;
        case OWSMessageCellType_StillImage:
        case OWSMessageCellType_AnimatedImage: {
            NSData *data = [NSData dataWithContentsOfURL:[self.attachmentStream mediaURL]];
            if (!data) {
                OWSFailDebug(@"%@ Could not load image data: %@", self.logTag, [self.attachmentStream mediaURL]);
                return;
            }
            ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
            [library writeImageDataToSavedPhotosAlbum:data
                                             metadata:nil
                                      completionBlock:^(NSURL *assetURL, NSError *error) {
                                          if (error) {
                                              DDLogWarn(@"Error Saving image to photo album: %@", error);

                                          } else {
                                              [DTToastHelper showSuccess:Localized(@"CHAT_FOLDER_SAVE_SUCCESS_TIP",
                                                                                             @"Title format for action sheet that offers to block an unknown user."
                                                                                             @"Embeds {{the unknown user's name or phone number}}.")];
                                          }
                                      }];
            break;
        }
        case OWSMessageCellType_Audio:
            OWSFailDebug(@"%@ Cannot save media data.", self.logTag);
            break;
        case OWSMessageCellType_Video:
            if (UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(self.attachmentStream.mediaURL.path)) {
                UISaveVideoAtPathToSavedPhotosAlbum(self.attachmentStream.mediaURL.path, self, nil, nil);
            } else {
                OWSFailDebug(@"%@ Could not save incompatible video data.", self.logTag);
            }
            break;
        case OWSMessageCellType_GenericAttachment:
            OWSFailDebug(@"%@ Cannot save media data.", self.logTag);
            break;
        case OWSMessageCellType_DownloadingAttachment: {
            OWSFailDebug(@"%@ Can't save not-yet-downloaded attachment", self.logTag);
            break;
        }
    }
}

- (void)deleteAction
{
    //MARK: remove -> archive
    TSMessage *message = (TSMessage *)self.interaction;
    OWSLogInfo(@"[Message Delete] timestamp: %llu, type: %ld, deviceId: %u", message.timestamp, message.interactionType, [OWSDevice currentDeviceId]);
  
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
//        [message anyRemoveWithTransaction:writeTransaction];
        [[OWSArchivedMessageJob sharedJob] archiveMessage:message transaction:writeTransaction];
        DDLogInfo(@"deleteAction message timestamp for sorting: %llu", message.timestampForSorting);
    });
}

- (BOOL)hasBodyTextActionContent
{
    return self.hasBodyText && self.displayableBodyText.fullText.length > 0;
}

- (BOOL)hasMediaActionContent
{
    switch (self.messageCellType) {
        case OWSMessageCellType_Unknown:
        case OWSMessageCellType_TextMessage:
        case OWSMessageCellType_OversizeTextMessage:
        case OWSMessageCellType_ContactShare:
        case OWSMessageCellType_Card:
        case OWSMessageCellType_CombinedForwarding:
            return NO;
        case OWSMessageCellType_StillImage:
        case OWSMessageCellType_AnimatedImage:
        case OWSMessageCellType_Audio:
        case OWSMessageCellType_Video:
        case OWSMessageCellType_GenericAttachment:
            return self.attachmentStream != nil;
        case OWSMessageCellType_DownloadingAttachment: {
            //版本支持转发/合并转发本地未下载的附件
            return YES;
        }
    }
}

- (BOOL)allowEmojiReaction {
    
    switch (self.messageCellType) {
        case OWSMessageCellType_Unknown:
        case OWSMessageCellType_ContactShare:
        case OWSMessageCellType_Audio:
        case OWSMessageCellType_CombinedForwarding:
            return NO;
        case OWSMessageCellType_TextMessage:
        case OWSMessageCellType_OversizeTextMessage:
        case OWSMessageCellType_StillImage:
        case OWSMessageCellType_AnimatedImage:
        case OWSMessageCellType_Video:
        case OWSMessageCellType_GenericAttachment:
        case OWSMessageCellType_Card:
            return YES;
        case OWSMessageCellType_DownloadingAttachment:
            return self.hasBodyText;
        default: return NO;
    }
}

- (BOOL)isEqualTo:(id <ConversationViewItem>)otherItem {
    
    NSString *authorId = nil;
    NSString *otherAuthorId = nil;
    TSInteraction *interaction = self.interaction;
    TSInteraction *otherInteraction = otherItem.interaction;
    
    if ([interaction isKindOfClass:[TSOutgoingMessage class]]) {
        authorId = [TSAccountManager localNumber];
    }
    if ([interaction isKindOfClass:[TSIncomingMessage class]]) {
        TSIncomingMessage *incomingMessage = (TSIncomingMessage *)interaction;
        authorId = incomingMessage.authorId;
    }
    
    if ([otherInteraction isKindOfClass:[TSOutgoingMessage class]]) {
        otherAuthorId = [TSAccountManager localNumber];
    }
    if ([otherInteraction isKindOfClass:[TSIncomingMessage class]]) {
        TSIncomingMessage *incomingMessage = (TSIncomingMessage *)otherInteraction;
        otherAuthorId = incomingMessage.authorId;
    }
    
    return self.interaction.timestamp == otherInteraction.timestamp && [authorId isEqualToString:otherAuthorId];
}


- (instancetype)initWithSepcialInteraction:(TSInteraction *)interaction
                                    thread:(nullable TSThread *)thread
                               transaction:(SDSAnyReadTransaction *)transaction
                         conversationStyle:(ConversationStyle *)conversationStyle {

    OWSAssertDebug(interaction);
    OWSAssertDebug(conversationStyle);

    self = [super init];

    if (!self) {
        return self;
    }

    _interaction = interaction;
    _thread = thread;
    _conversationStyle = conversationStyle;

    [self ensureViewState:transaction];

    return self;
}

- (BOOL)isPinned {
    
    if (![self.interaction isKindOfClass:TSMessage.class]) {
        return NO;
    }
    TSMessage *message = (TSMessage *)self.interaction;
    
    return message.isPinned;
}

- (BOOL)isPinMessage {
    
    if (![self.interaction isKindOfClass:TSMessage.class]) {
        return NO;
    }
    TSMessage *message = (TSMessage *)self.interaction;
    
    return message.isPinnedMessage;
}

- (BOOL)isConfidentialMessage {
    
    if (![self.interaction isKindOfClass:TSMessage.class]) {
        return NO;
    }
    
    TSMessage *message = (TSMessage *)self.interaction;
    return (message.messageModeType == TSMessageModeTypeConfidential);
    
}

//MARK: 如果reactionMap包含的emoji都不在指定的emojis里，或reactionMap里所有的记录都是remove，不显示reactionView
- (BOOL)hasEmojiReactionView {

    if (![self.interaction isKindOfClass:TSMessage.class]) {
        return NO;
    }
    
    TSMessage *message = (TSMessage *)self.interaction;
    if (DTParamsUtils.validateDictionary(message.reactionMap)) {
        
        NSSet *allEmojis = [NSSet setWithArray:[DTReactionHelper emojis]];
        NSSet *currentEmojis = [NSSet setWithArray:message.reactionMap.allKeys];
        BOOL isEmojisInScope = [allEmojis intersectsSet:currentEmojis];
        if (!isEmojisInScope) {
            return NO;
        }
        
        NSMutableSet <NSString *> *invalidEmojis = currentEmojis.mutableCopy;
        [invalidEmojis minusSet:allEmojis];
        NSMutableDictionary *tmpValidReactionMap = message.reactionMap.mutableCopy;
        [invalidEmojis enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, BOOL * _Nonnull stop) {
            [tmpValidReactionMap removeObjectForKey:obj];
        }];
        if (tmpValidReactionMap.count == 0) {
            return NO;
        }
        
        __block BOOL hasDisplayEmoji = NO;
        [tmpValidReactionMap.allValues enumerateObjectsUsingBlock:^(NSArray<DTReactionSource *> * _Nonnull objs, NSUInteger idx_, BOOL * _Nonnull stop1) {
            [objs enumerateObjectsUsingBlock:^(DTReactionSource * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop2) {
                if (!obj.isRemove) {
                    hasDisplayEmoji = YES;
                    *stop1 = YES;
                    *stop2 = YES;
                }
            }];
        }];
        return hasDisplayEmoji;
    }
    
    return NO;
}

@end

NS_ASSUME_NONNULL_END
