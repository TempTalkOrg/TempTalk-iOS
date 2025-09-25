//
//  DTCallManager.m
//  TTServiceKit
//
//  Created by Felix on 2021/7/30.
//

#import "DTCallManager.h"
#import "OWSRequestFactory.h"
#import "OWSError.h"
#import "TSRequest.h"
#import "TSGroupThread.h"
#import "DTParamsBaseUtils.h"
#import <SignalCoreKit/NSDate+OWS.h>
#import <TTServiceKit/DTFileServiceContext.h>
#import <TTServiceKit/TTServiceKit-Swift.h>

NSString *const DTMeetingKeyValueCollection   = @"DTMeetingKeyValueCollection";
NSString *const DTMeetingVirtualBackgroundKey = @"virtualBackground_v2";
NSString *const DTMeetingVirtualEffectBlur = @"effect_blur";
NSString *const DTMeetingLocalVideoMirrorKey = @"localVideoMirror";
NSString *const DTMeetingCCLanguageKey        = @"cc_language";

const int TSMeetingVersion = 3;

@interface DTCallManager ()

@property (atomic, copy) NSString *meetingAuthToken;
@property (atomic, assign) NSTimeInterval meetingAuthTokenDate;

@property (nonatomic, strong) SDSKeyValueStore *keyValueStore;

@property (nonatomic, strong) DTQueryIdentityKeyApi *queryIdentityKeyApi;

@end

@implementation DTCallManager

- (instancetype)init
{
    self = [super init];
    if (!self) {
        return self;
    }
    
    _keyValueStore = [[SDSKeyValueStore alloc] initWithCollection:DTMeetingKeyValueCollection];

    OWSSingletonAssert();

    return self;
}

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    static id sharedInstance = nil;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];;
    });

    return sharedInstance;
}

+ (NSString *)generateRandomChannelName {
    static int kNumber = 9;

    NSString *sourceStr = @"0123456789";

    NSMutableString *resultStr = [[NSMutableString alloc] init];

    srand((unsigned)time(0));

    for (int i = 0; i < kNumber; i++) {
        unsigned index = rand() % [sourceStr length];
        NSString *oneStr = [sourceStr substringWithRange:NSMakeRange(index, 1)];
        [resultStr appendString:oneStr];
    }

    return [NSString stringWithFormat:@"1%@",resultStr];
}

+ (NSString *)generateGroupChannelNameBy:(TSThread *)thread {
    TSGroupThread *gThread = (TSGroupThread *)thread;
    NSData *groupIdD = gThread.groupModel.groupId;
    NSString *groupIdStr = [groupIdD base64EncodedString];
    groupIdStr = [groupIdStr stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
    return [NSString stringWithFormat:@"G-%@", groupIdStr];
}

- (NSData *)restoreGroupIdFromChannelName:(NSString *)groupChannelName {
    
    NSString *groupIdString = [self restoreGroupIdStringFromChannelName:groupChannelName];
    
    if (groupIdString && groupIdString.length) {

        NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:groupIdString options:0];
        return decodedData;
    } else {

        return nil;
    }
}

- (NSString *)restoreGroupIdStringFromChannelName:(NSString *)groupChannelName {
    OWSAssertDebug(groupChannelName);
    
    if (groupChannelName && groupChannelName.length && [groupChannelName hasPrefix:@"G-"]) {
        
        NSString *temp = [groupChannelName stringByReplacingOccurrencesOfString:@"G-" withString:@""];
        temp = [temp stringByReplacingOccurrencesOfString:@"-" withString:@"/"];
        return temp;
    }
    
    return nil;
}

+ (NSString *)defaultMeetingName {
#if CC
    return @"CC Meeting";
#else
    return [TSConstants.appDisplayName stringByAppendingString:@" Meeting"];
#endif
}

+ (NSString *)defaultInstanceMeetingName {
    return @"instant call";
}

