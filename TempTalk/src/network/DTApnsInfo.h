//
//  DTApnsInfo.h
//  Signal
//
//  Created by Kris.s on 2021/8/28.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTApnsInfo : MTLModel<MTLJSONSerializing>

@property (nonatomic, copy) NSString *conversationId;

@property (nonatomic, strong) NSDictionary *passthroughInfo;

@property (nonatomic, strong) NSString *callerName;

//MARK: critical alert专用
@property (nonatomic, copy, nullable) NSString *interruptionLevel;
@property (nonatomic, copy, nullable) NSString *msg;

@end

NS_ASSUME_NONNULL_END
