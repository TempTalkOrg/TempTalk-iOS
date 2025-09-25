//
//  DTScheduleMeeting.h
//  TTServiceKit
//
//  Created by Ethan on 28/08/2023.
//

#import <Mantle/Mantle.h>
@class DTMeetingAttendee;
@class DTMeetingGroup;
@class DTMeetingAttachment;
@class DTMeetingRecurringRule;
@class DTLiveStreamGuests;
@class DTMeetingHostInfo;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DTScheduleEditMode) {
    DTScheduleEditModeHidden,
    DTScheduleEditModeReadWrite,
    DTScheduleEditModeReadonly
};

@interface DTScheduleMeeting : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *topic;
@property (nonatomic, copy, nullable) NSString *describe;
@property (nonatomic, copy) NSString *timezone;
@property (nonatomic, copy) NSString *host;
@property (nonatomic, strong, nullable) DTMeetingRecurringRule *recurringRule;
@property (nonatomic, strong, nullable) NSArray <DTMeetingAttendee *> *attendees;
@property (nonatomic, strong, nullable) DTLiveStreamGuests *guests;
@property (nonatomic, strong, nullable) DTMeetingGroup *group;
@property (nonatomic, strong, nullable) NSArray <DTMeetingAttachment *> *attachment;
@property (nonatomic, strong) NSArray <DTMeetingAttachment *> *meetingLinks;
@property (nonatomic, strong) DTMeetingHostInfo *hostInfo;
@property (nonatomic, strong) DTMeetingHostInfo *creator;
@property (nonatomic, assign) BOOL isAllDay;
@property (nonatomic, assign) BOOL isRecurring;
@property (nonatomic, assign) BOOL isGroup;
@property (nonatomic, assign) BOOL everyoneCanInviteOthers;
@property (nonatomic, assign) BOOL everyoneCanModify;
@property (nonatomic, assign) NSTimeInterval start;
@property (nonatomic, assign) NSTimeInterval end;
@property (nonatomic, copy) NSString *source;

// detail
@property (nonatomic, copy) NSString *eid;
@property (nonatomic, copy, nullable) NSString *channelName;

@property (nonatomic, assign) BOOL isLiveStream;

@end

@interface DTMeetingAttendee : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *email;
@property (nonatomic, copy) NSString *role;

// detail
@property (nonatomic, copy) NSString *going;
@property (nonatomic, assign) BOOL isGroupUser;
@property (nonatomic, assign) BOOL isRemovable;

@end

@interface DTLiveStreamGuests : MTLModel<MTLJSONSerializing>

@property (nonatomic, strong, nullable) NSArray <NSString *> *users;
@property (nonatomic, assign) BOOL allStaff;
@property (nonatomic, assign) NSInteger total;

@end

@interface DTMeetingHostInfo : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSString *name;

@end

@interface DTMeetingGroup : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *gid;
@property (nonatomic, copy) NSString *name;

@end

@interface DTMeetingAttachment : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *link;

@end

@interface DTMeetingRepeatOption : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *value;

- (instancetype)initWithLabel:(NSString *)label value:(NSString *)value;

@end

@interface DTMeetingRecurringRule : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *rrule;
@property (nonatomic, copy) NSString *repeat;
@property (nonatomic, strong) NSArray <DTMeetingRepeatOption *> *repeatOptions;

@end


@interface DTListMeeting : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *cid;
@property (nonatomic, copy) NSString *eid;
@property (nonatomic, copy) NSString *topic;
@property (nonatomic, copy, nullable) NSString *channelName;
@property (nonatomic, strong) DTMeetingHostInfo *hostInfo;
@property (nonatomic, strong) DTMeetingHostInfo *creator;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) NSString *source;
@property (nonatomic, copy) NSString *googleLink;
@property (nonatomic, assign) NSTimeInterval start;
@property (nonatomic, assign) NSTimeInterval end;
@property (nonatomic, assign) NSString *going;
@property (nonatomic, assign) BOOL receiveNotification;
@property (nonatomic, assign) BOOL isLiveStream;
@property (nonatomic, assign) BOOL muted;

