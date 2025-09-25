//
//  DTMeetingEntity.h
//  TTServiceKit
//
//  Created by Felix on 2022/2/15.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTMeetingEntity : MTLModel <MTLJSONSerializing>

@property (nonatomic, assign) NSUInteger maxAudioPushStreamCount;
@property (nonatomic, assign) NSUInteger maxVideoPushStreamCount;
@property (nonatomic, strong) NSArray<NSString *> *meetingPreset;
@property (nonatomic, strong) NSArray<NSString *> *meetingInviteForbid;
@property (nonatomic, assign) BOOL openMuteOther;
@property (nonatomic, assign) NSUInteger messageDisappearTime;
/// 控制是否展示主持人结束会议/转移主持人功能
@property (nonatomic, assign) BOOL hostEndButtonPopup;

@end

NS_ASSUME_NONNULL_END
