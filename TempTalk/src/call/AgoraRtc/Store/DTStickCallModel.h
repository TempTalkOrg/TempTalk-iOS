//
//  DTStickCallModel.h
//  Wea
//
//  Created by Felix on 2021/12/25.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@class DTStickCallModel;

typedef enum : NSUInteger {
    MeetingEventUnknow = 0,
    MeetingEventCreate,
    MeetingEventDestroy,
    MeetingEventChange,
    MeetingEventStartMeeting,
    MeetingEventJoinStart,
    MeetingEventJoinEnd,
    MeetingEventPopups,
    MeetingEventHost,
    MeetingEventHostEnd,
    MeetingEventVideo,
} MeetingEvent;

typedef enum : NSUInteger {
    MeetingTypeUnknow = 0,
    MeetingTypePrivate,
    MeetingTypeInstant,
    MeetingTypeGroup,
    MeetingTypeExternal,
    MeetingTypeRoom,
} MeetingType;

@interface DTRTMMessage : MTLModel<MTLJSONSerializing>

// 'create', 'destroy', 'change', 'start-meeting', 'popups', 'join-start', 'join-end'
@property (nonatomic, assign) MeetingEvent event;
@property (nonatomic, strong) DTStickCallModel *room;

@property (nonatomic, copy) NSString *channelName;
@property (nonatomic, copy, nullable) NSString *meetingName;
@property (nonatomic, copy, nullable) NSString *host;
@property (nonatomic, strong) NSNumber *ts;

/// 推流: 'start'/'end'
@property (nonatomic, copy) NSString *type;

@property (nonatomic, assign) BOOL isScheduled;

@end

@interface DTStickCallModel : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *channelName;
@property (nonatomic, copy) NSString *meetingName;
// 'private', 'instant', 'group', 'external'
@property (nonatomic, assign) MeetingType meetingType;
@property (nonatomic, assign) MeetingEvent meetingEvent;
@property (nonatomic, strong) NSArray<NSString *> *privateUsers;
@property (nonatomic, strong, nullable) NSNumber *meetingId;
// 1on1 thread recipient
@property (nonatomic, copy) NSString *otherRecipient;
// group thread id
@property (nonatomic, strong) NSData *groupId;
@property (nonatomic, strong) NSNumber *online;
@property (nonatomic, strong) NSNumber *duration;
@property (nonatomic, strong) NSNumber *ts;
/// 预约会议开始前显示Join, 入会后显示计时
/// 对应的会话
@property (nonatomic, copy) NSString *uniqueId;

@property (nonatomic, assign) BOOL isLiveStream;
@property (nonatomic, copy, nullable) NSString *eid;

@end

NS_ASSUME_NONNULL_END
