//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSOutgoingSyncMessage.h"

NS_ASSUME_NONNULL_BEGIN

@class OWSLinkedDeviceReadReceipt;

@interface OWSReadReceiptsForLinkedDevicesMessage : OWSOutgoingSyncMessage

@property (nonatomic, strong, readonly) NSArray<OWSLinkedDeviceReadReceipt *> *readReceipts;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initSyncMessageWithTimestamp:(uint64_t)timestamp NS_UNAVAILABLE;

- (instancetype)initWithReadReceipts:(NSArray<OWSLinkedDeviceReadReceipt *> *)readReceipts NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
