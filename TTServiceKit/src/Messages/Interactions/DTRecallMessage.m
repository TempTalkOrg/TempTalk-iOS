//
//  DTRecallMessage.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/12/23.
//

#import "DTRecallMessage.h"
#import "DTParamsBaseUtils.h"
#import "DTMention.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@implementation DTRecallMessage

- (instancetype)initWithTimestamp:(uint64_t)timestamp
                           source:(DTRealSourceEntity *)source
                             body:(NSString *)body
                        atPersons:(NSString *)atPersons
                         mentions:(nullable NSArray <DTMention *> *)mentions {
    if(self = [super init]){
        self.timestamp = timestamp;
        self.source = source;
        self.body = body;
        self.atPersons = atPersons;
        _mentions = mentions;
    }
    return self;
}

+ (DTRecallMessage *)recallWithDataMessage:(DSKProtoDataMessage *)dataMessage{
    OWSAssertDebug(dataMessage);
    if(!dataMessage.recall){
        return nil;
    }
    
    if(!dataMessage.recall.source){
        OWSProdError(@"recall message have no source");
        return nil;
    }
    
    DSKProtoRealSource *sourceProto = dataMessage.recall.source;
    
    DTRecallMessage *recall = [DTRecallMessage new];
    DTRealSourceEntity * sourceEntity = [DTRealSourceEntity realSourceEntityWithProto:sourceProto];
    recall.source = sourceEntity;
    
    if(![recall checkIntegrity]){
        OWSProdError(@"recall message integrity false");
        return nil;
    }
    
    return recall;
}

- (BOOL)checkIntegrity{
    if(self.source.timestamp > 0 &&
       self.source.sourceDevice > 0 &&
       DTParamsUtils.validateString(self.source.source)){
        return YES;
    }
    return NO;
}

- (NSString *)description{
    return [NSString stringWithFormat:@"<source.timestamp:%lld, source.sourceDevice:%u, source.source:%@>", self.source.timestamp, self.source.sourceDevice, self.source.source];
}

- (void)clearOriginContent {
    self.body = @"";
    self.atPersons = @"";
    _mentions = @[];
}

- (BOOL)isValidRecallMessageWithSource:(NSString *)source {
    if (!DTParamsUtils.validateString(source) ||
        !DTParamsUtils.validateString(self.source.source) ||
        ![source isEqualToString:self.source.source]) {
        return false;
    }
    return true;
}

@end
