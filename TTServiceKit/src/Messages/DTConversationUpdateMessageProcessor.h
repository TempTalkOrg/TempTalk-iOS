//
//  DTConversationUpdateMessageProcessor.h
//  TTServiceKit
//
//  Created by hornet on 2022/6/23.
//

#import <Foundation/Foundation.h>
#import "DTConversationNotifyEntity.h"
@class DTFetchThreadConfigAPI;



NS_ASSUME_NONNULL_BEGIN
extern NSString *const DTConversationSharingConfigurationChangeNotification;

@class SDSAnyWriteTransaction;
@class DSKProtoEnvelope;

@interface DTConversationUpdateMessageProcessor : NSObject
@property (nonatomic, strong) DTFetchThreadConfigAPI *fetchThreadConfigAPI;
- (void)handleConversationUpdateMessageWithEnvelope:(DSKProtoEnvelope *)envelope
                                     display:(BOOL)display
                           conversationNotifyEntity:(DTConversationNotifyEntity *)conversationNotifyEntity
                                        transaction:(SDSAnyWriteTransaction *)transaction;
@end

NS_ASSUME_NONNULL_END
