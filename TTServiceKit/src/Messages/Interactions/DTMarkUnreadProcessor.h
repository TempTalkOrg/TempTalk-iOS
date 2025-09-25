//
//  DTMarkUnreadProcessor.h
//  TTServiceKit
//
//  Created by hornet on 2022/7/4.
//

#import <Foundation/Foundation.h>

@class DSKProtoSyncMessageMarkAsUnread;
@class SDSAnyWriteTransaction;
NS_ASSUME_NONNULL_BEGIN

extern NSString *const DTMarkAsUnreadNotification;

@interface DTMarkUnreadProcessor : NSObject
- (void)processIncomingSyncMessage:(DSKProtoSyncMessageMarkAsUnread *) markAsUnreadMessage
                   serverTimestamp:(UInt64)serverTimestamp
                       transaction:(SDSAnyWriteTransaction *) transaction;
@end

NS_ASSUME_NONNULL_END
