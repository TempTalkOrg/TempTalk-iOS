//
//  Copyright (c) 2021 Open Whisper Systems. All rights reserved.
//

#import "ProtoUtils.h"
#import "ProfileManagerProtocol.h"
#import "SSKEnvironment.h"
#import "TSThread.h"
#import <SignalCoreKit/Cryptography.h>
#import <TTServiceKit/TTServiceKit-Swift.h>

NS_ASSUME_NONNULL_BEGIN

@implementation ProtoUtils

//+ (OWSAES256Key *)localProfileKey
//{
//    return self.profileManager.localProfileKey;
//}

+ (SSKAES256Key *)localProfileKey
{
    id<ProfileManagerProtocol> profileManager = [TextSecureKitEnv sharedEnv].profileManager;
    return profileManager.localProfileKey;
}

#pragma mark -

+ (BOOL)shouldMessageHaveLocalProfileKey:(TSThread *)thread recipientId:(NSString *_Nullable)recipientId
{
    OWSAssertDebug(thread);
    
    id<ProfileManagerProtocol> profileManager = [TextSecureKitEnv sharedEnv].profileManager;
    
    // For 1:1 threads, we want to include the profile key IFF the
    // contact is in the whitelist.
    //
    // For Group threads, we want to include the profile key IFF the
    // recipient OR the group is in the whitelist.
    if (recipientId.length > 0 && [profileManager isUserInProfileWhitelist:recipientId]) {
        return YES;
    } else if ([profileManager isThreadInProfileWhitelist:thread]) {
        return YES;
    }
    
    return NO;
}

//+ (BOOL)shouldMessageHaveLocalProfileKey:(TSThread *)thread
//                             transaction:(SDSAnyReadTransaction *)transaction
//{
//    OWSAssertDebug(thread);
//    OWSAssertDebug(transaction);
//
//    // Group threads will return YES if the group is in the whitelist
//    // Contact threads will return YES if the contact is in the whitelist.
//    return [self.profileManager isThreadInProfileWhitelist:thread transaction:transaction];
//}
//
//+ (void)addLocalProfileKeyIfNecessary:(TSThread *)thread
//                   dataMessageBuilder:(SSKProtoDataMessageBuilder *)dataMessageBuilder
//                          transaction:(SDSAnyReadTransaction *)transaction
//{
//    OWSAssertDebug(thread);
//    OWSAssertDebug(dataMessageBuilder);
//    OWSAssertDebug(transaction);
//
//    if ([self shouldMessageHaveLocalProfileKey:thread transaction:transaction]) {
//        [dataMessageBuilder setProfileKey:self.localProfileKey.keyData];
//    }
//}
//
//+ (void)addLocalProfileKeyToDataMessageBuilder:(SSKProtoDataMessageBuilder *)dataMessageBuilder
//{
//    OWSAssertDebug(dataMessageBuilder);
//
//    [dataMessageBuilder setProfileKey:self.localProfileKey.keyData];
//}
//
//+ (void)addLocalProfileKeyIfNecessary:(TSThread *)thread
//                   callMessageBuilder:(SSKProtoCallMessageBuilder *)callMessageBuilder
//                          transaction:(SDSAnyReadTransaction *)transaction
//{
//    OWSAssertDebug(thread);
//    OWSAssertDebug(callMessageBuilder);
//    OWSAssertDebug(transaction);
//
//    if ([self shouldMessageHaveLocalProfileKey:thread transaction:transaction]) {
//        [callMessageBuilder setProfileKey:self.localProfileKey.keyData];
//    }
//}
//
//+ (nullable NSString *)parseProtoE164:(nullable NSString *)value name:(NSString *)name
//{
//    if (value == nil) {
//        OWSFailDebug(@"%@ was unexpectedly nil.", name);
//        return nil;
//    }
//    if (value.length == 0) {
//        OWSFailDebug(@"%@ was unexpectedly empty.", name);
//        return nil;
//    }
//    if (![PhoneNumber resemblesE164:value]) {
//        if (SSKDebugFlags.internalLogging) {
//            OWSFailDebug(@"%@ was unexpectedly invalid: %@.", name, value);
//        }
//        OWSFailDebug(@"%@ was unexpectedly invalid.", name);
//        return nil;
//    }
//    return value;
//}

+ (void)addLocalProfileKeyIfNecessary:(TSThread *)thread
                   dataMessageBuilder:(DSKProtoDataMessageBuilder *)dataMessageBuilder
                          recipientId:(NSString *_Nullable)recipientId
{
    OWSAssertDebug(thread);
    
    if(!recipientId.length || [recipientId isEqualToString:@"-1"]){
        return;
    }
    
    if ([self shouldMessageHaveLocalProfileKey:thread recipientId:recipientId]) {
        
        [dataMessageBuilder setProfileKey:self.localProfileKey.keyData];
        
        if (recipientId.length > 0) {
            // Once we've shared our profile key with a user (perhaps due to being
            // a member of a whitelisted group), make sure they're whitelisted.
            id<ProfileManagerProtocol> profileManager = [TextSecureKitEnv sharedEnv].profileManager;
            // FIXME PERF avoid this dispatch. It's going to happen for *each* recipient in a group message.
            //            dispatch_async(dispatch_get_main_queue(), ^{
            DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *writeTransaction) {
                [profileManager addUserToProfileWhitelist:recipientId transaction:writeTransaction];
            });
            //            });
        }
    }
}

+ (void)addLocalProfileKeyWithDataMessageBuilder:(DSKProtoDataMessageBuilder *)dataMessageBuilder;
{
    [dataMessageBuilder setProfileKey:self.localProfileKey.keyData];
}

@end

NS_ASSUME_NONNULL_END
