//
//  DTSetConversationApi.h
//  Signal
//
//  Created by hornet on 2022/6/22.
//  Copyright © 2022 Difft. All rights reserved.
//

//#import <TTServiceKit/TTServiceKit.h>
#import "DTBaseAPI.h"

@class DTConversationEntity;
NS_ASSUME_NONNULL_BEGIN

@interface DTSetConversationApi : DTBaseAPI
- (void)requestConfigMuteStatusWithConversationID:(NSString *)conversation
                                       muteStatus:(NSNumber *)muteStatus
                                          success:(void(^)(DTConversationEntity*)) sucessBlock
                                          failure:(void(^)(NSError*))failure;

- (void)requestConfigBlockStatusWithConversationID:(NSString *)conversation
                                       blockStatus:(NSNumber *)blockStatus
                                           success:(void(^)(DTConversationEntity*)) sucessBlock
                                           failure:(void(^)(NSError*))failure;

- (void)requestConfigConfidentialModeWithConversationID:(NSString *)conversation
                                       confidentialMode:(NSInteger)confidentialMode
                                                success:(void(^)(DTConversationEntity*)) sucessBlock
                                                failure:(void(^)(NSError*))failure;

- (void)requestConfigConractRemarkWithConversationID:(NSString *)conversation
                                              remark:(NSString *)aesRemarkNameString
                                             success:(void(^)(DTConversationEntity*)) sucessBlock
                                             failure:(void(^)(NSError*))failure;

@end

NS_ASSUME_NONNULL_END
