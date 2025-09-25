//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSDeviceProvisioningCodeService.h"
#import "OWSRequestFactory.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

NSString *const OWSDeviceProvisioningCodeServiceProvisioningCodeKey = @"verificationCode";

@interface OWSDeviceProvisioningCodeService ()

@end

@implementation OWSDeviceProvisioningCodeService


- (void)requestProvisioningCodeWithSuccess:(void (^)(NSString *))successCallback
                                   failure:(void (^)(NSError *))failureCallback
{
    TSRequest *request = [OWSRequestFactory deviceProvisioningCodeRequest];
    
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        OWSLogVerbose(@"ProvisioningCode request succeeded");
        
        NSDictionary *responseObject = response.responseBodyJson;
        
        if ([(NSObject *)responseObject isKindOfClass:[NSDictionary class]]) {
            NSDictionary *responseDict = (NSDictionary *)responseObject;
            NSString *provisioningCode =
            [responseDict objectForKey:OWSDeviceProvisioningCodeServiceProvisioningCodeKey];
            successCallback(provisioningCode);
        }
    } failure:^(OWSHTTPErrorWrapper * _Nonnull wrapperError) {
        NSError *error = wrapperError.asNSError;
        
        if (!error.isNetworkConnectivityFailure) {
            OWSProdError([OWSAnalyticsEvents errorProvisioningCodeRequestFailed]);
        }
        OWSLogVerbose(@"ProvisioningCode request failed with error: %@", error);
        failureCallback(error);
    }];
}

@end

NS_ASSUME_NONNULL_END
