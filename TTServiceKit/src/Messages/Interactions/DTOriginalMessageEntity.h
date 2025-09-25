//
//  DTOriginalMessageEntity.h
//  TTServiceKit
//
//  Created by Kris.s on 2022/1/13.
//

#import <Mantle/Mantle.h>
#import "DTRealSourceEntity.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTOriginalMessageEntity : MTLModel

@property (nonatomic, strong) DTRealSourceEntity *realSource;
@property (nonatomic, copy) NSString *conversationId;

- (instancetype)initSourceWithRealSource:(DTRealSourceEntity *)realSource
                          conversationId:(NSString *)conversationId;

//+ (DTOriginalMessageEntity *)originalMessageWithProto:(DSKProtoDataMessageOriginalMessage *)originalMessageProto;
//+ (DSKProtoDataMessageOriginalMessage *)protoWithOriginalMessageEntity:(DTOriginalMessageEntity *)originalMessageEntity;

@end

NS_ASSUME_NONNULL_END
