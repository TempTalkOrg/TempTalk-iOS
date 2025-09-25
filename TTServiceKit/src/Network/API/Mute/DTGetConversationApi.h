//
//  DTGetConversationApi.h
//  Signal
//
//  Created by hornet on 2022/6/22.
//  Copyright © 2022 Difft. All rights reserved.
//

//#import <TTServiceKit/TTServiceKit.h>
#import "DTBaseAPI.h"
#import "DTConversationNotifyEntity.h"

// TODO: conversationSetting combine DTGetConversationApi && DTSetConversationApi
@interface DTGetConversationApi : DTBaseAPI
- (void)requestMuteStatusWithConversationIds:(NSArray *)conversations
                                     success:(void(^)(NSArray<DTConversationEntity*>*)) sucessBlock
                                     failure:(void(^)(NSError*))failure;

@end

