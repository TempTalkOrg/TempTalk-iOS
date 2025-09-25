//
//  DTAlertCallViewController.m
//  Signal
//
//  Created by Felix on 2021/9/3.
//

#import "DTAlertCallViewManager.h"
#import "DTCallModel.h"
#import <TTMessaging/UIView+SignalUI.h>
#import <TTMessaging/UIColor+OWS.h>
#import <TTMessaging/OWSWindowManager.h>
#import <TTServiceKit/DTCallManager.h>
#import <TTServiceKit/TSGroupThread.h>
#import <TTServiceKit/DTVirtualThread.h>
#import <TTServiceKit/TTServiceKit-Swift.h>
#import <TTServiceKit/Localize_Swift.h>
#import "TempTalk-Swift.h"

@interface DTAlertCallViewManager () <DTAlertCallViewDelegate>

@property (nonatomic, strong) NSMutableDictionary <NSString *, DTAlertCallModel *> *alertCallModels;

@property (nonatomic, strong, nullable) OWSAudioPlayer *audioPlayer;

@end

@implementation DTAlertCallViewManager

- (void)dealloc
{
    OWSLogInfo(@"%s DTAlertCallViewController", __FUNCTION__);
}

+ (instancetype _Nonnull)sharedManager {
    static DTAlertCallViewManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[DTAlertCallViewManager alloc] init];
    });
    return manager;
}

#pragma mark - public

- (void)addAlert:(DTCallModel *)callModel
       alertType:(DTAlertCallType)alertType {
    
    if ([self.alertCallModels.allKeys containsObject:callModel.channelName]) {
        return;
    }
    
    OWSLogInfo(@"%@ call alert get thread form channelName: %@", self.logTag, callModel.channelName);
    
    UIWindow *window = [[OWSWindowManager sharedManager] getToastSuitableWindow];

    dispatch_async(dispatch_get_main_queue(), ^{
        DTAlertCallView *alertCallView = [DTAlertCallView new];
        alertCallView.delegate = self;
        [alertCallView configAlertCall:callModel alertType:alertType];
        [window addSubview:alertCallView];
        [alertCallView autoHCenterInSuperview];
        [alertCallView autoPinTopToSuperviewMargin];
        [alertCallView autoSetDimension:ALDimensionHeight toSize:131];
        [alertCallView autoSetDimension:ALDimensionWidth toSize:MIN(kScreenWidth, kScreenHeight)-16];
        NSTimeInterval timeInterval = 0;
        if (alertType == DTAlertCallTypeSchedule || alertType == DTAlertCallTypeCritical) {
            timeInterval = callModel.lasting;
        } else {
            timeInterval = 60;
        }
        NSTimer *timer = [NSTimer weakScheduledTimerWithTimeInterval:timeInterval target:self selector:@selector(removeAlertCall:) userInfo:@{@"channelName": callModel.channelName} repeats:NO];
        DTAlertCallModel *alertCallModel = [DTAlertCallModel new];
        alertCallModel.callTimer = timer;
        alertCallModel.callModel = callModel;
        alertCallModel.alertCallView = alertCallView;
        
        self.alertCallModels[callModel.channelName] = alertCallModel;
        
        if (alertType == DTAlertCallTypeCritical) {
            if (self.audioPlayer) {
                return;
            }
            
            OWSAudioPlayer *player = [OWSSounds audioPlayerForSound:OWSSound_CriticalAlert];
            self.audioPlayer = player;
            player.isLooping = YES;
            [player playWithPlayAndRecordAudioCategory];
        }
    });
}

- (void)bringAlertCallsToView:(UIView *)toView {
    
    [self.alertCallModels.allValues enumerateObjectsUsingBlock:^(DTAlertCallModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        DTAlertCallView *alertCallView = obj.alertCallView;
        [alertCallView removeFromSuperview];
        [toView addSubview:alertCallView];
        [alertCallView autoHCenterInSuperview];
        [alertCallView autoPinTopToSuperviewMargin];
        [alertCallView autoSetDimension:ALDimensionHeight toSize:131];
        [alertCallView autoSetDimension:ALDimensionWidth toSize:MIN(kScreenWidth, kScreenHeight)-16]; 
    }];
}

//- (void)replaceAlertCall:(DTCallModel *)callModel fromView:(UIView *)sourceView {
//    __block NSString *shouldReplaceKey = nil;
//    [self.callModels enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, DTCallModel * _Nonnull obj, BOOL * _Nonnull stop) {
//        if ([obj.caller isEqualToString:callModel.caller]) {
//            
//            shouldReplaceKey = key;
//            *stop = YES;
//        }
//    }];
//    
//    [self addAlertCall:callModel alertType:DTAlertCallTypeCall toView:sourceView];
//    if (shouldReplaceKey) {
//        
//        [self removeAlertCallByChannelName:shouldReplaceKey];
//    }
//}

