//
//  DTThumbUpApi.m
//  Wea
//
//  Created by hornet on 2022/7/28.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTThumbUpApi.h"
#import <SignalCoreKit/Threading.h>


@implementation DTThumbUpApi
- (instancetype)init {
    self = [super init];
    if (self) {
        
    }
    return self;
}

- (NSString *)requestMethod{
    return @"POST";
}

- (NSString *)requestUrl{
    return @"/v1/interacts/thumbsUp";
}

- (void)thumbUpWith:(NSString *)number
            success:(DTAPISuccessBlock)success
            failure:(DTAPIFailureBlock)failure {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (DTParamsUtils.validateString(number)) {
        [params setValue:number forKey:@"number"];
    }
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:[self requestUrl]]
                                            method:[self requestMethod]
                                        parameters:params];
    
    [self sendRequest:request
              success:^(DTAPIMetaEntity * _Nonnull entity) {
        DispatchMainThreadSafe(^{
            if (success) {
                success(entity);
            }
        });
    } failure:^(NSError * _Nonnull error) {
        DispatchMainThreadSafe(^{
            if (failure) {
                failure(error);
            }
        });
    }];
}
@end
