//
//  DTMentionedMsgInfo.h
//  TTServiceKit
//
//  Created by Kris.s on 2022/11/7.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTMentionedMsgInfo : MTLModel

@property (nonatomic, assign, readonly) uint64_t timestampForSorting;

@property (nonatomic, copy, readonly) NSString *uniqueMessageId;

- (instancetype)initWithUniqueMessageId:(NSString *)uniqueMessageId
                    timestampForSorting:(uint64_t)timestampForSorting;

@end

NS_ASSUME_NONNULL_END
