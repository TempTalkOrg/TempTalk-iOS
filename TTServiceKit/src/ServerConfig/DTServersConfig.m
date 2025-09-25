//
//  DTServersConfig.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/11/16.
//

#import "DTServersConfig.h"
#import "DTServerConfigManager.h"
#import "DTParamsBaseUtils.h"

@implementation DTServersConfig

+ (DTServersEntity *)fetchServersConfig{
    __block DTServersEntity *result = nil;
    
    [[DTServerConfigManager sharedManager] fetchServersConfigCompletion:^(id _Nonnull config, NSError * _Nonnull error) {
        if(error || config == nil){
            DTServersEntity *entity = [self fetchServersDefaultConfig];
            result = entity;
            
        }else{
            NSError *error;
            DTServersEntity *entity = [MTLJSONAdapter modelOfClass:[DTServersEntity class] fromJSONDictionary:config error:&error];
            if(!error && [self isValidateEntity:entity]){
                result = entity;
            }else{
                DTServersEntity *entity = [self fetchServersDefaultConfig];
                result = entity;
                OWSLogError(@"Multi-server ：%@ using config from disk error: %@",self.logTag, error.localizedDescription);
            }
        }
    }];
    
    return result;
}

+ (DTServersEntity *)fetchServersDefaultConfig {
        
    DTServersEntity *entity = nil;
#if POD_CONFIGURATION_RELEASE_CHATIVETEST || POD_CONFIGURATION_RELEASE_TEST || POD_CONFIGURATION_DEBUG_TEST
    entity = [MTLJSONAdapter modelOfClass:[DTServersEntity class] fromJSONDictionary:[self defaultConfig] error:nil];
#else // 正式环境 scheme: Debug Release Release_test Release_cc
    entity = [MTLJSONAdapter modelOfClass:[DTServersEntity class] fromJSONDictionary:[self defaultConfig] error:nil];
    if(![self isValidateEntity:entity]){
        entity = [DTServersEntity new];
        DTServerHostEntity *hostEntity = [DTServerHostEntity new];
        hostEntity.name = @"chat.chative.im";
        hostEntity.certType = @"self";
        hostEntity.servTo = @"chat";
        entity.hosts = @[hostEntity];
        
        DTServerDomainEntity *domainEntity = [DTServerDomainEntity new];
        domainEntity.domain = @"chat.chative.im";
        domainEntity.certType = @"self";
        domainEntity.label = @"chat1";
        
        DTServerDomainEntity *avatarDomainEntity = [DTServerDomainEntity new];
        avatarDomainEntity.domain = @"d272r1ud4wbyy4.cloudfront.net";
        avatarDomainEntity.certType = @"authority";
        avatarDomainEntity.label = @"avatar";
        
        DTServerServiceEntity *serviceChatEntity = [DTServerServiceEntity new];
        serviceChatEntity.domains = @[domainEntity];
        serviceChatEntity.name = @"chat";
        serviceChatEntity.path = @"/chat";
        
        DTServerServiceEntity *serviceCallEntity = [DTServerServiceEntity new];
        serviceCallEntity.domains = @[domainEntity];
        serviceCallEntity.name = @"call";
        serviceCallEntity.path = @"/call";

        DTServerServiceEntity *serviceFileShareEntity = [DTServerServiceEntity new];
        serviceFileShareEntity.domains = @[domainEntity];
        serviceFileShareEntity.name = @"fileSharing";
        serviceFileShareEntity.path = @"/fileSharing";
        
        DTServerServiceEntity *serviceSpeech2textEntity = [DTServerServiceEntity new];
        serviceSpeech2textEntity.domains = @[domainEntity];
        serviceSpeech2textEntity.name = @"speech2text";
        serviceSpeech2textEntity.path = @"/speech2text";
        
        DTServerServiceEntity *serviceAvatarEntity = [DTServerServiceEntity new];
        serviceAvatarEntity.domains = @[avatarDomainEntity];
        serviceAvatarEntity.name = @"avatar";
        serviceAvatarEntity.path = @"";
        
        
        entity.services = @[serviceChatEntity, serviceCallEntity, serviceFileShareEntity, serviceSpeech2textEntity, serviceAvatarEntity];
        
    }
#endif
    
    return entity;
}


+ (BOOL)isValidateEntity:(DTServersEntity *)entity{
    if (!DTParamsUtils.validateArray(entity.hosts) ||
        !entity.srvs ||
        !DTParamsUtils.validateString(entity.avatarFile)) {
        return NO;
    }
    
    return YES;
}

+ (BOOL)hasLegalUrl:(NSArray *)array{
    __block BOOL hasLegalUrl = NO;
    [array enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSURL *url = [NSURL URLWithString:obj];
        if(DTParamsUtils.validateString(url.host)){
            hasLegalUrl = YES;
        }
    }];
    return hasLegalUrl;
}
     
