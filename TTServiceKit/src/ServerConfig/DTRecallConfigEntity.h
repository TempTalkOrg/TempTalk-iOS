//
//  DTRecallConfigEntity.h
//  TTServiceKit
//
//  Created by Kris.s on 2022/1/1.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTRecallConfigEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, assign) NSTimeInterval timeoutInterval;
@property (nonatomic, assign) NSTimeInterval editableInterval;

@end

NS_ASSUME_NONNULL_END
