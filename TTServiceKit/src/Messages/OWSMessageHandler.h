//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

NS_ASSUME_NONNULL_BEGIN

@class DSKProtoContent;
@class DSKProtoDataMessage;
@class DSKProtoEnvelope;

NSString *envelopeAddress(DSKProtoEnvelope *envelope);

@interface OWSMessageHandler : NSObject

- (NSString *)descriptionForEnvelopeType:(DSKProtoEnvelope *)envelope;
- (NSString *)descriptionForEnvelope:(DSKProtoEnvelope *)envelope;
- (NSString *)descriptionForContent:(DSKProtoContent *)content;
- (NSString *)descriptionForDataMessage:(DSKProtoDataMessage *)dataMessage;

@end

NS_ASSUME_NONNULL_END
