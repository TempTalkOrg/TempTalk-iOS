//
//  AppDelegate+ReportBackgroundStatus.m
//  Wea
//
//  Created by Ethan on 25/05/2023.
//  Copyright © 2023 Difft. All rights reserved.
//

#import "AppDelegate+ReportBackgroundStatus.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <TTServiceKit/OWSRequestFactory.h>
#import <TTServiceKit/OWSDispatch.h>

@implementation AppDelegate (ReportBackgroundStatus)

- (void)reportBackgroundStatusByWebSocket:(BOOL)inBackground {

    OWSRequestMaker *requestMaker = [[OWSRequestMaker alloc] initWithLabel:@"report background status" requestFactoryBlock:^TSRequest * _Nullable{
        return [OWSRequestFactory postUserBackgroundStatus:inBackground];
    } udAuthFailureBlock:^{
        
    } websocketFailureBlock:^{
        
    }];
    
    requestMaker.makeRequestObjc.doneOn([OWSDispatch sendingQueue], ^(OWSRequestMakerResult *result) {
//        NSDictionary *responseObject = result.responseJson;
        OWSLogInfo(@"%@ report background %d success", self.logTag, inBackground);
    }).catch(^(NSError * _Nonnull error) {
        OWSLogError(@"%@ report background %d fail: %@", self.logTag, inBackground, error.localizedDescription);
//        UIApplicationState state = UIApplication.sharedApplication.applicationState;
//        BOOL isCurrentBackground = (state != UIApplicationStateBackground);
//        if (inBackground != isCurrentBackground) {
//            return;
//        }
//        [self reportBackgroundStatusByHttp:inBackground];
    });

//    [self reportBackgroundStatusByHttp:inBackground];
}

- (void)reportBackgroundStatusByHttp:(BOOL)inBackground {
    
    TSRequest *request = [OWSRequestFactory postUserBackgroundStatus:inBackground];
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
//        NSDictionary *responseObject = response.responseBodyJson;
        OWSLogInfo(@"%@ report background %d success", self.logTag, inBackground);
    } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
        OWSLogError(@"%@ report background %d fail: %@", self.logTag, inBackground, error.asNSError.localizedDescription);
    }];
}

@end
