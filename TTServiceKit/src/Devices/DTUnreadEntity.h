//
//  DTUnreadEntity.h
//  TTServiceKit
//
//  Created by hornet on 2022/7/4.
//

#import <Mantle/Mantle.h>
#import "DTConversationInfoEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTUnreadEntity : MTLModel
@property (nonatomic, strong, nullable) DTConversationInfoEntity *covnersation;
@property (nonatomic, assign) UInt32  unreadFlag;
@end

NS_ASSUME_NONNULL_END
