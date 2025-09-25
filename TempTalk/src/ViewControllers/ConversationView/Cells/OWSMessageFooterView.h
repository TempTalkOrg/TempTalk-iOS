//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

@class ConversationStyle;
@protocol ConversationViewItem;

@protocol OWSMessageFooterViewDelegate <NSObject>

- (void)tapReadStatusAction;

@end

NS_ASSUME_NONNULL_BEGIN

@interface OWSMessageFooterView : UIStackView

@property (nonatomic, weak) id<OWSMessageFooterViewDelegate> delegate;

- (void)configureWithConversationViewItem:(id <ConversationViewItem>)viewItem
                        isOverlayingMedia:(BOOL)isOverlayingMedia
                        conversationStyle:(ConversationStyle *)conversationStyle
                               isIncoming:(BOOL)isIncoming;

- (CGSize)measureWithConversationViewItem:(id <ConversationViewItem>)viewItem;

- (void)prepareForReuse;

@end

NS_ASSUME_NONNULL_END
