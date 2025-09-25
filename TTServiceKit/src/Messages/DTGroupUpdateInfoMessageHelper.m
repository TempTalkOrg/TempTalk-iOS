//
//  DTGroupUpdateInfoMessageHelper.m
//  TTServiceKit
//
//  Created by hornet on 2022/9/30.
//

#import "DTGroupUpdateInfoMessageHelper.h"
#import "TSGroupThread.h"
#import "TSInfoMessage.h"
#import "NSDate+OWS.h"
#import <TTServiceKit/TTServiceKit-swift.h>

@implementation DTGroupUpdateInfoMessageHelper
+ (TSInfoMessage *)groupUpdatePublishRuleInfoMessage:(NSNumber *)publishRule timestamp:(uint64_t)timestamp serverTimestamp:(uint64_t)serverTimestamp
       inThread:(TSThread *)thread {
    TSInfoMessage * publishRuleChangeSystemMessage = nil;
    if (publishRule && [publishRule intValue] == 0) { // 仅管理员可以发言
        publishRuleChangeSystemMessage = [[TSInfoMessage alloc] initActionInfoMessageWithType:TSInfoMessageGroupPublishRuleChange
                                                                                        timestamp:[NSDate ows_millisecondTimeStamp]
                                                                                  serverTimestamp:serverTimestamp
                                                                                         inThread:thread
                                                                                    customMessage:[[NSAttributedString alloc] initWithString:Localized(@"INFO_MESSAGE_ONLY_OWNER_CAN_SPEAK", nil)]];
        
    } else if (publishRule && [publishRule intValue] == 1) {
        publishRuleChangeSystemMessage = [[TSInfoMessage alloc] initActionInfoMessageWithType:TSInfoMessageGroupPublishRuleChange
                                                                                        timestamp:[NSDate ows_millisecondTimeStamp]
                                                                              serverTimestamp:serverTimestamp
                                                                                         inThread:thread
                                                                                    customMessage:[[NSAttributedString alloc] initWithString:Localized(@"INFO_MESSAGE_ONLY_MODERATORS_CAN_SPEAK", nil)]];
    } else if (publishRule && [publishRule intValue] == 2) {
        publishRuleChangeSystemMessage = [[TSInfoMessage alloc] initActionInfoMessageWithType:TSInfoMessageGroupPublishRuleChange
                                                                                        timestamp:[NSDate ows_millisecondTimeStamp]
                                                                                  serverTimestamp:serverTimestamp
                                                                                         inThread:thread
                                                                                    customMessage:[[NSAttributedString alloc] initWithString:Localized(@"INFO_MESSAGE_EVERYONE_CAN_SPEAK", nil)]];
    }
    return publishRuleChangeSystemMessage;
}

+ (TSInfoMessage *)gOpenAutoClearSwitchInfoMessageWithThread:(TSGroupThread *)thread isOn:(BOOL)isOn {
    uint64_t now = [NSDate ows_millisecondTimeStamp];
    NSString *updateGroupInfo = isOn ? Localized(@"LIST_GROUP_AUTO_CLEAN_TURN_ON_MSG", nil) : Localized(@"LIST_GROUP_AUTO_CLEAN_TURN_OFF_MSG", nil);
    TSInfoMessage *infoMessage = [[TSInfoMessage alloc] initWithTimestamp:now
                                                                 inThread:thread
                                                              messageType:TSInfoMessageTypeGroupUpdate
                                                            customMessage:updateGroupInfo];
    infoMessage.shouldAffectThreadSorting = NO;
    return infoMessage;
}

+ (TSInfoMessage *)gPrivilegeConfidentialInfoMessageWithThread:(TSGroupThread *)thread
                                                  operatorName:(NSString *)operatorName {
    uint64_t now = [NSDate ows_millisecondTimeStamp];
    NSString *updateGroupInfo = [NSString stringWithFormat:Localized(@"GROUP_INFO_TURN_ON_PROVILEGE_CONFIDENTIAL", nil), operatorName];
    TSInfoMessage *infoMessage = [[TSInfoMessage alloc] initWithTimestamp:now
                                                                 inThread:thread
                                                              messageType:TSInfoMessageTypeGroupUpdate
                                                            customMessage:updateGroupInfo];
    infoMessage.shouldAffectThreadSorting = YES;
    return infoMessage;
}

+ (TSInfoMessage *)groupUpdateExtPrivateChatInfoMessage:(TSGroupThread *)thread
                                                       turnOn:(BOOL)turnOn
                                                  operatorName:(NSString *)operatorName {
    uint64_t now = [NSDate ows_millisecondTimeStamp];
    NSString *updateGroupInfo;
    if (turnOn) {
        updateGroupInfo = [NSString stringWithFormat:Localized(@"GROUP_UPDATE_OPEN_EXT_PRIVATE_CHAT_INFO_MESSAGE", nil), Localized(@"YOU", @"")];
    } else {
        updateGroupInfo = [NSString stringWithFormat:Localized(@"GROUP_UPDATE_CLOSE_EXT_PRIVATE_CHAT_INFO_MESSAGE", nil), Localized(@"YOU", @"")];
    }
   
    TSInfoMessage *infoMessage = [[TSInfoMessage alloc] initWithTimestamp:now
                                                                 inThread:thread
                                                              messageType:TSInfoMessageTypeGroupUpdate
                                                            customMessage:updateGroupInfo];
    
    infoMessage.shouldAffectThreadSorting = YES;
    return infoMessage;
}

@end
