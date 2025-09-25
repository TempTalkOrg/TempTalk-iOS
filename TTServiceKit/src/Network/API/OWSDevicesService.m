//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSDevicesService.h"
#import "OWSDevice.h"
#import "OWSError.h"
#import "OWSRequestFactory.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <Mantle/MTLJSONAdapter.h>

NS_ASSUME_NONNULL_BEGIN

@implementation OWSDevicesService

+ (void)getDevicesWithSuccess:(void (^)(NSArray<OWSDevice *> *))successCallback
                      failure:(void (^)(NSError *))failureCallback
{
    TSRequest *request = [OWSRequestFactory getDevicesRequest];
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        OWSLogVerbose(@"Get devices request succeeded");
        
        NSDictionary *responseObject = response.responseBodyJson;
        
        NSArray<OWSDevice *> *devices = [self parseResponse:responseObject];
        
        if (devices) {
            successCallback(devices);
        } else {
            DDLogError(@"%@ unable to parse devices response:%@", self.logTag, responseObject);
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            failureCallback(error);
        }
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        NSError *error = errorWrapper.asNSError;
        
        if (!error.isNetworkConnectivityFailure) {
            OWSProdError([OWSAnalyticsEvents errorGetDevicesFailed]);
        }
        DDLogVerbose(@"Get devices request failed with error: %@", error);
        failureCallback(error);
    }];
}

+ (void)unlinkDevice:(OWSDevice *)device
             success:(void (^)(void))successCallback
             failure:(void (^)(NSError *))failureCallback
{
    TSRequest *request = [OWSRequestFactory deleteDeviceRequestWithDevice:device];

    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        DDLogVerbose(@"Delete device request succeeded");
        successCallback();
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        NSError *error = errorWrapper.asNSError;
        
        if (!error.isNetworkConnectivityFailure) {
            OWSProdError([OWSAnalyticsEvents errorUnlinkDeviceFailed]);
        }
        DDLogVerbose(@"Get devices request failed with error: %@", error);
        failureCallback(error);
    }];
}

+ (NSArray<OWSDevice *> *)parseResponse:(id)responseObject
{
    if (![responseObject isKindOfClass:[NSDictionary class]]) {
        DDLogError(@"Device response was not a dictionary.");
        return nil;
    }
    NSDictionary *response = (NSDictionary *)responseObject;

    NSArray<NSDictionary *> *devicesAttributes = response[@"devices"];
    if (!devicesAttributes) {
        DDLogError(@"Device response had no devices.");
        return nil;
    }

    NSMutableArray<OWSDevice *> *devices = [NSMutableArray new];
    for (NSDictionary *deviceAttributes in devicesAttributes) {
        NSError *error;
        OWSDevice *device = [OWSDevice deviceFromJSONDictionary:deviceAttributes error:&error];
        if (error) {
            DDLogError(@"Failed to build device from dictionary with error: %@", error);
        } else {
            [devices addObject:device];
        }
    }

    return [devices copy];
}

+ (void)checkIfKickedOffComplete:(void (^)(BOOL kickedOff))complete
{
    TSRequest *request = [OWSRequestFactory getDevicesRequest];
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        OWSLogVerbose(@"Get devices request succeeded");

        !complete ? : complete(NO);
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        
        NSInteger statusCode = errorWrapper.asNSError.httpStatusCode.integerValue;
        
        BOOL kickedOff = NO;
        if (401 == statusCode ||
            403 == statusCode) {
            kickedOff = YES;
        }
        !complete ? : complete(kickedOff);
    }];
}

@end

NS_ASSUME_NONNULL_END
