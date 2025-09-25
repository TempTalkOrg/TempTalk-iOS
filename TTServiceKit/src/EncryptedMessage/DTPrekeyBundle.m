//
//  DTPrekeyBundle.m
//  TTServiceKit
//
//  Created by Kris.s on 2023/5/16.
//

#import "DTPrekeyBundle.h"
#import "DTParamsBaseUtils.h"
#import "NSData+keyVersionByte.h"

@implementation DTPrekeyBundle

+ (NSDictionary *)JSONKeyPathsByPropertyKey{
    return [NSDictionary mtl_identityPropertyMapWithModel:[self class]];;
}

- (NSData *)identityKeyData {
    if(!DTParamsUtils.validateString(self.identityKey)){
        return nil;
    }
    NSData *identityKeyData = [[NSData dataFromBase64StringNoPadding:self.identityKey] throws_removeKeyType];
    return identityKeyData;
}

@end
