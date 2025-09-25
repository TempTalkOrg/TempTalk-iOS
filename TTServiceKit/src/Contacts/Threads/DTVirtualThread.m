//
//  DTVirtualThread.m
//  TTServiceKit
//
//  Created by Felix on 2022/5/13.
//

#import "DTVirtualThread.h"
//
#import <TTServiceKit/TTServiceKit-Swift.h>

@implementation DTVirtualThread

+ (nullable instancetype)getVirtualThreadWithId:(NSString *)virtualId
                                    transaction:(SDSAnyReadTransaction *)transaction {
    
    return [DTVirtualThread anyFetchDTVirtualThreadWithUniqueId:virtualId transaction:transaction];
}

- (NSString *)channelName {
    return self.uniqueId;
}

#pragma mark -

- (BOOL)isGroupThread {
    return NO;
}

- (BOOL)isLargeGroupThread {
    return NO;
}

- (BOOL)isWithoutReadRecipt {
    return NO;
}

- (BOOL)startMeetingWithoutInvitation {
    return YES;
}

#pragma mark - AbstractMethod

- (NSString *)serverThreadId {
    
    return nil;
}

- (BOOL)isHavePermissioncanSpeak {
    
    return YES;
}

- (NSString *)nameWithTransaction:(nullable SDSAnyReadTransaction *)transaction {
    
    return [DTCallManager defaultMeetingName];
}

- (NSString *)debugName {
    
    return @"Virtual Thread";
}

- (NSArray<NSString *> *)recipientIdentifiers {
    return @[];
}

- (BOOL)recipientsContainsBot {
    
    return NO;
}

@end
