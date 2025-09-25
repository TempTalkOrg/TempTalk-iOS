//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

@class SDSAnyWriteTransaction;
@class DTReadPositionEntity;

/**
 * Some interactions track read/unread status.
 * e.g. incoming messages and call notifications
 */
@protocol OWSReadTracking <NSObject>

/**
 * Has the local user seen the interaction?
 */
@property (nonatomic, readonly, getter=wasRead) BOOL read;

@property (nonatomic, readonly) uint64_t expireStartedAt;
@property (nonatomic, readonly) uint64_t timestampForSorting;
@property (nonatomic, readonly) NSString *uniqueThreadId;


- (BOOL)shouldAffectUnreadCounts;

/**
 * Used both for *responding* to a remote read receipt and in response to the local user's activity.
 */
- (void)markAsReadAtPosition:(DTReadPositionEntity *)readPosition
              sendReadReceipt:(BOOL)sendReadReceipt
                  transaction:(SDSAnyWriteTransaction *)transaction;

@end
