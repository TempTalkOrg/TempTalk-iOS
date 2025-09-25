//
//  DTOutgoingUnreadSyncMessage.h
//  TTServiceKit
//
//  Created by hornet on 2022/7/4.
//

//#import <TTServiceKit/TTServiceKit.h>
#import "OWSOutgoingSyncMessage.h"
#import "DTUnreadEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTOutgoingUnreadSyncMessage : OWSOutgoingSyncMessage

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initSyncMessageWithTimestamp:(uint64_t)timestamp NS_UNAVAILABLE;

- (instancetype)initOutgoingMessageWithUnReadEntity:( DTUnreadEntity * _Nonnull )unreadEntity;
@end

NS_ASSUME_NONNULL_END
