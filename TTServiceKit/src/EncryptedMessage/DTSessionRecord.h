//
//  DTSessionRecord.h
//  TTServiceKit
//
//  Created by Kris.s on 2023/5/16.
//

#import "TSYapDatabaseObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTSessionRecord : TSYapDatabaseObject

//消息加密协议版本号
@property (nonatomic, assign) int version;

@property (nonatomic, strong) NSData *remoteIdentityKey;

@property(nonatomic, assign) NSInteger remoteRegistrationId;

- (instancetype)initWithVersion:(int)version
              remoteIdentityKey:(NSData *)remoteIdentityKey
           remoteRegistrationId:(NSInteger)remoteRegistrationId;

@end

NS_ASSUME_NONNULL_END