+ (nullable TSThread *)getThreadFromChannelName:(NSString *)channelName transaction:(SDSAnyReadTransaction *)transaction {
    
    __block TSThread *targetThread = nil;
    
    DTVirtualThread *(^getVirtualThread)(NSString *) = ^(NSString *c) {
        DTVirtualThread *virtualThread = [DTVirtualThread getVirtualThreadWithId:channelName transaction:transaction];
        
        return virtualThread;
    };
    
    if ([channelName hasPrefix:@"G-"]) {
        NSData *groupId = [[self sharedInstance] restoreGroupIdFromChannelName:channelName];
        targetThread = [TSGroupThread getThreadWithGroupId:groupId transaction:transaction];
        if (!targetThread) {
            targetThread = getVirtualThread(channelName);
        }
    } else {
        targetThread = getVirtualThread(channelName);
    }
  
    return targetThread;
}

/**
 data =     {
     token = "";
 };
 reason = OK;
 status = 0;
 ver = 1;
 */
- (void)getMeetingAuthSuccess:(void (^)(NSString * authToken))successHandler
                      failure:(void (^)(NSError *error))failureHandler {
    BOOL isValid = [self checkAuthTokenIsValid];
    if (isValid) {
        OWSLogInfo(@"[call] 使用 cache token");
        successHandler(self.meetingAuthToken);
        return;
    }
    
    TSRequest *request = [OWSRequestFactory meetingTokenAuthRequest];
        
    [self.networkManager
     makeRequest:request
     success:^(id<HTTPResponse>  _Nonnull response) {
        NSDictionary *responseObject = response.responseBodyJson;
        
        if (!DTParamsUtils.validateDictionary(responseObject)) {
            [self resetAuthToken];
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            failureHandler(error);
        }
        
        NSNumber *status = responseObject[@"status"];
        if (status.integerValue == 0) {
            NSString *token = responseObject[@"data"][@"token"];
            if (token && [token isKindOfClass:NSString.class]) {
                self.meetingAuthToken = token;
                self.meetingAuthTokenDate = [[NSDate new] timeIntervalSince1970];
                successHandler(token);
            } else {
                [self resetAuthToken];
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                failureHandler(error);
            }
        } else {
            [self resetAuthToken];
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            failureHandler(error);
        }
    }
     failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
        [self resetAuthToken];
        failureHandler(error.asNSError);
    }];
}

- (void)getRTMTokenV1ByUid:(NSString *)uid
                   success:(void (^)(NSDictionary *responseObject))successHandler
                   failure:(void (^)(NSError *error))failureHandler {
    OWSAssertDebug(uid);
    OWSAssertDebug(successHandler);
    OWSAssertDebug(failureHandler);
    
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory getRTMTokenRequestV1:uid];
        request.authToken = authToken;
        
        [self.meetingUrlSession
         performNonmainRequest:request
         success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            successHandler(responseObject);
        }
         failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            return failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        failureHandler(error);
    }];
}

- (void)getPrivateChannelTokenV1WithInvitee:(NSString *)invitee
                              notInContacts:(BOOL)notInContacts
                                meetingName:(NSString *)meetingName
                                    success:(void (^)(id responseObject))successHandler
                                    failure:(void (^)(NSError *error))failureHandler {
    OWSAssertDebug(invitee);
    OWSAssertDebug(successHandler);
    OWSAssertDebug(failureHandler);
    
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory getPrivateChannelTokenRequestV1WithInvitee:invitee notInContacts:notInContacts meetingName:meetingName];
        request.authToken = authToken;
        
        [self.meetingUrlSession
         performNonmainRequest:request
         success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            successHandler(responseObject);
        }
         failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            return failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        return failureHandler(error);
    }];
}

- (void)getPrivateChannelIdentityKeyByUid:(NSString *)uid
                   success:(void (^)(id responseObject))successHandler
                                  failure:(void (^)(NSError *error))failureHandler {
    [self.queryIdentityKeyApi quertIdentity:@[uid] resetIdentityKeyTime:0 sucess:^(id<HTTPResponse>  _Nonnull response) {
        NSDictionary *responseObject = response.responseBodyJson;
        if (!DTParamsUtils.validateDictionary(responseObject)) {
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }
        successHandler(responseObject);
    } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nullable entity) {
        !failureHandler?:failureHandler(error);
    }];
}
- (void)getChannelIdentityKeyByUidArr:(NSArray<NSString *> *)uids
                              success:(void (^)(id responseObject))successHandler
                              failure:(void (^)(NSError *error))failureHandler {
    [self.queryIdentityKeyApi quertIdentity:uids resetIdentityKeyTime:0 sucess:^(id<HTTPResponse>  _Nonnull response) {
        NSDictionary *responseObject = response.responseBodyJson;
        if (!DTParamsUtils.validateDictionary(responseObject)) {
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }
        successHandler(responseObject);
    } failure:^(NSError * _Nonnull error, DTAPIMetaEntity * _Nullable entity) {
        !failureHandler?:failureHandler(error);
    }];
}


