//
//  DTMentionedMsgInfo.m
//  TTServiceKit
//
//  Created by Kris.s on 2022/11/7.
//

#import "DTMentionedMsgInfo.h"

@implementation DTMentionedMsgInfo

- (instancetype)initWithUniqueMessageId:(NSString *)uniqueMessageId
                    timestampForSorting:(uint64_t)timestampForSorting {
    if(self = [super init]){
        _uniqueMessageId = uniqueMessageId;
        _timestampForSorting = timestampForSorting;
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if(![object isKindOfClass:[DTMentionedMsgInfo class]]) return NO;
    DTMentionedMsgInfo *rObjc = (DTMentionedMsgInfo *)object;
    if(((!rObjc.uniqueMessageId && !self.uniqueMessageId) || [rObjc.uniqueMessageId isEqualToString:self.uniqueMessageId]) &&
       rObjc.timestampForSorting == self.timestampForSorting){
        return YES;
    }
    return NO;
}

@end
