//
//  DTGetConversationApi.m
//  Signal
//
//  Created by hornet on 2022/6/22.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTGetConversationApi.h"
#import "DTServersConfig.h"
#import "DTConversationNotifyEntity.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "DTChatFolderManager.h"

@implementation DTGetConversationApi

- (instancetype)init {
    if (self = [super init]) {
        self.serverType = DTServerTypeChat;
    }
    return self;
}

- (NSString *)requestMethod {
    return @"POST";
}

- (NSString *)requestUrl {
    return @"/v1/conversation/get";
}

//{"conversations":["+72212204429","gid1"]}
- (void)requestMuteStatusWithConversationIds:(NSArray *)conversations
                                          success:(void(^)(NSArray<DTConversationEntity*>*)) sucessBlock
                                         failure:(void(^)(NSError*))failure {
    
    if(!DTParamsUtils.validateArray(conversations)){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    
    NSDictionary *params = @{@"conversations":conversations};
    NSString *path = [self requestUrl];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:params.copy];
//    request.availableUrls = [[DTServersConfig fetchServersConfig].chat mutableCopy];
    [self sendRequest:request success:^(DTAPIMetaEntity * _Nonnull entity) {
        if (DTParamsUtils.validateArray(entity.data[@"conversations"])) {
            NSError *error;
            NSArray *conversationArr = entity.data[@"conversations"];
            conversationArr = [MTLJSONAdapter modelsOfClass:DTConversationEntity.class fromJSONArray:conversationArr error:&error];
            if (error) {
                failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusDataError, kDTAPIDataErrorDescription));
            } else {
                if (sucessBlock) {
                    sucessBlock(conversationArr);
                }
            }
        } else if (entity.data[@"conversations"] 
                   && [entity.data[@"conversations"] isKindOfClass:[NSArray class]]) {
            NSArray *dataArr = (NSArray *)entity.data[@"conversations"];
            if(dataArr.count == 0){
                if (sucessBlock) {
                    sucessBlock(dataArr);
                }
            }
        } else {
            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusDataError, kDTAPIDataErrorDescription));
        }
        
    } failure:^(NSError * _Nonnull error) {
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusDataError, kDTAPIDataErrorDescription));
    }];
}



@end
