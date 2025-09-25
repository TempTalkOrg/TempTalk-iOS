//
//  DTAlertCallView.h
//  Signal
//
//  Created by Felix on 2021/9/3.
//

#import <UIKit/UIKit.h>

@class DTCallModel;
@class DTAlertCallView;
@class AvatarImageView;
@class DTLiveKitCallModel;

typedef NS_ENUM(NSInteger, DTAlertCallType) {
    DTAlertCallTypeCall = 0, // 通话中收到calling
    DTAlertCallTypeSchedule, // 预约会议开始
    DTAlertCallTypeEvent,    // 非会议事件
    DTAlertCallTypeCritical  // critical alert
};

NS_ASSUME_NONNULL_BEGIN

@protocol DTAlertCallViewDelegate <NSObject>

@optional
- (void)alertCallView:(DTAlertCallView *)alertCall
leftButtonClickWithCallModel:(DTCallModel *)callModel
            alertType:(DTAlertCallType)alertType;
@optional
- (void)alertCallView:(DTAlertCallView *)alertCall
rightButtonClickWithCallModel:(DTCallModel *)callModel
            alertType:(DTAlertCallType)alertType;
@optional
- (void)alertCallView:(DTAlertCallView *)alertCall
topSwipActionWithCallModel:(DTCallModel *)callModel
            alertType:(DTAlertCallType)alertType;

@optional
- (void)leftButtonAction:(DTLiveKitCallModel *)liveKitCall;
@optional
- (void)rightButtonAction:(DTLiveKitCallModel *)liveKitCall;
@optional
- (void)swipeAction:(DTLiveKitCallModel *)liveKitCall;

@end

@interface DTAlertCallView : UIView

@property (nonatomic, weak) id<DTAlertCallViewDelegate> delegate;
@property (nonatomic, assign, readonly) DTAlertCallType alertType;

@property (nonatomic, readonly) UILabel *titleLabel;
@property (nonatomic, readonly) UILabel *subTitleLabel;
@property (nonatomic, readonly) AvatarImageView *avatarView;
@property (nonatomic, readonly) UIButton *leftButton;
@property (nonatomic, readonly) UIButton *rightButton;

- (void)configAlertCall:(DTCallModel *)callModel
              alertType:(DTAlertCallType)alertType;

@end

NS_ASSUME_NONNULL_END