/// event中自己的角色
@property (nonatomic, copy) NSString *role;
/// event所在calendar中自己的角色
@property (nonatomic, copy) NSString *c_role;


@end

@interface DTUserEvents : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *uid;
@property (nonatomic, copy) NSString *timeZone;
@property (nonatomic, strong) NSArray <DTListMeeting *> *events;

@end

@interface DTSchedulePermission :  MTLModel<MTLJSONSerializing>

@property (nonatomic, assign) DTScheduleEditMode buttonDelete;
@property (nonatomic, assign) DTScheduleEditMode buttonEdit;
@property (nonatomic, assign) DTScheduleEditMode buttonUpdate;
@property (nonatomic, assign) DTScheduleEditMode checkboxEveryoneCanInviteOthers;
@property (nonatomic, assign) DTScheduleEditMode checkboxEveryoneCanModifyMeeting;
@property (nonatomic, assign) DTScheduleEditMode checkboxReceiveNotification;
@property (nonatomic, assign) DTScheduleEditMode checkboxSendInvitationToTheChatRoom;
@property (nonatomic, assign) DTScheduleEditMode editorAttachment;
@property (nonatomic, assign) DTScheduleEditMode pickerStartDateTime;
@property (nonatomic, assign) DTScheduleEditMode selectorAttendee;
@property (nonatomic, assign) DTScheduleEditMode selectorDuration;
@property (nonatomic, assign) DTScheduleEditMode selectorRepeat;
@property (nonatomic, assign) DTScheduleEditMode textFieldDesc;
@property (nonatomic, assign) DTScheduleEditMode textFieldTitle;
@property (nonatomic, assign) DTScheduleEditMode textHost;
@property (nonatomic, assign) DTScheduleEditMode toggleGoingOrNot;
@property (nonatomic, assign) DTScheduleEditMode buttonCopy;
@property (nonatomic, assign) DTScheduleEditMode buttonAddLiveStream;
@property (nonatomic, assign) DTScheduleEditMode buttonCopyLiveStream;
@property (nonatomic, assign) DTScheduleEditMode buttonJoin;

@end

//"buttonUpdate":                        "readwrite",
//"buttonEdit":                          "-",
//"buttonDelete":                        "-",
//"textFieldTitle":                      "readwrite",
//"pickerStartDateTime":                 "readwrite",
//"selectorDuration":                    "readwrite",
//"selectorRepeat":                      "readwrite",
//"selectorAttendee":                    "readwrite",
//"textHost":                            "read",
//"editorAttachment":                    "readwrite",
//"textFieldDesc":                       "readwrite",
//"checkboxEveryoneCanModifyMeeting":    "readwrite",
//"checkboxEveryoneCanInviteOthers":     "readwrite",
//"checkboxSendInvitationToTheChatRoom": "readwrite",
//"toggleGoingOrNot":                    "-",
//"checkboxReceiveNotification":         "-",
//"buttonAddLiveStream":                 "-"

NS_ASSUME_NONNULL_END

/*
 {
 "topic": "A test",
     "description": "A test for difft calendar",
     "start": 167990988,
     "end": 168000082,
     "timezone": "Asia/Shanghai",
     "isAllDay": false,
     "isRecurring": true,
     "recurringRule": {
         "rrule": "FREQ=YEARLY;INTERVAL=1"
     },
     "host": "+1234567",
     "attendees": [
         {
             "uid": "+1234567",
             "name": "Alice",
             "email": "alice@test.com",
             "role": "host"
         },
         {
             "uid":"+1234567",
             "name": "Cathy",
             "email": "cathy@test.com",
             "role": "attendee"
         }
     ],
     "isGroup": true,
     "group": {
         "gid": "xxxx",
         "name": "global dev group 1"
     },
     "attachment": [
         {
             "name": "A test attachment - 1",
             "link": "https://xxxxxxxxx"
         },
         {
             "name": "A test attachment - 2",
             "link": "https://xxxxxxx"
         }
     ],
     "everyoneCanInviteOthers": true,
     "everyoneCanModify": false
 }
 */
