//
//  DTDotAPI.m
//  TTServiceKit
//
//  Created by Ethan on 13/02/2023.
//

#import "DTDotAPI.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@implementation DTDotAPI

- (instancetype)init {
    
    if (self = [super init]) {
        self.serverType = DTServerTypeDot;
    }
    
    return self;
}

- (void)reportMeetingInfoWithMeetingId:(NSString *)meetingId
                           meetingName:(NSString *)meetingName
                             timestamp:(NSTimeInterval)timestamp
                           channelName:(NSString *)channelName {
    
    if (!DTParamsUtils.validateString(meetingId)) {
        OWSLogError(@"%@ meetingId error: %@", self.logTag, meetingId);
        return;
    }
    if (!DTParamsUtils.validateString(meetingName)) {
        OWSLogError(@"%@ meetingName error: %@", self.logTag, meetingName);
        return;
    } else {
        OWSLogInfo(@"%@ meetingName: %@", self.logTag, meetingName);
    }
    if (timestamp <= 0 || timestamp == NSNotFound) {
        OWSLogError(@"%@ timestamp error: %.0f", self.logTag, timestamp);
        return;
    }
    if (!DTParamsUtils.validateString(channelName)) {
        OWSLogError(@"%@ channelName error: %@", self.logTag, channelName);
        return;
    }
    uint64_t realTimestamp = ceil(timestamp);
    [[DTTokenHelper sharedInstance] asyncFetchGlobalAuthTokenWithCompletion:^(NSString * _Nullable token, NSError * _Nullable error) {
        if (error) {
            OWSLogError(@"%@ get token error: %@", self.logTag, error.localizedDescription);
            return;
        }
        
        NSURL *url = [NSURL URLWithString:@"/v1/dot/reportMeetingInfo"];
        TSRequest *request = [TSRequest requestWithUrl:url
                                                method:@"POST"
                                            parameters:@{@"meetingId" : meetingId,
                                                         @"meetingName" : meetingName,
                                                         @"timestamp" : @(realTimestamp),
                                                         @"channelName" : channelName
                                                       }];
        request.authToken = token;
        
        [self.urlSession performNonmainRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                OWSLogError(@"%@ report meeting error:%@", self.logTag, error.localizedDescription);
                return;
            }
            NSNumber *statusNumber = responseObject[@"status"];
            if (statusNumber.integerValue != 0) {
                OWSLogInfo(@"%@ report meeting error, reason: %@", self.logTag, responseObject[@"reason"]);
                return;
            }
            OWSLogInfo(@"%@ report meeting info success", self.logTag);
        } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            OWSLogError(@"%@ report meeting error:%@", self.logTag, error.asNSError.localizedDescription);
        }];
    }];
}

- (OWSURLSession *)urlSession {
    return [[OWSSignalService sharedInstance] urlSessionForNoneService];
}

+ (NSString *)logTag {
    return @"[dot]";
}

@end