- (void)removeAlertCall:(NSTimer *)timer {
    NSDictionary *userInfo = timer.userInfo;
    if ([userInfo isKindOfClass:NSDictionary.class]) {
        NSString *channelName = userInfo[@"channelName"];
        [self removeAlertCallByChannelName:channelName];
    }
}

- (void)removeAlertCallByChannelName:(NSString *)channelName {
   
    if (!channelName || channelName.length == 0) {
        return;
    }
    if (![self.alertCallModels.allKeys containsObject:channelName]) {
        return;
    }
        
    DTAlertCallModel *alertCallModel = self.alertCallModels[channelName];

    dispatch_async(dispatch_get_main_queue(), ^{
        NSTimer *callTimer = alertCallModel.callTimer;
        [callTimer invalidate];
        callTimer = nil;
        DTAlertCallView *alertCallView = alertCallModel.alertCallView;
        if (alertCallView.superview) {
            [alertCallView removeFromSuperview];
        }
    });
    
    [self stopRing:alertCallModel];
    [self.alertCallModels removeObjectForKey:channelName];
    OWSLogInfo(@"%@ remove alert: %ld, %@", self.logTag, alertCallModel.alertCallView.alertType, channelName);
}

- (void)removeAllAlertCalls {
  
    [self.alertCallModels.allKeys enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self removeAlertCallByChannelName:obj];
    }];
}

- (BOOL)hasAlertCall {
    return self.alertCallModels.count > 0;
}

- (BOOL)hasAlert:(NSString *)channelName {
    
    NSArray <NSString *> *channelNames = self.alertCallModels.allKeys;

    if (!DTParamsUtils.validateString(channelName) ||!DTParamsUtils.validateArray(channelNames)) {
        return NO;
    }
    
    return [channelNames containsObject:channelName];
}

- (void)stopRing:(DTAlertCallModel *)alertModel {
    
    if (alertModel.alertCallView.alertType != DTAlertCallTypeCritical) {
        return;
    }
    
    if (!_audioPlayer) {
        return;
    }
        
    [self.audioPlayer stop];
    self.audioPlayer = nil;
}

#pragma mark - DTAlertCallViewDelegate

/*
- (void)alertCallView:(DTAlertCallView *)alertCall
leftButtonClickWithCallModel:(DTCallModel *)callModel
            alertType:(DTAlertCallType)alertType {
    if ((callModel.callType == DTCallType1v1) && alertType == DTAlertCallTypeCall) {
        [[DTMultiCallManager sharedManager] refuseCallWithChannelName:callModel.channelName response:@""];
    }
    
    [self removeAlertCallByChannelName:callModel.channelName];
}

- (void)alertCallView:(DTAlertCallView *)alertCall
rightButtonClickWithCallModel:(DTCallModel *)callModel
            alertType:(DTAlertCallType)alertType {
    if (alertType == DTAlertCallTypeCall || alertType == DTAlertCallTypeSchedule) {
        if ([DTMultiCallManager sharedManager].haveMeeting) {
            [[DTMultiCallManager sharedManager] showToast:Localized(@"CALL_INCOMING_ALERT_ONGOING_TIP", nil)];
        } else {
            DTVirtualThread * (^createVirtualThread)(NSString *, SDSAnyWriteTransaction *) = ^(NSString *_channelName, SDSAnyWriteTransaction *transaction) {
                DTVirtualThread *virtualThread = [DTVirtualThread getVirtualThreadWithId:_channelName transaction:transaction];
                if (!virtualThread) {
                    virtualThread = [[DTVirtualThread alloc] initWithUniqueId:_channelName];
                    [virtualThread anyInsertWithTransaction:transaction];
                }
                return virtualThread;
            };
            if (callModel.thread) {
                [[DTMultiCallManager sharedManager] showCallViewControllerWithCallModel:callModel 
                                                                             autoAccept:YES
                                                                            fromCallKit:NO
                                                                            shouldCheck:NO
                                                                           isLiveStream:callModel.isLiveStream
                                                                                    eid:callModel.eid
                                                                             completion:nil];
                [self removeAlertCallByChannelName:callModel.channelName];
                return;
            }
            DatabaseStorageAsyncWrite(self.databaseStorage, ^(SDSAnyWriteTransaction *transaction) {
                DTVirtualThread *virtualThread = createVirtualThread(callModel.channelName, transaction);
                callModel.thread = virtualThread;
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[DTMultiCallManager sharedManager] showCallViewControllerWithCallModel:callModel
                                                                                 autoAccept:YES
                                                                                fromCallKit:NO
                                                                                shouldCheck:NO
                                                                               isLiveStream:callModel.isLiveStream
                                                                                        eid:callModel.eid
                                                                                 completion:nil];
                    [self removeAlertCallByChannelName:callModel.channelName];
                });
            });
        }
    } else if (alertType == DTAlertCallTypeEvent) {
        UIWindow *topWindow = [OWSWindowManager.sharedManager getToastSuitableWindow];
        if (topWindow.windowLevel == UIWindowLevel_CallView()) {
            [[DTMultiCallManager sharedManager] showToast:@"Unable to view schedule details when you on a call"];
            return;
        }
        
        DTMeetingDetailController *detailVC = [DTMeetingDetailController new];
        detailVC.shouldUseTheme = YES;
        detailVC.popupsEvent = callModel.event;
        
        OWSNavigationController *detailNav = [[OWSNavigationController alloc] initWithRootViewController:detailVC];
        
        UIViewController *fromVC = [[UIApplication sharedApplication] frontmostViewController];
        [fromVC presentViewController:detailNav animated:YES completion:nil];
        
        [self removeAlertCallByChannelName:callModel.channelName];
    } else if (alertType == DTAlertCallTypeCritical) {
        UIWindow *topWindow = [OWSWindowManager.sharedManager getToastSuitableWindow];
        NSString *channelName = callModel.channelName;
        [self sendCriticalReadSyncMessageWithMessage:callModel.incomingMessage channelName:channelName];

        if (topWindow.windowLevel == UIWindowLevel_CallView()) {
            [[DTMultiCallManager sharedManager] showToast:@"Unable to push when you on a call"];
            DTAlertCallModel *alertModel = self.alertCallModels[channelName];
            [self stopRing:alertModel];
            return;
        }
                
        [self removeAlertCallByChannelName:callModel.channelName];
        [self criticalPushToConversationVC:callModel.thread];
    }
    
}

- (void)alertCallView:(DTAlertCallView *)alertCall
topSwipActionWithCallModel:(DTCallModel *)callModel
            alertType:(DTAlertCallType)alertType {
    if ((callModel.callType == DTCallType1v1) && alertType == DTAlertCallTypeCall) {
        [[DTMultiCallManager sharedManager] refuseCallWithChannelName:callModel.channelName response:@""];
    }
    
    [self removeAlertCallByChannelName:callModel.channelName];
}
*/

