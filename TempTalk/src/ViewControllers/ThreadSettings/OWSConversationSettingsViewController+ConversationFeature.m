//
//  OWSConversationSettingsViewController+MuteFeature.m
//  Signal
//
//  Created by hornet on 2022/6/23.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "OWSConversationSettingsViewController+ConversationFeature.h"
#import <TTServiceKit/DTConversationSettingHelper.h>

@implementation OWSConversationSettingsViewController (ConversationFeature)

- (void)requestConfigMuteStatusWithConversationID:(NSString *)gid
                                       muteStatus:(NSNumber *) muteStatus
                                          success:(void(^ )(void)) successBlock
                                          failure:(void(^ )(void)) failureBlock {
    [[DTConversationSettingHelper sharedInstance] configMuteStatusWithConversationID:gid muteStatus:muteStatus success:successBlock failure:failureBlock];
}

- (void)requestConfigBlockStatusWithConversationID:(NSString *)gid
                                       blockStatus:(NSNumber *) blockStatus
                                          success:(void(^ )(void)) successBlock
                                          failure:(void(^ )(void)) failureBlock {
    [[DTConversationSettingHelper sharedInstance] configBlockStatusWithConversationID:gid blockStatus:blockStatus success:successBlock failure:failureBlock];
}

@end
