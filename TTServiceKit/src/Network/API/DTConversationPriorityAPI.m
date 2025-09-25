//
//  DTConversationPriorityAPI.m
//  TTServiceKit
//
//  Created by Kris.s on 2022/8/11.
//

#import "DTConversationPriorityAPI.h"

static const NSUInteger kConversationPriorityAPIRetryCount = 3;

@interface DTConversationPriorityAPI ()

@property (nonatomic, assign) NSUInteger retryCount;

@end

@implementation DTConversationPriorityAPI

- (instancetype)init{
    if(self = [super init]){
        self.retryCount = kConversationPriorityAPIRetryCount;
    }
    return self;
}

- (NSString *)requestMethod{
    return @"POST";
}

- (NSString *)requestUrl{
    return @"/v1/messages/setPriorConversation";
}

- (void)sendRequestWithParams:(NSDictionary *)params
                      success:(DTAPISuccessBlock)success
                      failure:(DTAPIFailureBlock)failure{
    
    NSString *path = [self requestUrl];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:params];
                           
    [self sendRequest:request success:^(DTAPIMetaEntity * _Nonnull entity) {
        self.retryCount = kConversationPriorityAPIRetryCount;
        success(entity);
    } failure:^(NSError * _Nonnull error) {
        if(self.retryCount > 0){
            dispatch_async(dispatch_get_main_queue(), ^{
                [self sendRequestWithParams:params
                                    success:success
                                    failure:failure];
            });
            self.retryCount --;
        }else{
            failure(error);
        }
    }];
}

@end
