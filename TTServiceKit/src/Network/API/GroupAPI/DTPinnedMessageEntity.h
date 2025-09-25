//
//  DTPinnedMessageEntity.h
//  TTServiceKit
//
//  Created by Ethan on 2022/3/17.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@class DTCardMessageEntity;

@interface DTPinnedMessageEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *pinId;
@property (nonatomic, copy) NSString *groupId;
@property (nonatomic, copy) NSString *content;
@property (nonatomic, copy) NSString *creator;
@property (nonatomic, assign) uint64_t createTime;
@property (nonatomic, strong, nullable) DTCardMessageEntity *businessInfo;//refreshedCard

@end

NS_ASSUME_NONNULL_END
