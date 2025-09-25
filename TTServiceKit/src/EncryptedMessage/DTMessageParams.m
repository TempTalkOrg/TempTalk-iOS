//
//  DTMessageParams.m
//  TTServiceKit
//
//  Created by Kris.s on 2023/5/23.
//

#import "DTMessageParams.h"
#import "TSConstants.h"
#import "DTApnsMessageBuilder.h"
#import "OWSReadReceiptsForSenderMessage.h"
#import "DTReadPositionEntity.h"
#import "DTMsgPeerContextParams.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
@implementation DTMessageParams

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{
        @"type":@"type",
        @"content":@"content",
        @"legacyContent":@"legacyContent",
        @"readReceipt":@"readReceipt",
        @"notification":@"notification",
        @"conversation":@"conversation",
        @"msgType":@"msgType",
        @"readPositions":@"readPositions",
        @"realSource":@"realSource",
        @"detailMessageType":@"detailMessageType",
        @"timestamp":@"timestamp",
        @"silent":@"silent",
        @"recipients":@"recipients"
    };
}

+ (NSValueTransformer *)readPositionsJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:[DTReadPositionEntity class]];
}

+ (NSValueTransformer *)realSourceJSONTransformer {
    return [MTLJSONAdapter dictionaryTransformerWithModelClass:[DTRealSourceEntity class]];
}

+ (NSValueTransformer *)recipientsJSONTransformer {
    return [MTLJSONAdapter arrayTransformerWithModelClass:[DTMsgPeerContextParams class]];
}

- (instancetype)initWithType:(TSWhisperMessageType)type
                     content:(NSData *)content
               legacyContent:(NSData * __nullable)legacyContent
                 readReceipt:(BOOL)readReceipt
                    apnsInfo:(NSDictionary *)apnsInfo
{
    self = [super init];

    if (!self) {
        return self;
    }

    _type = (int)type;
    _content = [content base64EncodedString];
    if(legacyContent){
        _legacyContent = [legacyContent base64EncodedString];
    }
    _readReceipt = readReceipt;
    _notification = apnsInfo;

    return self;
}

@end