- (void)getPrekeyBundleByUid:(NSString *)uid
                   success:(void (^)(id responseObject))successHandler
                                  failure:(void (^)(NSError *error))failureHandler {
    TSRequest *request =
        [OWSRequestFactory recipientPrekeyRequestWithRecipient:uid deviceId:[@1 stringValue]];
//    [self.networkManager makeRequest:request completionQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) success:^(id<HTTPResponse>  _Nonnull response) {
//        NSDictionary *responseObject = response.responseBodyJson;
    
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        NSDictionary *responseObject = response.responseBodyJson;
        if (!DTParamsUtils.validateDictionary(responseObject)) {
            NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
            return failureHandler(error);
        }
        successHandler(responseObject);
    } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
        !failureHandler?:failureHandler(error.asNSError);
    }];
    
}


- (void)requestForConfigMeetingversion {
    NSDictionary *parms = @{@"meetingVersion":@(TSMeetingVersion),@"supportTransfer":@(1), @"msgEncVersion": @(MESSAGE_CURRENT_VERSION)};
    TSRequest *request = [OWSRequestFactory putV1ProfileWithParams:parms];
    [self.networkManager makeRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
        OWSLogInfo(@"requestForconfigMeetingversion sucess");
    } failure:^(OWSHTTPErrorWrapper * _Nonnull errorWrapper) {
        OWSLogInfo(@"requestForconfigMeetingversion fail");
    }];
}

- (void)getInstantChannelTokenV1WithInvitees:(NSArray *)invitees
                                 meetingName:(NSString *)meetingName
                                     success:(void (^)(id responseObject))successHandler
                                     failure:(void (^)(NSError *error))failureHandler {
    OWSAssertDebug(successHandler);
    OWSAssertDebug(failureHandler);
    
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory getInstantChannelTokenRequestV1WithInvitee:invitees meetingName:meetingName];
        request.authToken = authToken;
        
        [self.meetingUrlSession
         performNonmainRequest:request
         success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            successHandler(responseObject);
        }
         failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            return failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        return failureHandler(error);
    }];
}

/*
- (void)getExternalChannelTokenV1WithChannelName:(NSString *)channelName
                                         success:(void (^)(id _Nonnull))successHandler
                                         failure:(void (^)(NSError * _Nonnull))failureHandler {
    OWSAssertDebug(successHandler);
    OWSAssertDebug(failureHandler);
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory getExternalChannelTokenRequestV1WithChannelName:channelName];
        request.authToken = authToken;
        
        [self.meetingUrlSession
         performNonmainRequest:request
         success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            successHandler(responseObject);
        }
         failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            return failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        return failureHandler(error);
    }];
}
*/

- (void)getGroupChannelTokenV1ByChannelName:(NSString *)channelName
                                meetingName:(NSString *)meetingName
                                   invitees:(NSArray *)invitees
                                    encInfo:(NSArray *)encInfo
                             meetingVersion:(int)meetingVersion
                                    success:(void (^)(id responseObject))successHandler
                                    failure:(void (^)(NSError *error))failureHandler {
    OWSAssertDebug(channelName);
    OWSAssertDebug(meetingName);
    OWSAssertDebug(invitees);
    OWSAssertDebug(successHandler);
    OWSAssertDebug(failureHandler);
    
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory getGroupChannelTokenRequestV1:channelName meetingName:meetingName invitees:invitees encInfo:encInfo meetingVersion:meetingVersion];
        request.authToken = authToken;
        
        [self.meetingUrlSession
         performNonmainRequest:request
         success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            successHandler(responseObject);
        }
         failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            return failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        return failureHandler(error);
    }];
}

