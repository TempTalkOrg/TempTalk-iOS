//
//  DTPersonalCardToolView.h
//  Wea
//
//  Created by hornet on 2021/11/15.
//

#import <UIKit/UIKit.h>
// 通话类型
typedef NS_ENUM(NSInteger, DTToolViewBtnType) {
    DTToolViewBtnTypeMessage,// 消息
    DTToolViewBtnTypePhone,// 语音
    DTToolViewBtnTypeShare,// 分享
};

NS_ASSUME_NONNULL_BEGIN
@class DTPersonalCardToolView;

@protocol DTPersonalCardToolViewDelegate <NSObject>
-(void)personalCardTooltoolView:(DTPersonalCardToolView *)view senderClick:(UIButton *)sender btnType:(DTToolViewBtnType)type;
@end


@interface DTPersonalCardToolView : UIStackView
@property(nonatomic,weak) id <DTPersonalCardToolViewDelegate> toolViewDelegate;
@end

NS_ASSUME_NONNULL_END
