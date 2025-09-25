//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSDeviceProvisioningService.h"
#import "OWSRequestFactory.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@interface OWSDeviceProvisioningService ()

@end

@implementation OWSDeviceProvisioningService

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }

    return self;
}

- (void)provisionWithMessageBody:(NSData *)messageBody
               ephemeralDeviceId:(NSString *)deviceId
                         success:(void (^)(void))successCallback
                         failure:(void (^)(NSError *))failureCallback
{
    TSRequest *request =
        [OWSRequestFactory deviceProvisioningRequestWithMessageBody:messageBody ephemeralDeviceId:deviceId];
    
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        OWSLogVerbose(@"Provisioning request succeeded");
        successCallback();
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        NSError *error = errorWrapper.asNSError;
        if (!error.isNetworkConnectivityFailure) {
            OWSProdError([OWSAnalyticsEvents errorProvisioningRequestFailed]);
        }
        OWSLogVerbose(@"Provisioning request failed with error: %@", error);
        failureCallback(error);
    }];
}

@end

NS_ASSUME_NONNULL_END