- (void)addInviteesToChannel:(NSArray *)invitees
                 channelName:(NSString *)channelName
                         eid:(nullable NSString *)eid
                    encInfos:(nullable NSArray *)encInfos
                   publicKey:(nullable NSString *)publicKey
              meetingVersion:(int) meetingVersion
                   meetingId:(nullable NSString *)meetingId
                     success:(void (^)(id responseObject))successHandler
                     failure:(void (^)(NSError *error))failureHandler {
    OWSAssertDebug(successHandler);
    OWSAssertDebug(failureHandler);
    
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory addInviteeToChannelWithInvitee:invitees channelName:channelName eid:eid encInfos:encInfos publicKey:publicKey meetingVersion:meetingVersion meetingId:meetingId];
        request.authToken = authToken;
        
        [self.meetingUrlSession
         performNonmainRequest:request
         success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            successHandler(responseObject);
        }
         failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            return failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        return failureHandler(error);
    }];
}

- (void)getRenewRTCChannelTokenV1ByChannelName:(NSString *)channelName
                                      joinType:(nullable NSString *)joinType
                                     meetingId:(nullable NSString *)meetingId
                                    expireTime:(nullable NSString *)expireTime
                                       success:(void (^)(id responseObject))successHandler
                                       failure:(void (^)(NSError *error))failureHandler {
    OWSAssertDebug(channelName);
    OWSAssertDebug(successHandler);
    OWSAssertDebug(failureHandler);
    
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory getRenewRTCChannelTokenRequestV1:channelName
                                                                        joinType:joinType
                                                                       meetingId:meetingId
                                                                      expireTime:expireTime];
        request.authToken = authToken;
        
        [self.meetingUrlSession
         performNonmainRequest:request
         success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            successHandler(responseObject);
        }
         failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            return failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        return failureHandler(error);
    }];
}

- (void)getUserRelatedChannelV1Success:(void (^)(id responseObject))successHandler
                               failure:(void (^)(NSError *error))failureHandler {
    OWSAssertDebug(successHandler);
    OWSAssertDebug(failureHandler);
    
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory getUserRelatedChannelRequestV1];
        request.authToken = authToken;
        
        [self.meetingUrlSession
         performNonmainRequest:request
         success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            successHandler(responseObject);
        }
         failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            return failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        failureHandler(error);
    }];
}

- (void)getMeetingChannelAndPasswordV1Success:(void (^)(id responseObject))successHandler
                                      failure:(void (^)(NSError *error))failureHandler {
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory getMeetingChannelAndPasswordRequestV1];
        request.authToken = authToken;
        
        [self.meetingUrlSession
         performNonmainRequest:request
         success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            successHandler(responseObject);
        }
         failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            return failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        return failureHandler(error);
    }];
}

- (void)getExternalGroupChannelPasswordV1ByChannelName:(NSString *)channelName
                                           meetingName:(NSString *)meetingName
                                              invitees:(NSArray *)invitees
                                               success:(void (^)(id responseObject))successHandler
                                               failure:(void (^)(NSError *error))failureHandler {
    OWSAssertDebug(channelName);
    OWSAssertDebug(meetingName);
    OWSAssertDebug(invitees);
    OWSAssertDebug(successHandler);
    OWSAssertDebug(failureHandler);
    
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory getExternalGroupChannelTokenRequestV1:channelName meetingName:meetingName invitees:invitees];
        request.authToken = authToken;
        
        [self.meetingUrlSession
         performNonmainRequest:request
         success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            successHandler(responseObject);
        }
         failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            return failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        return failureHandler(error);
    }];
}

- (void)getGroupMeetingDetailsV1ByMeetingId:(NSString *)groupMeetingId
                                    success:(void (^)(id responseObject))successHandler
                                    failure:(void (^)(NSError *error))failureHandler {
    OWSAssertDebug(groupMeetingId);
    OWSAssertDebug(successHandler);
    OWSAssertDebug(failureHandler);
    
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory getGroupMeetingDetailRequestV1:groupMeetingId];
        request.authToken = authToken;
        
        [self.meetingUrlSession
         performNonmainRequest:request
         success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            successHandler(responseObject);
        }
         failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            return failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        return failureHandler(error);
    }];
}

