//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSAudioPlayer.h"
#import "ConversationItemMacro.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, OWSMessageCellType) {
    OWSMessageCellType_Unknown,
    OWSMessageCellType_TextMessage,
    OWSMessageCellType_OversizeTextMessage,
    OWSMessageCellType_StillImage,
    OWSMessageCellType_AnimatedImage,
    OWSMessageCellType_Audio,
    OWSMessageCellType_Video,
    OWSMessageCellType_GenericAttachment,
    OWSMessageCellType_DownloadingAttachment,
    OWSMessageCellType_ContactShare,
    OWSMessageCellType_CombinedForwarding,
    OWSMessageCellType_Card,
};

NSString *NSStringForOWSMessageCellType(OWSMessageCellType cellType);

#pragma mark -

@class TSThread;
@class ContactShareViewModel;
@class DisplayableText;
@class OWSAudioMessageView;
@class OWSQuotedReplyModel;
@class OWSUnreadIndicator;
@class TSAttachmentPointer;
@class TSAttachmentStream;
@class TSInteraction;
@class SDSAnyReadTransaction;
@class DTCombinedForwardingMessage;
@class DTCardMessageEntity;
@class DTMention;
@class ConversationCell;
@class ConversationStyle;

// This is a ViewModel for cells in the conversation view.
//
// The lifetime of this class is the lifetime of that cell
// in the load window of the conversation view.
@protocol ConversationViewItem <NSObject, OWSAudioPlayerDelegate>

@property (nonatomic, readonly) TSInteraction *interaction;

@property (nonatomic, readonly) TSThread *thread;
@property (nonatomic, readonly) BOOL isGroupThread;

@property (nonatomic, readonly) NSDictionary *avatar;
@property (nonatomic, readonly) NSString *displayName;

@property (nonatomic, readonly) BOOL hasBodyText;
@property (nonatomic, readonly) BOOL showTranslateResultText;
@property (nonatomic, assign)   BOOL hasAutoRetryTranslate;
@property (nonatomic, readonly) BOOL isQuotedReply;
@property (nonatomic, readonly) BOOL hasQuotedAttachment;
@property (nonatomic, readonly) BOOL hasQuotedText;
@property (nonatomic, readonly) BOOL hasCellHeader;
@property (nonatomic, readonly) BOOL hasEmojiReactionView;
@property (nonatomic, assign)   BOOL hadAutoDownloaded;

@property (nonatomic, readonly) BOOL isCombindedForwardMessage;
@property (nonatomic, readonly) BOOL hasPerConversationExpiration;

/// 是否是转发和pin消息页
@property (nonatomic, assign) BOOL isUseForMessageList;
/// 原消息是否被pin
@property (nonatomic, readonly) BOOL isPinned;
/// 是否是pin消息
@property (nonatomic, readonly) BOOL isPinMessage;
/// 是否是机密消息
@property (nonatomic, readonly) BOOL isConfidentialMessage;

@property (nonatomic) BOOL shouldShowDate;
@property (nonatomic) BOOL shouldShowSenderAvatar;
@property (nonatomic, nullable) NSAttributedString *senderName;
@property (nonatomic, assign)  ConversationViewMode conversationViewMode;

@property (nonatomic) BOOL shouldHideFooter;
@property (nonatomic) BOOL isFirstInCluster;
@property (nonatomic) BOOL isLastInCluster;

@property (nonatomic, nullable) OWSUnreadIndicator *unreadIndicator;

@property (nonatomic, readonly) ConversationStyle *conversationStyle;

- (ConversationCell *)dequeueCellForCollectionView:(UICollectionView *)collectionView
                                         indexPath:(NSIndexPath *)indexPath;

- (void)replaceInteraction:(TSInteraction *)interaction transaction:(SDSAnyReadTransaction *)transaction;

- (void)clearCachedLayoutState;

#pragma mark - Needs Update

@property (nonatomic, readonly) BOOL needsUpdate;

- (void)clearNeedsUpdate;

#pragma mark - Audio Playback

@property (nonatomic, readonly) CGFloat audioDurationSeconds;

- (CGFloat)audioProgressSeconds;

- (void)associateAudioMessageView:(OWSAudioMessageView *)audioMessageView;

#pragma mark - View State Caching

// These methods only apply to text & attachment messages.
- (OWSMessageCellType)messageCellType;
- (nullable DisplayableText *)displayableBodyText;
- (nullable TSAttachmentStream *)attachmentStream;
- (nullable TSAttachmentPointer *)attachmentPointer;
- (CGSize)mediaSize;

- (nullable DisplayableText *)displayableQuotedText;
- (nullable NSString *)quotedAttachmentMimetype;
- (nullable NSString *)quotedRecipientId;

// We don't want to try to load the media for this item (if any)
// if a load has previously failed.
@property (nonatomic) BOOL didCellMediaFailToLoad;

@property (nonatomic, readonly, nullable) OWSQuotedReplyModel *quotedReply;

@property (nonatomic, readonly, nullable) DTCombinedForwardingMessage *combinedForwardingMessage;

@property (nonatomic, readonly, nullable) ContactShareViewModel *contactShare;
// 系统消息 body
@property (nonatomic, readonly, nullable) NSString *systemMessageText;
// 长文本（转附件文本）长度
@property (nonatomic, readonly) NSUInteger oversizeTextLength;

@property (nonatomic, strong, nullable) DTCardMessageEntity *card;
@property (atomic, nullable) NSAttributedString *cardAttrString;
@property (atomic, nullable) NSDictionary *gifElements;

@property (nonatomic, readonly, nullable) NSArray <DTMention *> *mentions;

@property (nonatomic, strong) NSArray <NSString *> *emojiTitles;

#pragma mark - MessageActions

@property (nonatomic, readonly) BOOL hasBodyTextActionContent;
@property (nonatomic, readonly) BOOL hasMediaActionContent;

- (BOOL)canSaveMedia;
- (BOOL)allowEmojiReaction;
- (void)copyMediaAction;
- (void)copyTextAction;
- (void)shareMediaAction;
- (void)shareTextAction;
- (void)saveMediaAction;
- (void)deleteAction;
- (BOOL)canShowTranslateAction;
- (BOOL)showTranslateAction;
- (BOOL)shouldShowTranslateView;

// For view items that correspond to interactions, this is the interaction's unique id.
// For other view views (like the typing indicator), this is a unique, stable string.
- (NSString *)itemId;

- (BOOL)isEqualTo:(id <ConversationViewItem>)otherItem;

- (instancetype)initWithSepcialInteraction:(TSInteraction *)interaction
                             thread:(nullable TSThread *)thread
                        transaction:(SDSAnyReadTransaction *)transaction
                  conversationStyle:(ConversationStyle *)conversationStyle;

- (UIColor *)threadInteractiveBarColor;

- (nullable NSString *)convertMentionsToJson;

- (nullable NSAttributedString *)buildAndConfigCardAttrString;

@end

#pragma mark -

@interface ConversationInteractionViewItem
: NSObject <ConversationViewItem, OWSAudioPlayerDelegate>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithInteraction:(TSInteraction *)interaction
                             thread:(TSThread *)thread
               conversationViewMode:(ConversationViewMode) conversationViewMode
                        transaction:(SDSAnyReadTransaction *)transaction
                  conversationStyle:(ConversationStyle *)conversationStyle;

@end

NS_ASSUME_NONNULL_END
