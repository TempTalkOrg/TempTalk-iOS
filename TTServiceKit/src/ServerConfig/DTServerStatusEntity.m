//
//  DTServerStatusEntity.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/11/16.
//

#import "DTServerStatusEntity.h"

@implementation DTServerStatusEntity

- (instancetype)init{
    if(self = [super init]){
        self.isAvailable = YES;
        self.timeConsuming = 10;
    }
    return self;
}

@end
