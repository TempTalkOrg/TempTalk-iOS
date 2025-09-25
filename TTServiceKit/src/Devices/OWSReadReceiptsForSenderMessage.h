//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSOutgoingSyncMessage.h"
#import "TSMessageMacro.h"

NS_ASSUME_NONNULL_BEGIN

@class OWSReadReceipt;
@class DTReadPositionEntity;

@interface OWSReadReceiptsForSenderMessage : TSOutgoingMessage

- (instancetype)initOutgoingMessageWithTimestamp:(uint64_t)timestamp
                                        inThread:(nullable TSThread *)thread
                                     messageBody:(nullable NSString *)body
                                   attachmentIds:(NSMutableArray<NSString *> *)attachmentIds
                                expiresInSeconds:(uint32_t)expiresInSeconds
                                 expireStartedAt:(uint64_t)expireStartedAt
                                  isVoiceMessage:(BOOL)isVoiceMessage
                                groupMetaMessage:(TSGroupMetaMessage)groupMetaMessage
                                   quotedMessage:(nullable TSQuotedMessage *)quotedMessage
                                    contactShare:(nullable OWSContact *)contactShare NS_UNAVAILABLE;

- (instancetype)initWithThread:(nullable TSThread *)thread
             messageTimestamps:(NSArray<NSNumber *> *)messageTimestamps
                  readPosition:(DTReadPositionEntity *)readPosition
               messageModeType:(TSMessageModeType) messageModeType;

@end

NS_ASSUME_NONNULL_END