+ (NSDictionary *)defaultConfig{

#if POD_CONFIGURATION_RELEASE_CHATIVETEST || POD_CONFIGURATION_RELEASE_TEST || POD_CONFIGURATION_DEBUG_TEST
    return @{
        @"hosts": @[
            @{
                @"name": @"chat.test.chative.im",
                @"certType": @"authority",
                @"servTo": @"fuse"
            },
            @{
                @"name": @"chat.test.chative.im",
                @"certType": @"self",
                @"servTo": @"chat"
            },
        ],
        @"srvs": @{
            @"chat": @"/chat",
            @"voice": @"/voice",
            @"call": @"/call",
            @"fileSharing": @"/fileshare",
            @"translate": @"/translate",
            @"miniProgram": @"/mp",
            @"caption": @"/caption",
            @"conversationConfig": @"/conversationConfig",
            @"webauthn": @"/webauthn"
        },
        @"avatarFile": @"https://dtsgla5wj1qp2.cloudfront.net",
        @"domains": @[
            @{
                @"certType": @"self",
                @"domain": @"chat.test.chative.im",
                @"label": @"chat1"
            },
            @{
                @"certType": @"authority",
                @"domain": @"dtsgla5wj1qp2.cloudfront.net",
                @"label": @"avatar"
            }
        ],
        @"services": @[
            @{
                @"domains": @[
                    @"chat1"
                ],
                @"name": @"chat",
                @"path": @"/chat"
            },
            @{
                @"domains": @[
                    @"chat1"
                ],
                @"name": @"call",
                @"path": @"/call"
            },
            @{
                @"domains": @[
                    @"chat1"
                ],
                @"name": @"fileSharing",
                @"path": @"/fileSharing"
            },
            @{
                @"domains": @[
                    @"chat1"
                ],
                @"name": @"speech2text",
                @"path": @"/speech2text"
            },
            @{
                @"domains": @[
                    @"avatar"
                ],
                @"name": @"avatar",
                @"path": @""
            }
        ]
    };
#else
    return @{
        @"hosts": @[
            @{
                @"name": @"chat.chative.im",
                @"certType": @"authority",
                @"servTo": @"fuse"
            },
            @{
                @"name": @"chat.chative.im",
                @"certType": @"self",
                @"servTo": @"chat"
            },
        ],
        @"srvs": @{
            @"chat": @"/chat",
            @"voice": @"/voice",
            @"call": @"/call",
            @"fileSharing": @"/fileshare",
            @"translate": @"/translate",
            @"miniProgram": @"/mp",
            @"caption": @"/caption",
            @"conversationConfig": @"/conversationConfig",
        },
        @"avatarFile": @"https://d272r1ud4wbyy4.cloudfront.net",
        @"domains": @[
            @{
                @"certType": @"self",
                @"domain": @"chat.chative.im",
                @"label": @"chat1"
            },
            @{
                @"certType": @"self",
                @"domain": @"chat.chative.online",
                @"label": @"chat2"
            },
            @{
                @"certType": @"self",
                @"domain": @"chat.chative.ninja",
                @"label": @"chat3"
            },
            @{
                @"certType": @"self",
                @"domain": @"chat.temptalk.net",
                @"label": @"chat4"
            },
            @{
                @"certType": @"authority",
                @"domain": @"d272r1ud4wbyy4.cloudfront.net",
                @"label": @"avatar"
            }
        ],
        @"services": @[
            @{
                @"domains": @[
                    @"chat1",
                    @"chat2",
                    @"chat3",
                    @"chat4",
                ],
                @"name": @"chat",
                @"path": @"/chat"
            },
            @{
                @"domains": @[
                    @"chat1",
                    @"chat2",
                    @"chat3",
                    @"chat4",
                ],
                @"name": @"call",
                @"path": @"/call"
            },
            @{
                @"domains": @[
                    @"chat1",
                    @"chat2",
                    @"chat3",
                    @"chat4",
                ],
                @"name": @"fileSharing",
                @"path": @"/fileSharing"
            },
            @{
                @"domains": @[
                    @"chat1",
                    @"chat2",
                    @"chat3",
                    @"chat4",
                ],
                @"name": @"speech2text",
                @"path": @"/speech2text"
            },
            @{
                @"domains": @[
                    @"avatar"
                ],
                @"name": @"avatar",
                @"path": @""
            }
        ]
    };
#endif
}

+ (NSString *)convertToWebSocketUrlWithOriginUrl:(NSString *)originUrl serverType:(DTServerType)serverType{
    
    NSString *urlString = originUrl;
    
    if ([urlString hasPrefix:@"http"] ||
        [urlString hasPrefix:@"https"]) {
        
        NSURL *url = [NSURL URLWithString:urlString];
        urlString = [NSString stringWithFormat:@"wss://%@", url.host];
        if (DTParamsUtils.validateString(url.path)) {
            urlString = [urlString stringByAppendingString:url.path];
        }
        if (url.port) {
            urlString = [urlString stringByAppendingFormat:@":%@", url.port];
        }
    } else {
        urlString = [NSString stringWithFormat:@"wss://%@", originUrl];
    }
    
    if(serverType == DTServerTypeChat){
        return [NSString stringWithFormat:@"%@/v1/websocket/",urlString];
    }else if(serverType == DTServerTypeUserStatus){
        return [NSString stringWithFormat:@"%@/ws?token=",urlString];
    }else{
        return urlString;
    }
}

@end
