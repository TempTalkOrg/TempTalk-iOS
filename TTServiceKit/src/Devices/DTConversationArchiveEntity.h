//
//  DTConversationArchiveEntity.h
//  TTServiceKit
//
//  Created by hornet on 2022/8/9.
//

#import <Mantle/Mantle.h>
#import "DTConversationInfoEntity.h"
NS_ASSUME_NONNULL_BEGIN

@interface DTConversationArchiveEntity : MTLModel
@property (nonatomic, strong, nullable) DTConversationInfoEntity *covnersation;
@property (nonatomic, assign) UInt32  flag;
@end

NS_ASSUME_NONNULL_END
