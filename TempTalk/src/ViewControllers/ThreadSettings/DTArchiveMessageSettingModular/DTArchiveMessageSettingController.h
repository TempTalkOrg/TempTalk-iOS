//
//  DTArchiveMessageSettingController.h
//  Signal
//
//  Created by hornet on 2022/7/26.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <TTMessaging/TTMessaging.h>
#import "OWSConversationSettingsViewDelegate.h"
NS_ASSUME_NONNULL_BEGIN

@interface DTArchiveMessageSettingController : OWSTableViewController
@property (nonatomic, assign) uint32_t durationSeconds;
@property (nonatomic, weak) id<OWSConversationSettingsViewDelegate> conversationSettingsViewDelegate;
@property (nonatomic, strong) TSThread *thread;
@end

NS_ASSUME_NONNULL_END
