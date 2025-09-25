//
//  DTConversationInfoEntity.h
//  TTServiceKit
//
//  Created by hornet on 2022/8/9.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTConversationInfoEntity : MTLModel
@property (nonatomic, copy, nullable) NSString *number;
@property (nonatomic, strong, nullable) NSData *groupId;
@end

NS_ASSUME_NONNULL_END
