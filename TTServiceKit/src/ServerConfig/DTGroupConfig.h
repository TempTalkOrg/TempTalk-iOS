//
//  DTGroupConfig.h
//  TTServiceKit
//
//  Created by Kris.s on 2022/3/30.
//

#import <Mantle/Mantle.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTGroupReminderConfig : MTLModel<MTLJSONSerializing>

@property (nonatomic, strong) NSArray <NSString *> *remindCycle;
@property (nonatomic, assign) NSInteger remindMonthDay;
@property (nonatomic, assign) NSInteger remindWeekDay;
@property (nonatomic, assign) NSInteger remindTime;
@property (nonatomic, copy) NSString *remindDescription;

@end


@interface DTGroupConfigEntity : MTLModel<MTLJSONSerializing>

@property (nonatomic, assign) NSUInteger chatTunnelSecurityThreshold;
@property (nonatomic, assign) NSUInteger meetingWithoutRingThreshold;
@property (nonatomic, assign) NSUInteger chatWithoutReceiptThreshold;
@property (nonatomic, strong) NSArray <NSNumber *>*messageArchivingTimeOptionValues;
@property (nonatomic, strong) DTGroupReminderConfig *groupRemind;
@property (nonatomic, assign) NSTimeInterval autoClear;

@property (nonatomic, assign) BOOL tempGroupCallCancelEnable;

@end

@interface DTGroupConfig : NSObject

+ (DTGroupConfigEntity *)fetchGroupConfig;

@end

NS_ASSUME_NONNULL_END