- (void)getMeetingDetailsV1ByMeetingId:(NSString *)meetingId
                               success:(void (^)(id responseObject))successHandler
                               failure:(void (^)(NSError *error))failureHandler {
    OWSAssertDebug(meetingId);
    OWSAssertDebug(successHandler);
    OWSAssertDebug(failureHandler);
    
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory getMeetingDetailRequestV1:meetingId];
        request.authToken = authToken;
        
        [self.meetingUrlSession
         performNonmainRequest:request
         success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            successHandler(responseObject);
        }
         failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            return failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        return failureHandler(error);
    }];
}

- (void)createGroupV1WithGroupName:(nullable NSString *)groupName
                         meetingId:(NSNumber *)meetingId
                         memberIds:(NSArray <NSString *> *)memberIds
                           success:(void (^)(id responseObject))successHandler
                           failure:(void (^)(NSError *error))failureHandler {
    OWSAssertDebug(meetingId);
    OWSAssertDebug(successHandler);
    OWSAssertDebug(failureHandler);
    
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory createMeetingGroupRequestV1WithGroupName:groupName
                                                                               meetingId:meetingId
                                                                               memberIds:memberIds];
        request.authToken = authToken;
        
        [self.meetingUrlSession
         performNonmainRequest:request
         success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            successHandler(responseObject);
        }
         failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            return failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        return failureHandler(error);
    }];
}

- (void)getMeetingOnlineStatusByChannelName:(NSString *)channelName
                                    success:(void (^)(id responseObject))successHandler
                                    failure:(void (^)(NSError *error))failureHandler {
    
    OWSAssertDebug(channelName);
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory getMeetingOnlineUsersRequestV1:channelName];
        request.authToken = authToken;
        [self.meetingUrlSession performNonmainRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            successHandler(responseObject);
        } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            return failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        return failureHandler(error);
    }];
}

- (void)getMeetingShareInfoByChannelName:(NSString *)channelName
                                 success:(void (^)(id responseObject))successHandler
                                 failure:(void (^)(NSError *error))failureHandler {
    
    OWSAssertDebug(channelName);
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory getMeetingShareInfoRequestV1:channelName];
        request.authToken = authToken;
        [self.meetingUrlSession performNonmainRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            successHandler(responseObject);
        } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            return failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        return failureHandler(error);
    }];
}

- (void)getMeetingChannelDetailByChannelName:(NSString *)channelName
                                     success:(void (^)(id responseObject))successHandler
                                     failure:(void (^)(NSError *error))failureHandler {
    
//    OWSAssertDebug(channelName);
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory getMeetingChannelDetailRequestV1:channelName];
        request.authToken = authToken;
        [self.meetingUrlSession performNonmainRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            successHandler(responseObject);
        } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            return failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        return failureHandler(error);
    }];
}

- (void)putMeetingGroupMemberLeaveBychannelName:(NSString *)channelName
                                        success:(void (^)(id responseObject))successHandler
                                        failure:(void (^)(NSError *error))failureHandler {
    
    OWSAssertDebug(channelName);
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory putMeetingGroupMemberLeaveRequestV1:channelName];
        request.authToken = authToken;
        [self.meetingUrlSession performNonmainRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            successHandler(responseObject);
        } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            return failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        return failureHandler(error);
    }];
}

- (void)putMeetingGroupMemberInviteBychannelName:(NSString *)channelName
                                         success:(void (^)(id responseObject))successHandler
                                         failure:(void (^)(NSError *error))failureHandler {
    
    OWSAssertDebug(channelName);
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory putMeetingGroupMemberInviteRequestV1:channelName];
        request.authToken = authToken;
        [self.meetingUrlSession performNonmainRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            successHandler(responseObject);
        } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            return failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        return failureHandler(error);
    }];
}

- (void)putMeetingGroupMemberKickBychannelName:(NSString *)channelName
                                         users:(NSArray <NSString *> *)users
                                       success:(void (^)(id responseObject))successHandler
                                       failure:(void (^)(NSError *error))failureHandler {
    
    OWSAssertDebug(channelName);
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory putMeetingGroupMemberKickRequestV1:channelName users:users];
        request.authToken = authToken;
        [self.meetingUrlSession performNonmainRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            successHandler(responseObject);
        } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            return failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        return failureHandler(error);
    }];
}

