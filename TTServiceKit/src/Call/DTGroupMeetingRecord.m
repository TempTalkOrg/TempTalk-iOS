//
//  DTGroupMeetingRecord.m
//  TTServiceKit
//
//  Created by Ethan on 2022/7/22.
//

#import "DTGroupMeetingRecord.h"

@implementation DTGroupMeetingRecord

+ (instancetype)sharedRecord {
    
    static DTGroupMeetingRecord *record = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        record = [DTGroupMeetingRecord new];
        record.meetingRecordSet = [NSMutableSet new];
    });
    return record;
}


@end