#pragma mark - data

- (NSMutableDictionary <NSString *, DTAlertCallModel *> *)alertCallModels {
    if (!_alertCallModels) {
        _alertCallModels = @{}.mutableCopy;
    }
    
    return _alertCallModels;
}

- (void)criticalPushToConversationVC:(TSThread *)thread {

    UIViewController *fromVC = [[UIApplication sharedApplication] frontmostViewController];
    UITabBarController *tabbarVC = fromVC.tabBarController;
    if (!tabbarVC) {
        OWSLogError(@"%@ wrong window: %.0f", self.logTag, fromVC.view.window.windowLevel);
        return;
    }
    
    UINavigationController *cNav = tabbarVC.viewControllers.firstObject;
    
    if (tabbarVC.selectedIndex != 0) {
        UINavigationController *selectedNav = (UINavigationController *)tabbarVC.selectedViewController;
        [selectedNav popToRootViewControllerAnimated:NO];
        tabbarVC.selectedIndex = 0;
    }

    id cvc = cNav.viewControllers.lastObject;
    if ([cvc isKindOfClass:ConversationViewController.class]) {
        ConversationViewController *conversationVC = (ConversationViewController *)cvc;
        TSThread *openedThread = conversationVC.thread;
        if ([openedThread.uniqueId isEqualToString:thread.uniqueId]) {
            OWSLogInfo(@"topvc is same conversationvc, no need to reopen");
            [conversationVC resetContentAndLayoutWithSneakyTransaction];
            return;
        }
    }
    
    DTHomeViewController *homeVC = (DTHomeViewController *)cNav.viewControllers.firstObject;
    if (thread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [homeVC.conversationVC presentThread:thread action:ConversationViewActionNone];
        });
    }
    
}

- (void)sendCriticalReadSyncMessageWithMessage:(TSIncomingMessage *)message
                                   channelName:(NSString *)channelName {
    
    DTAlertCallModel *alertModel = self.alertCallModels[channelName];
    
    if (alertModel.hasRead) {
        return;
    }
    alertModel.hasRead = YES;
    
    OWSLinkedDeviceReadReceipt *criticalReadReceipt = [[OWSLinkedDeviceReadReceipt alloc] initWithSenderId:message.authorId messageIdTimestamp:message.timestamp readTimestamp:0];
    OWSCriticalReadReceiptsMessage *readSyncMessage =
        [[OWSCriticalReadReceiptsMessage alloc] initWithReadReceipts:@[criticalReadReceipt]];

    OWSLogInfo(@"%@ will send linked critical read receipt", self.logTag);
    
    [self.messageSender enqueueMessage:readSyncMessage
        success:^{
        OWSLogInfo(@"%@ Successfully sent linked critical read receipt", self.logTag);
    }
                               failure:^(NSError *error) {
        OWSLogError(@"%@ Failed to send critical read receipt to linked devices with error: %@", self.logTag, error);
    }];

}

@end


@implementation DTAlertCallModel

@end
