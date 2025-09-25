//
//  OWSConversationSettingsViewController+MuteFeature.h
//  Signal
//
//  Created by hornet on 2022/6/23.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "OWSConversationSettingsViewController.h"

@class DTConversationEntity;
NS_ASSUME_NONNULL_BEGIN

@interface OWSConversationSettingsViewController (ConversationFeature)

- (void)requestConfigMuteStatusWithConversationID:(NSString *)gid
                                       muteStatus:(NSNumber *) muteStatus
                                          success:(void(^ _Nullable)(void)) successBlock
                                          failure:(void(^ _Nullable)(void)) failureBlock;

- (void)requestConfigBlockStatusWithConversationID:(NSString *)gid
                                       blockStatus:(NSNumber *) blockStatus
                                          success:(void(^ _Nullable)(void)) successBlock
                                           failure:(void(^ _Nullable)(void)) failureBlock;

@end

NS_ASSUME_NONNULL_END
