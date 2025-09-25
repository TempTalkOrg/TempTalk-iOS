//
//  DTServersEntity.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/11/16.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@class DTServerHostEntity;
@class DTServerServEntity;
@class DTServerDomainEntity;
@class DTServerServiceEntity;

extern NSString *const DTServerToChat;
extern NSString *const DTServerToCall;
extern NSString *const DTServerToFileSharing;
extern NSString *const DTServerToSpeech2text;
extern NSString *const DTServerToAvatar;

@interface DTServersEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, strong) NSArray<DTServerHostEntity *> *hosts;
@property (nonatomic, strong) DTServerServEntity *srvs;
@property (nonatomic, strong) NSArray<DTServerDomainEntity *> *domains;
@property (nonatomic, strong) NSArray<DTServerServiceEntity *> *services;
@property (nonatomic, copy) NSString * _Nullable avatarFile;

#pragma mark - public

- (NSString *)servURLPath:(NSString *)server;

@end

@interface DTServerHostEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *certType;
@property (nonatomic, copy) NSString *servTo;

@end

@interface DTServerDomainEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *domain;
@property (nonatomic, copy) NSString *certType;
@property (nonatomic, copy) NSString *label;

@end


@interface DTServerServiceEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSArray<NSString *> *domains;

@end

@interface DTServerServEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *chat;
@property (nonatomic, copy) NSString *call;
@property (nonatomic, copy) NSString *fileSharing;

@end

NS_ASSUME_NONNULL_END
