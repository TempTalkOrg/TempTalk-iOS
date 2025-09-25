//
//  DTForwardMessageHelper.h
//  Wea
//
//  Created by Ethan on 2021/11/23.
//

#import <Foundation/Foundation.h>
@protocol ConversationViewItem;
@class TSMessage;
@class TSThread;
@class DTCombinedForwardingMessage;
@class YapDatabaseConnection;

typedef NS_ENUM(NSInteger, DTForwardMessageType) {
    
    DTForwardMessageTypeOneByOne = 0,
    DTForwardMessageTypeCombined,
    DTForwardMessageTypeNote
};

NS_ASSUME_NONNULL_BEGIN

@interface DTForwardMessageHelper : NSObject

+ (TSMessage *)messageFromViewItem:(id <ConversationViewItem>)viewItem;
+ (NSArray <TSMessage *> *)messagesFromViewItems:(NSArray <id<ConversationViewItem>> *)viewItems;

+ (id)forwardContentFromViewItem:(id<ConversationViewItem>)viewItem;
+ (NSArray *)forwardContentsFromViewItems:(NSArray <id<ConversationViewItem>> *)viewItems;

+ (NSString *)previewOfMessageTextWithForwardType:(DTForwardMessageType)type thread:(TSThread *)thread viewItems:(NSArray <id<ConversationViewItem>> *)viewItems;

+ (NSAttributedString *)combinedForwardingMessageBodyTextWithIsGroupThread:(BOOL)isGroupThread combinedMessage:(TSMessage *)combinedMessage;

+ (NSString *)combinedForwardingMessageTitleWithIsGroupThread:(BOOL )isGroupThread combinedMessage:(TSMessage *)combinedMessage;

+ (void)forwardMessageIsFromGroup:(BOOL)isGroupThread
                     targetThread:(TSThread *)targetThread
                         messages:(NSArray <TSMessage *>*)messages
                          success:(void(^ _Nullable)(void))success
                          failure:(void(^ _Nullable)(NSError *error))failure;

@end

NS_ASSUME_NONNULL_END
