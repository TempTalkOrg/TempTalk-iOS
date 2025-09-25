//
//  DTGroupMeetingRecord.h
//  TTServiceKit
//
//  Created by Ethan on 2022/7/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTGroupMeetingRecord : NSObject

@property (nonatomic, strong) NSMutableSet<NSString *> *meetingRecordSet;

+ (instancetype)sharedRecord;

@end

NS_ASSUME_NONNULL_END
