//
//  DTSetConversationApi.m
//  Signal
//
//  Created by hornet on 2022/6/22.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTSetConversationApi.h"
#import "DTServersConfig.h"
#import "DTConversationNotifyEntity.h"


@implementation DTSetConversationApi

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
    return @"/v1/conversation/set";
}

- (void)requestConfigMuteStatusWithConversationID:(NSString *)conversation
                                       muteStatus:(NSNumber *)muteStatus
                                          success:(void(^)(DTConversationEntity*)) sucessBlock
                                         failure:(void(^)(NSError*))failure {
    if(!DTParamsUtils.validateString(conversation)){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    NSDictionary *params = @{@"conversation":conversation,@"muteStatus":muteStatus};
    [self requestWithParmas:params success:sucessBlock failure:failure];
}


- (void)requestConfigBlockStatusWithConversationID:(NSString *)conversation
                                       blockStatus:(NSNumber *)blockStatus
                                          success:(void(^)(DTConversationEntity*)) sucessBlock
                                           failure:(void(^)(NSError*))failure {
    if(!DTParamsUtils.validateString(conversation)){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    NSDictionary *params = @{@"conversation":conversation,@"blockStatus":blockStatus};
    [self requestWithParmas:params success:sucessBlock failure:failure];
}

- (void)requestConfigConfidentialModeWithConversationID:(NSString *)conversation
                                       confidentialMode:(NSInteger)confidentialMode
                                          success:(void(^)(DTConversationEntity*)) sucessBlock
                                           failure:(void(^)(NSError*))failure {
    if(!DTParamsUtils.validateString(conversation)){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    NSDictionary *params = @{@"conversation":conversation,@"confidentialMode":@(confidentialMode)};
    [self requestWithParmas:params success:sucessBlock failure:failure];
}

- (void)requestWithParmas:(NSDictionary *)params success:(void(^)(DTConversationEntity*)) sucessBlock
                  failure:(void(^)(NSError*))failure{
    NSString *path = [self requestUrl];
    TSRequest *request = [TSRequest requestWithUrl:[NSURL URLWithString:path]
                                            method:[self requestMethod]
                                        parameters:params.copy];
//    request.availableUrls = [[DTServersConfig fetchServersConfig].chat mutableCopy];
    [self sendRequest:request success:^(DTAPIMetaEntity * _Nonnull entity) {
        NSError *error;
        DTConversationEntity *dataEntity = [MTLJSONAdapter modelOfClass:[DTConversationEntity class]
                                                        fromJSONDictionary:entity.data
                                                                     error:&error];
        if (error) {
            failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusDataError, kDTAPIDataErrorDescription));
        } else {
            if (sucessBlock) {
                sucessBlock(dataEntity);
            }
        }
        
    } failure:^(NSError * _Nonnull error) {
        
    }];
}

- (void)requestConfigConractRemarkWithConversationID:(NSString *)conversation
                                              remark:(NSString *)aesRemarkNameString
                                             success:(void(^)(DTConversationEntity*)) sucessBlock
                                             failure:(void(^)(NSError*))failure {
    if(!DTParamsUtils.validateString(conversation)){
        failure(DTErrorWithCodeDescription(DTAPIRequestResponseStatusParamsError, kDTAPIParamsErrorDescription));
        return;
    }
    NSString *remarkNameSecretText = DTParamsUtils.validateString(aesRemarkNameString) ?  [NSString stringWithFormat:@"V1|%@",aesRemarkNameString] : @"";
    NSDictionary *params = @{@"conversation":conversation,@"remark":remarkNameSecretText};
    [self requestWithParmas:params success:sucessBlock failure:failure];
}

@end
