//
//  DTCltlogAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/9/22.
//

#import "DTCltlogAPI.h"
#import "TSAccountManager.h"

@implementation DTCltlogAPI

- (NSString *)requestMethod{
    return @"POST";
}

- (NSString *)requestUrl{
    return @"";
}

- (void)sendRequestWithEventName:(NSString *)eventName
                          params:(NSDictionary *)params
                         success:(DTAPISuccessBlock)success
                         failure:(DTAPIFailureBlock)failure{
    
// do nothing.
    
}

@end
