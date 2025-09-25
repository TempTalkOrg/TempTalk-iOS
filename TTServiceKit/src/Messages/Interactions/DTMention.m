//
//  DTMention.m
//  TTServiceKit
//
//  Created by Ethan on 2022/11/8.
//

#import "DTMention.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@implementation DTMention

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];
}

- (instancetype)initWithStart:(uint32_t)start
                       length:(uint32_t)length
                          uid:(NSString *)uid
                  mentionType:(int32_t)mentionType {
    if (self = [super init]) {
        _start = start;
        _length = length;
        _uid = uid;
        _type = mentionType;
    }
    
    return self;
}

+ (NSArray<DTMention *> *)mentionsWithProto:(DSKProtoDataMessage *)dataMessage {
    
    OWSAssertDebug(dataMessage);
    return [DTMention mentionsWithMentionsProto:dataMessage.mentions];
}

+ (NSArray<DTMention *> *)mentionsWithMentionsProto:(NSArray <DSKProtoDataMessageMention *> *)mentionsProto {
        
    if (!mentionsProto || mentionsProto.count == 0) {
        return nil;
    }
    
    NSMutableArray <DTMention *> *mentions = [NSMutableArray new];
    [mentionsProto enumerateObjectsUsingBlock:^(DSKProtoDataMessageMention * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        DTMention *mention = [[DTMention alloc] initWithStart:obj.start
                                                       length:obj.length
                                                          uid:obj.uid
                                                  mentionType:obj.unwrappedType];
        [mentions addObject:mention];
    }];
    
    return mentions.copy;
}

+ (NSArray<DSKProtoDataMessageMention *> *)mentionsProtoWithMentions:(NSArray<DTMention *> *)mentions {
    
    if (!mentions || mentions.count == 0) {
        OWSLogError(@"mentions is nil");
        return nil;
    }
    
    NSMutableArray <DSKProtoDataMessageMention *> *dataMessageMentions = [NSMutableArray new];
    [mentions enumerateObjectsUsingBlock:^(DTMention * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        DSKProtoDataMessageMentionBuilder *builder = [DSKProtoDataMessageMention builder];
        builder.start = obj.start;
        builder.length = obj.length;
        builder.uid = obj.uid;
        builder.type = obj.type;
        
        DSKProtoDataMessageMention *dataMessageMention = [builder buildAndReturnError:nil];
        if (dataMessageMention) {
            [dataMessageMentions addObject:dataMessageMention];
        }
    }];
    
    return dataMessageMentions.copy;
}

+ (NSString *)atPersons:(NSArray <DTMention *> *)mentions {
    
    if (!mentions || mentions.count == 0) {
        return nil;
    }
    NSMutableArray <NSString *> *tmpAtPersons = @[].mutableCopy;
    for (DTMention *mention in mentions) {
        [tmpAtPersons addObject:mention.uid];
    }
    
    return [tmpAtPersons componentsJoinedByString:@";"];
}

@end