- (void)getMeetingHostByChannelName:(NSString *)channelName
                         completion:(void (^)(NSString *host))completion {
    
    if (!channelName) return;
    
    OWSAssertDebug(channelName);
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory getMeetingHostRequestV1:channelName];
        request.authToken = authToken;
        [self.meetingUrlSession performNonmainRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                OWSLogError(@"[call] get meeting host channelName:%@, error: %@", channelName, error.localizedDescription);
                return;
            }
            NSDictionary *responseDict = responseObject;
            NSNumber *statusNumber = responseDict[@"status"];
            if (statusNumber.integerValue != 0) {
                OWSLogError(@"[call] get meeting host channelName:%@, errorStatus: %ld", channelName, statusNumber.integerValue);
                return;
            }
            NSDictionary *data = responseDict[@"data"];
            NSString *host = data[@"host"];
            OWSLogError(@"[call] get meeting host success, channelName:%@, host: %@", channelName, host);
            completion(host);
        } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            OWSLogError(@"[call] get meeting host channelName:%@, error: %@", channelName, error.asNSError.localizedDescription);
        }];
    } failure:^(NSError *error) {
        OWSLogError(@"[call] get meeting host channelName:%@, error: %@", channelName, error.localizedDescription);
    }];
}

- (void)putMeetingHostTransferByChannelName:(NSString *)channelName
                                       host:(NSString *)host
                                    success:(void (^)(id responseObject))successHandler
                                    failure:(void (^)(NSError *error))failureHandler {
    
    OWSAssertDebug(channelName);
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory putMeetingHostTransferRequestV1:channelName host:host];
        request.authToken = authToken;
        [self.meetingUrlSession performNonmainRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                OWSLogError(@"[call] transfer meeting host channelName:%@, error: %@", channelName, error.localizedDescription);
            }
            NSDictionary *responseDict = responseObject;
            NSNumber *statusNumber = responseDict[@"status"];
            if (statusNumber.integerValue != 0) {
                OWSLogError(@"[call] transfer meeting host channelName:%@, errorStatus: %ld", channelName, statusNumber.integerValue);
                return;
            }
            OWSLogError(@"[call] transfer meeting host success, channelName: %@", channelName);
            successHandler(responseObject);
        } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            OWSLogError(@"[call] transfer meeting host channelName:%@, error: %@", channelName, error.asNSError.localizedDescription);
        }];
    } failure:^(NSError *error) {
        OWSLogError(@"[call] transfer meeting host channelName:%@, error: %@", channelName, error.localizedDescription);
    }];
}

- (void)putMeetingHostEndByChannelName:(NSString *)channelName
                               success:(void (^)(id responseObject))successHandler
                               failure:(void (^)(NSError *error))failureHandler {
    
    OWSAssertDebug(channelName);
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory putMeetingHostEndRequestV1:channelName];
        request.authToken = authToken;
        [self.meetingUrlSession performNonmainRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                OWSLogError(@"[call] host end meeting channelName:%@, error: %@", channelName, error.localizedDescription);
            }
            NSDictionary *responseDict = responseObject;
            NSNumber *statusNumber = responseDict[@"status"];
            if (statusNumber.integerValue != 0) {
                OWSLogError(@"[call] host end meeting channelName:%@, errorStatus: %ld", channelName, statusNumber.integerValue);
                return;
            }
            OWSLogError(@"[call] host end meeting success, channelName: %@", channelName);
            successHandler(responseObject);
        } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            OWSLogError(@"[call] host end meeting channelName:%@, error: %@", channelName, error.asNSError.localizedDescription);
        }];
    } failure:^(NSError *error) {
        OWSLogError(@"[call] host end meeting channelName:%@, error: %@", channelName, error.localizedDescription);
    }];
}

- (void)postLocalCameraState:(BOOL)isOpen
                 channelName:(NSString *)channelName
                     account:(NSString *)account
                     success:(void (^)(id responseObject))successHandler
                     failure:(void (^)(NSError *error))failureHandler {
    
    OWSAssertDebug(channelName);
    OWSAssertDebug(account);

    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory postMeetingCameraState:isOpen
                                                           channelName:channelName
                                                               account:account];
        request.authToken = authToken;
        [self.meetingUrlSession performNonmainRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            successHandler(responseObject);
        } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            if (failureHandler) failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        if (failureHandler) failureHandler(error);
    }];
}

