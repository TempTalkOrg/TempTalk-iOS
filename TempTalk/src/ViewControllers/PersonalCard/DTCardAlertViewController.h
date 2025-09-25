//
//  DTCardAlertViewController.h
//  Wea
//
//  Created by hornet on 2022/5/31.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <TTMessaging/TTMessaging.h>

// 通话类型
typedef NS_ENUM(NSInteger, DTCardAlertViewType) {
    DTCardAlertViewTypeDefault,
    DTCardAlertViewTypeTextView,// 自己的名片可编辑
};

// 通话类型
typedef NS_ENUM(NSInteger, DTCardAlertActionType) {
    DTCardAlertActionTypeCancel,
    DTCardAlertActionTypeConfirm,// 自己的名片可编辑
};

@class DTCardAlertViewController;
@protocol DTCardAlertViewControllerDelegate <NSObject>
- (void)cardAlert:(DTCardAlertViewController * _Nullable)alert actionType:(DTCardAlertActionType)actionType changedText:(NSString * _Nullable)changedText defaultText:(NSString *_Nullable)defaultText;
@end

NS_ASSUME_NONNULL_BEGIN

@interface DTCardAlertViewController : OWSViewController
@property (nonatomic, weak) id <DTCardAlertViewControllerDelegate> alertDelegate;
@property (nonatomic, copy) NSAttributedString *attributedContentString;
@property (nonatomic, copy) NSString *contentString;
@property (nonatomic, copy) NSString *titleString;
@property (nonatomic, assign) NSUInteger maxLength;
@property (nonatomic, assign) int tag;
- (instancetype)init:(NSString *)recipientId type:(DTCardAlertViewType)alertType;
+ (NSMutableAttributedString *)commonContentAttributesString:(nonnull NSString *)string withFont:(int)fontSize;
@end

NS_ASSUME_NONNULL_END
