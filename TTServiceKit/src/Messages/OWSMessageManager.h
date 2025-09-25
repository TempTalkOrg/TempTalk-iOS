//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//

#import "OWSMessageHandler.h"
#import "TSIncomingMessage.h"

NS_ASSUME_NONNULL_BEGIN

@class OWSMessageContentJob;
@class TSThread;
@class TSMessage;
@class SDSAnyWriteTransaction;

@interface OWSMessageManager : OWSMessageHandler

@property (nonatomic, assign) BOOL handleUnsupportedMessage;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)sharedManager;

/// processEnvelope: can be called from any thread.
/// Note: hotDataDestination - hot data 主动拉取的消息有一部分 syncMessage 是以 dataMessage 形式发送过来的，需要知道是哪个 1on1 会话的
- (void)processEnvelopeJob:(OWSMessageContentJob *_Nullable)job
                  envelope:(DSKProtoEnvelope *)envelope
             plaintextData:(NSData *_Nullable)plaintextData
        hotDataDestination:(NSString *_Nullable)hotDataDestination
               transaction:(SDSAnyWriteTransaction *)writeTransaction;

- (void)finalizeIncomingMessage:(TSIncomingMessage *)incomingMessage
                         thread:(TSThread *)thread
                    transaction:(SDSAnyWriteTransaction *)transaction;

@end

NS_ASSUME_NONNULL_END
