//
//  DTCallKitManagerDelegate.h
//  TempTalk
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CallStatus) {
    CallStatusNone = 0,
    CallStatusBuildCallerFail,
    CallStatusBusy,
    CallStatusReadyStart,
    CallStatusAccept,
    CallStatusEnd,
};

typedef NS_ENUM(NSInteger, CKCallSystemState) {
    CKCallSystemStateNone = 0,
    CKCallSystemStateReported,
    CKCallSystemStateRemoved,
};

@protocol DTCallKitManagerDelegate <NSObject>
@optional
- (void)refreshCurrentCallStatus:(CallStatus)status uuidString:(nullable NSString *)uuidString;
- (void)refreshCurrentCallMuteState:(BOOL)isMute uuidString:(nullable NSString *)uuidString;
@end

NS_ASSUME_NONNULL_END
