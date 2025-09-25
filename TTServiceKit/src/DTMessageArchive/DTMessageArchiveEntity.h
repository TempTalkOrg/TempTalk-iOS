//
//  DTMessageArchiveEntity.h
//  TTServiceKit
//
//  Created by user on 2024/6/24.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTMessageArchiveEntity : MTLModel
@property (nonatomic, copy, nullable) NSString *concatNumbers;
@property (nonatomic, copy, nullable) NSString *gid;
@property (nonatomic, assign) uint64_t endTimestamp;
@end

NS_ASSUME_NONNULL_END
