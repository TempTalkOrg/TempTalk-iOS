//
//  DTIncomingCallMessage.h
//  TTServiceKit
//

#import "TSIncomingMessage.h"

NS_ASSUME_NONNULL_BEGIN

/// Locally-created call message (new-flow createCallMsg). recordType = 64.
@interface DTIncomingCallMessage : TSIncomingMessage

/// 0 = pending (counts as unread), 1 = handled (excluded from unread).
@property (nonatomic, assign) NSInteger callState;

/// Room id of the call this message represents; locator key for clearing.
@property (nonatomic, copy, nullable) NSString *roomId;

@end

NS_ASSUME_NONNULL_END
