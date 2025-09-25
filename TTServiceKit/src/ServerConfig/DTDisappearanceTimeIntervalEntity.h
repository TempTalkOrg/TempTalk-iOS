//
//  DTDisappearanceTimeIntervalEntity.h
//  TTServiceKit
//
//  Created by Kris.s on 2021/8/18.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTDisappearanceTimeIntervalEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, strong) NSNumber *globalDefault;

/// message 消息归档
// default
@property (nonatomic, strong) NSNumber *messageDefault;
// note to self
@property (nonatomic, strong) NSNumber *messageMe;
// other thread
@property (nonatomic, strong) NSNumber *messageOthers;
// group
@property (nonatomic, strong) NSNumber *messageGroup;

/// conversation 会话归档
// default
@property (nonatomic, strong) NSNumber *conversationDefault;
// note to self
@property (nonatomic, strong) NSNumber *conversationMe;
// other thread
@property (nonatomic, strong) NSNumber *conversationOthers;
// group
@property (nonatomic, strong) NSNumber *conversationGroup;

@property (nonatomic, copy) NSArray *messageArchivingTimeOptionValues;
@end

NS_ASSUME_NONNULL_END
