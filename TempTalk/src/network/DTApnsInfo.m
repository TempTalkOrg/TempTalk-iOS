//
//  DTApnsInfo.m
//  Signal
//
//  Created by Kris.s on 2021/8/28.
//

#import "DTApnsInfo.h"

@implementation DTApnsInfo

+ (NSDictionary *)JSONKeyPathsByPropertyKey
{
    return @{
        @"passthroughInfo":@"aps.passthrough",
        @"interruptionLevel" : @"aps.interruption-level",
        @"msg" : @"aps.msg"
    };
}

+ (NSValueTransformer *)passthroughInfoJSONTransformer {
    return [MTLValueTransformer transformerUsingForwardBlock:^id(NSString *passthroughString, BOOL *success, NSError *__autoreleasing *error) {
        NSData *jsonData = [passthroughString dataUsingEncoding:NSUTF8StringEncoding];
        if(jsonData){
            NSDictionary *passthroughInfo = [NSJSONSerialization JSONObjectWithData:jsonData
                                                                 options:NSJSONReadingMutableContainers
                                                                   error:nil];
            return passthroughInfo;
        }
        return nil;
    } reverseBlock:^id(NSDictionary *passthroughInfo, BOOL *success, NSError *__autoreleasing *error) {
        if(passthroughInfo.count){
            NSError *jsonError;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:passthroughInfo.copy options:NSJSONWritingPrettyPrinted error:&jsonError];
            NSString *jsonString;
            if(jsonData.length && !jsonError){
                jsonString = [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
            }
            return jsonString;
        }else{
            return nil;
        }
    }];
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionaryValue error:(NSError **)error {
    self = [super initWithDictionary:dictionaryValue error:error];
    if (self == nil) return nil;

    if([self.passthroughInfo isKindOfClass:[NSDictionary class]]){
        NSString *conversationId = self.passthroughInfo[@"conversationId"];
        if([conversationId isKindOfClass:[NSString class]]){
            self.conversationId = conversationId;
        }
    }

    return self;
}


@end
