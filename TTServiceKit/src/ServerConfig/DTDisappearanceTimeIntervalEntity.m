//
//  DTDisappearanceTimeIntervalEntity.m
//  TTServiceKit
//
//  Created by Kris.s on 2021/8/18.
//

#import "DTDisappearanceTimeIntervalEntity.h"

@implementation DTDisappearanceTimeIntervalEntity

+ (NSDictionary *)JSONKeyPathsByPropertyKey {
    return @{
        @"globalDefault"      : @"default",
        @"messageDefault"     : @"message.default",
        @"messageMe"          : @"message.me",
        @"messageOthers"      : @"message.other",
        @"messageGroup"       : @"message.group",
        @"conversationDefault": @"conversation.default",
        @"conversationMe"     : @"conversation.me",
        @"conversationOthers" : @"conversation.other",
        @"conversationGroup"  : @"conversation.group",
        @"messageArchivingTimeOptionValues"  : @"messageArchivingTimeOptionValues",
    };
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionaryValue error:(NSError *__autoreleasing *)error{
    if(self = [super initWithDictionary:dictionaryValue error:error]){
//        if([self.messageMe isEqualToNumber:@(0)]){
//            self.messageMe = @(INT32_MAX);
//        }
    }
    return self;
}

- (NSNumber *)messageOthers {
    if (!_messageOthers) {
        
        return _messageDefault;
    }
    
    return _messageOthers;
}

- (NSNumber *)messageGroup {
    if (!_messageGroup) {
        
        return _messageDefault;
    }
    
    return _messageGroup;
}

- (NSNumber *)conversationOthers {
    if (!_conversationOthers) {
        
        return _conversationDefault;
    }
    
    return _conversationOthers;
}

- (NSNumber *)conversationGroup {
    if (!_conversationGroup) {
        
        return _conversationDefault;
    }
    
    return _conversationGroup;
}

@end
