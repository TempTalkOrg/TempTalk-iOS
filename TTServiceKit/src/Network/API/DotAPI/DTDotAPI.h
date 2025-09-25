//
//  DTDotAPI.h
//  TTServiceKit
//
//  Created by Ethan on 13/02/2023.
//

#import "DTBaseAPI.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTDotAPI : DTBaseAPI

- (void)reportMeetingInfoWithMeetingId:(NSString *)meetingId
                           meetingName:(NSString *)meetingName
                             timestamp:(NSTimeInterval)timestamp
                           channelName:(NSString *)channelName;

@end

NS_ASSUME_NONNULL_END
