//
//  Copyright (c) 2017 Open Whisper Systems. All rights reserved.
//

#import "OWSMessageServiceParams.h"
#import "TSConstants.h"
#import "DTApnsMessageBuilder.h"
#import "OWSReadReceiptsForSenderMessage.h"
#import "DTReadPositionEntity.h"
#import "DTRealSourceEntity.h"

@implementation OWSMessageServiceParams

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
//    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
    return @{
        @"type":@"type",
        @"content":@"content",
        @"readReceipt":@"readReceipt",
        @"notification":@"notification",
        @"conversation":@"conversation",
        @"msgType":@"msgType",
        @"readPositions":@"readPositions",
        @"realSource":@"realSource",
        @"detailMessageType":@"detailMessageType",
        @"reactionInfo":@"reactionInfo"
    };
}

+ (NSValueTransformer *)readPositionsJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:[DTReadPositionEntity class]];
}

+ (NSValueTransformer *)realSourceJSONTransformer {
    return [MTLJSONAdapter dictionaryTransformerWithModelClass:[DTRealSourceEntity class]];
}

- (instancetype)initWithType:(TSWhisperMessageType)type
                 recipientId:(NSString *)destination
                      device:(int)deviceId
                     content:(NSData *)content
              registrationId:(int)registrationId
                 readReceipt:(BOOL)readReceipt
                    apnsInfo:(NSDictionary *)apnsInfo
{
    self = [super init];

    if (!self) {
        return self;
    }

    _type = type;
    _destination = destination;
    _destinationDeviceId = deviceId;
    _destinationRegistrationId = registrationId;
    _content = [content base64EncodedString];
    _readReceipt = readReceipt;
    _notification = apnsInfo;

    return self;
}


@end
