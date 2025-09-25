//
//  DTSessionRecord.m
//  TTServiceKit
//
//  Created by Kris.s on 2023/5/16.
//

#import "DTSessionRecord.h"

@implementation DTSessionRecord

- (instancetype)initWithVersion:(int)version
              remoteIdentityKey:(NSData *)remoteIdentityKey
           remoteRegistrationId:(NSInteger)remoteRegistrationId {
    if(self = [super init]){
        self.version = version;
        self.remoteIdentityKey = remoteIdentityKey;
        self.remoteRegistrationId = remoteRegistrationId;
    }
    return self;
}

@end
