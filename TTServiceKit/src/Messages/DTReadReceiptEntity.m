//
//  DTReadReceiptEntity.m
//  TTServiceKit
//
//  Created by Kris.s on 2022/3/30.
//

#import "DTReadReceiptEntity.h"

@implementation DTReadReceiptEntity

- (instancetype)init{
    if(self = [super init]){
        _timestamps = [NSMutableSet new];
        _whisperMessageType = TSPlainTextMessageType;
    }
    return self;
}

@end
