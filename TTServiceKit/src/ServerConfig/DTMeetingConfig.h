//
//  DTMeetingConfig.h
//  TTServiceKit
//
//  Created by Felix on 2022/2/15.
//

#import <Foundation/Foundation.h>
#import "DTMeetingEntity.h"

typedef NS_ENUM(NSUInteger, DTMeetingStatus) {
    DTMeetingStatusOutofMeeting = 0,            // 不在会议中
    DTMeetingStatusIn1on1VoiceMeeing = 1,       // 1on1 语音
    DTMeetingStatusIn1on1VideoMeeing = 2,       // 1on1 视频
    DTMeetingStatusInGroupVoiceMeeing = 3,      // group 语音
    DTMeetingStatusInGroupVideoMeeing = 4,      // group 视频
    DTMeetingStatusConnecting = 10,
};

NS_ASSUME_NONNULL_BEGIN

@interface DTMeetingConfig : NSObject

+ (DTMeetingEntity *)fetchMeetingConfig;

@end

NS_ASSUME_NONNULL_END
