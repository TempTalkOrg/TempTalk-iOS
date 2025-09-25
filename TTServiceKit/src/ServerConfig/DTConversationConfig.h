//
//  DTConversationConfig.h
//  TTServiceKit
//
//  Created by hornet on 2022/7/6.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN
@interface DTConversationConfigEntity : MTLModel<MTLJSONSerializing>
@property (nonatomic, copy) NSString *blockRegex;
@end

@interface DTConversationConfig : NSObject
+ (nullable DTConversationConfigEntity * )fetchConversationConfig;
+ (BOOL)matchBlockRegexWithBotId:(NSString *)botid;
@end

NS_ASSUME_NONNULL_END
