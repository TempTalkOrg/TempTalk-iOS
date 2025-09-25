//
//  DTTokenKeychainStore.m
//  TTServiceKit
//
//  Created by Kris.s on 2022/11/11.
//

#import "DTTokenKeychainStore.h"
#import <SAMKeychain/SAMKeychain.h>
#import "TSAccountManager.h"

@implementation DTTokenKeychainStore

+ (void)setPassword:(NSString *)password forAccount:(NSString *)key {
    NSString *keyChainServiceName = [self keyChainServiceName];
    NSString *localKey = [self localKeyWithKey:key];
    if (keyChainServiceName) {
        [SAMKeychain setPassword:password forService:keyChainServiceName account:localKey];
    }
}

+ (NSString *)localKeyWithKey:(NSString *)key {
    return [NSString stringWithFormat:@"%@_%@",[TSAccountManager sharedInstance].localNumber.length ? [TSAccountManager sharedInstance].localNumber : @"",key];
}

+ (nullable NSString *)loadPasswordWithAccountKey:(NSString *)key {
    if (!key) {
        return nil;
    }
    NSString *localKey = [self localKeyWithKey:key];
    return [SAMKeychain passwordForService:[self keyChainServiceName] account:localKey];
}

+ (NSString *)keyChainServiceName {
    NSString *bundleID = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleIdentifier"];
    NSString *appendServiceName = NSStringFromSelector(_cmd);
    return [NSString stringWithFormat:@"%@%@",bundleID,appendServiceName];
}

+ (NSString *)UUIDString {
    return [[NSUUID UUID] UUIDString];
}

@end