- (void)getMeetingUserNameByUid:(NSString *)uid
                        success:(void (^)(NSString *name))successHandler
                        failure:(void (^)(NSError *error))failureHandler {
    
    OWSAssertDebug(uid);
    [self getMeetingAuthSuccess:^(NSString *authToken) {
        TSRequest *request = [OWSRequestFactory getMeetingUserNameRequestV1:uid];
        request.authToken = authToken;
        [self.meetingUrlSession performNonmainRequest:request success:^(id<HTTPResponse>  _Nonnull response) {
            NSDictionary *responseObject = response.responseBodyJson;
            
            if (!DTParamsUtils.validateDictionary(responseObject)) {
                NSError *error = OWSErrorMakeUnableToProcessServerResponseError();
                return failureHandler(error);
            }
            NSDictionary *data = responseObject[@"data"];
            NSString *name = data[@"name"];
            name = name && name.length > 0 ? name : uid;
            successHandler(name);
        } failure:^(OWSHTTPErrorWrapper * _Nonnull error) {
            return failureHandler(error.asNSError);
        }];
    } failure:^(NSError *error) {
        return failureHandler(error);
    }];
}

- (OWSURLSession *)meetingUrlSession {
    return OWSSignalService.sharedInstance.urlSessionForNoneService;
}

- (OWSURLSession *)calendarUrlSession {
    return OWSSignalService.sharedInstance.urlSessionForNoneService;
}

- (OWSURLSession *)captionUrlSession {
    return OWSSignalService.sharedInstance.urlSessionForNoneService;
}

#pragma mark - private

- (void)resetAuthToken {
    self.meetingAuthToken = nil;
    self.meetingAuthTokenDate = 0;
    
    OWSLogInfo(@"[call] 清理 cache token");
}

// TODO: 与文件和状态取 token 重复，需要合并
- (BOOL)checkAuthTokenIsValid{
    
    if (!DTParamsUtils.validateString(self.meetingAuthToken)) {
        [self resetAuthToken];
        return NO;
    }
    
    NSDictionary *tokenInfo = [[self class] decodeWithJwtString:self.meetingAuthToken];
    
    if (!DTParamsUtils.validateNumber(tokenInfo[@"iat"]) ||
        !DTParamsUtils.validateNumber(tokenInfo[@"exp"])) {
        [self resetAuthToken];
        return NO;
    }
    
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval iatTime = [tokenInfo[@"iat"] doubleValue];
    NSTimeInterval expTime = [tokenInfo[@"exp"] doubleValue];
    
    NSTimeInterval expDiffTime = expTime - iatTime;
    if (currentTime - self.meetingAuthTokenDate + 2*60 >= expDiffTime) {
        [self resetAuthToken];
        return NO;
    }
    
    return YES;
}

