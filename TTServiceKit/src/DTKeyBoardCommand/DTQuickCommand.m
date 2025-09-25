//
//  DTQuickCommand.m
//  Signal
//
//  Created by hornet on 2022/8/22.
//  Copyright © 2022 Difft. All rights reserved.
//


#pragma mark - 注册PLugin

#import "DTQuickCommand.h"
#import "TSOutgoingMessage.h"
#import "DTMention.h"

extern void registerKeycommond(Class class,NSString *keycommond);

@interface DTQuickCommand ()
@end

@implementation DTQuickCommand
///子类重写该方法并完成注册
+ (void)load {
    registerKeycommond(self,[self configKeyCommand]);
}

- (instancetype)init {
    self = [super init];
    if (self) {
       self.keyCommand = [[self class] configKeyCommand];
    }
    return self;
}

+ (NSString * __nullable)configKeyCommand {
    return nil;
}

+ (BOOL)isVerifyCaseOfTheString {
    return false;
}

+ (BOOL)isNeedremovePrefixQuickCommand {
    return false;
}

-(void)removePrefixQuickCommandFromMessage:(TSOutgoingMessage *)message {
    //在这个位置处理消息的 相关逻辑 message的body 是只读属性，所以使用了KVC
    if ([self.class configKeyCommand].length && [self.class isNeedremovePrefixQuickCommand]) {
        
        NSUInteger origionLength = message.body.length;
        NSMutableString *bodyString = [message.body.ows_stripped mutableCopy];
        NSString *body = [bodyString substringFromIndex:[self.class configKeyCommand].length].ows_stripped;
        [message setValue:body forKey:@"body"];
        
        NSUInteger deleteLength = origionLength - body.length;
        NSMutableArray *tmpMentions = [message.mentions mutableCopy];
        [message.mentions enumerateObjectsUsingBlock:^(DTMention * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            obj.start -= (uint32_t)deleteLength;
        }];
        [message setValue:tmpMentions.copy forKey:@"mentions"];
    }
}

- (BOOL)hasPrefixKeyboardCommandWith:(NSString *)string {
    return false;
}

/// 子类在需要的时候重写
- (void)handleOutgoingMessage:(TSOutgoingMessage *)message associatedOrignalMessage:(TSMessage *)orignalMessage {
    
}

- (void)handleOutgoingMessage:(TSOutgoingMessage *)message {
    
}
- (void)handleIncomingMessage:(TSIncomingMessage *)message {
    
}

@end


////////////////////////////////////////////////////////////////////////////
// 注册 Keycommond 命令
////////////////////////////////////////////////////////////////////////////
static NSMutableDictionary *dtKeycommondDictionary;
NSMutableDictionary *DTGetQuickcommondDictionary(void);
NSMutableDictionary *DTGetQuickcommondDictionary(void) {
    return dtKeycommondDictionary;
}

void registerKeycommond(Class class, NSString *keycommond) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dtKeycommondDictionary = [NSMutableDictionary dictionary];
    });
    NSString *key = NSStringFromClass(class);
    if (![dtKeycommondDictionary.allKeys containsObject:key ] && keycommond != nil && keycommond.length) {
        [dtKeycommondDictionary setValue:keycommond forKey:key];
    }
}
