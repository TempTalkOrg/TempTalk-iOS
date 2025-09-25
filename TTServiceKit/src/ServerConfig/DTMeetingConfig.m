//
//  DTMeetingConfig.m
//  TTServiceKit
//
//  Created by Felix on 2022/2/15.
//

#import "DTMeetingConfig.h"
#import "DTServerConfigManager.h"

@implementation DTMeetingConfig

+ (NSDictionary *)defaultConfig {
    return @{
        @"messageDisappearTime" : @6,
        @"maxAudioPushStreamCount" : @(24),
        @"maxVideoPushStreamCount": @(12),
        @"meetingInviteForbid": @[@"609066"],
        @"openMuteOther": @(false),
        @"hostEndButtonPopup": @(false),
        @"meetingPreset": @[
            @"Please slow down",
            @"Need to speed up",
            @"Agree",
            @"Disagree",
            @"Bad signal, can't hear clearly",
            @"You are muted",
            @"✋ I'd like to speak",
            @"Good call. Have to drop off.",
            @"Talk to you later.",
        ],
        @"createCallMsg": @(false)
    };
}

+ (DTMeetingEntity *)fetchMeetingConfig {
    
    __block DTMeetingEntity *result = nil;
    
    [[DTServerConfigManager sharedManager] fetchConfigFromLocalWithSpaceName:@"meeting"
                                                                  completion:^(id _Nonnull config, NSError * _Nonnull error) {
        NSDictionary *meetingConfig = config;
        if (error || meetingConfig == nil) {
            meetingConfig = [self defaultConfig];
        }
        
        NSError *jsonError;
        DTMeetingEntity *entity = [MTLJSONAdapter modelOfClass:[DTMeetingEntity class] fromJSONDictionary:meetingConfig error:&jsonError];
        if (!jsonError && entity) {
            result = entity;
        } else {
            DTMeetingEntity *entity = [DTMeetingEntity new];
            [meetingConfig enumerateKeysAndObjectsUsingBlock:^(id _Nonnull key, id _Nonnull obj, BOOL * _Nonnull stop) {
                [entity setValue:obj forKey:key];
            }];
            result = entity;
        }
        
    }];
    
    return result;
}


@end
