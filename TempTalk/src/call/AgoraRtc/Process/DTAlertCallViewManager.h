//
//  DTAlertCallViewController.h
//  Signal
//
//  Created by Felix on 2021/9/3.
//

#import "OWSViewController.h"
#import "DTAlertCallView.h"

@class DTCallModel;
@class DTAlertCallModel;
@class DTLiveKitCallModel;

NS_ASSUME_NONNULL_BEGIN

@interface DTAlertCallViewManager : NSObject

@property (nonatomic, readonly) NSMutableDictionary <NSString *, DTAlertCallModel *> *alertCallModels;

+ (instancetype _Nonnull)sharedManager;

- (void)addAlert:(DTCallModel *)callModel
       alertType:(DTAlertCallType)alertType;
//- (void)replaceAlertCall:(DTCallModel *)callModel fromView:(UIView *)sourceView;
- (void)bringAlertCallsToView:(UIView *)toView;
- (void)removeAlertCallByChannelName:(NSString *)channelName;
- (void)removeAllAlertCalls;

- (BOOL)hasAlertCall;
- (BOOL)hasAlert:(NSString *)channelName;

@end

@interface DTAlertCallModel : NSObject

@property (nonatomic, strong, nullable) DTCallModel *callModel;
@property (nonatomic, strong, nullable) DTLiveKitCallModel *liveKitCall;
@property (nonatomic, strong) DTAlertCallView *alertCallView;
@property (nonatomic, strong) NSTimer *callTimer;

/// critical alert sync read
@property (nonatomic, assign) BOOL hasRead;

@end

NS_ASSUME_NONNULL_END