+ (NSDictionary *)decodeWithJwtString:(NSString *)jwtStr {
    NSArray * segments = [jwtStr componentsSeparatedByString:@"."];
    NSString * base64String = [segments objectAtIndex:1];
    int requiredLength = (int)(4 *ceil((float)[base64String length]/4.0));
    int nbrPaddings = requiredLength - (int)[base64String length];
    if(nbrPaddings > 0) {
        NSString * pading = [[NSString string] stringByPaddingToLength:nbrPaddings withString:@"=" startingAtIndex:0];
        base64String = [base64String stringByAppendingString:pading];
    }
    base64String = [base64String stringByReplacingOccurrencesOfString:@"-" withString:@"+"];
    base64String = [base64String stringByReplacingOccurrencesOfString:@"_" withString:@"/"];
    NSData * decodeData = [[NSData alloc] initWithBase64EncodedData:[base64String dataUsingEncoding:NSUTF8StringEncoding] options:0];
    NSString * decodeString = [[NSString alloc] initWithData:decodeData encoding:NSUTF8StringEncoding];
    
    if (DTParamsUtils.validateString(decodeString)) {
        
        NSDictionary * jsonDict = [NSJSONSerialization JSONObjectWithData:[decodeString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
        return jsonDict;
    } else {
        
        return nil;
    }
}


+ (void)sendGroupMemberChangeMeetingSystemMessageWithThread:(TSThread *)thread
                                           meetingDetailUrl:(NSString *)meetingDetailUrl
                                                transaction:(SDSAnyWriteTransaction *)transaction {
    
    uint64_t now = [NSDate ows_millisecondTimeStamp];
    
    NSMutableAttributedString *attributeMessage = [[NSMutableAttributedString alloc] initWithString:@"The group has an agenda meeting, "];
    NSAttributedString *clickString = [[NSAttributedString alloc] initWithString:@"click here" attributes:@{NSForegroundColorAttributeName : DTGroupUtils.attributeInfoMessageHighlightColor}];
    [attributeMessage appendAttributedString:clickString];
    [attributeMessage appendAttributedString:[[NSAttributedString alloc] initWithString:@" to edit participants."]];

    TSInfoMessage *systemMessage = [[TSInfoMessage alloc] initMeetingInfoMessageWithType:TSInfoMessageGroupMemberChangeMeetingAlert
                                                                               timestamp:now
                                                                         serverTimestamp:0
                                                                     meetingReminderType:DTMeetingReminderTypeUnknow
                                                                        meetingDetailUrl:meetingDetailUrl
                                                                             meetingName:@""
                                                                                inThread:thread
                                                                           customMessage:attributeMessage.copy];
    
    [systemMessage anyInsertWithTransaction:transaction];
}

- (void)storeVirtualBgEffect:(nullable NSString *)effect
                 transaction:(nullable SDSAnyWriteTransaction *)writeTransaction {
    
    if (writeTransaction) {
        [self.keyValueStore setString:effect
                                  key:DTMeetingVirtualBackgroundKey
                          transaction:writeTransaction];
    } else {
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [self.keyValueStore setString:effect
                                      key:DTMeetingVirtualBackgroundKey
                              transaction:transaction];
        });
    }
}

- (nullable NSString *)storedVirtualBgEffectWithTransaction:(nullable SDSAnyReadTransaction *)readTransaction {
    
    if (readTransaction) {
        return [self.keyValueStore getString:DTMeetingVirtualBackgroundKey
                                 transaction:readTransaction];;
    }
    
    __block NSString *storedVirtual = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        storedVirtual = [self.keyValueStore getString:DTMeetingVirtualBackgroundKey 
                                          transaction:transaction];
    }];
    
    return storedVirtual;
}

- (void)storeLocalVideoMirror:(BOOL)mirrorEnable
                  transaction:(nullable SDSAnyWriteTransaction *)writeTransaction {
    
    if (writeTransaction) {
        [self.keyValueStore setBool:mirrorEnable
                                key:DTMeetingLocalVideoMirrorKey
                        transaction:writeTransaction];
    } else {
        DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
            [self.keyValueStore setBool:mirrorEnable
                                    key:DTMeetingLocalVideoMirrorKey
                            transaction:transaction];
        });
    }
}

- (BOOL)storedLocalVideoMirrorWithTransaction:(nullable SDSAnyReadTransaction *)readTransaction {
  
    if (readTransaction) {
        return [self.keyValueStore getBool:DTMeetingLocalVideoMirrorKey
                              defaultValue:YES
                               transaction:readTransaction];
    }
    __block BOOL mirrorEnable = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        mirrorEnable = [self.keyValueStore getBool:DTMeetingLocalVideoMirrorKey
                                      defaultValue:YES
                                       transaction:transaction];
    }];
    
    return mirrorEnable;
}

- (void)storeCClanguage:(NSString *)lang {
  
    DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
        [self.keyValueStore setString:lang key:DTMeetingCCLanguageKey transaction:transaction];
    });
}

- (NSString *)storedCClanguage {
  
    __block NSString *storedLanguage = nil;
    [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
        storedLanguage = [self.keyValueStore getString:DTMeetingCCLanguageKey transaction:transaction];
    }];
   
    if (!storedLanguage) {
        return self.cc_English;
    }
    
    return storedLanguage;
}

- (NSString *)cc_English {
    return @"en-US";
}

- (NSString *)cc_Chinese {
    return @"zh-CN";
}

- (DTQueryIdentityKeyApi *)queryIdentityKeyApi {
    if(!_queryIdentityKeyApi){
        _queryIdentityKeyApi = [DTQueryIdentityKeyApi new];
    }
    return _queryIdentityKeyApi;
}

@end
