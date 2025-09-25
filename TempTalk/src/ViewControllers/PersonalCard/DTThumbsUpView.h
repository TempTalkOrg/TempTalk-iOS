//
//  DTThumbsUpView.h
//  Wea
//
//  Created by hornet on 2022/7/28.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <UIKit/UIKit.h>
@class DTThumbsUpView;

@protocol DTThumbsUpViewProtocol <NSObject>
- (void)thumbsUpView:(DTThumbsUpView *_Nullable)thumbsUpView thumpUpIconBtnClick:(UIButton *_Nullable)sender;
@end

NS_ASSUME_NONNULL_BEGIN

@interface DTThumbsUpView : UIView
@property (nonatomic, weak) id <DTThumbsUpViewProtocol> thumbsUpViewDelegate;
@property (nonatomic, strong) NSString *thumbsUpCount;
@end

NS_ASSUME_NONNULL_END
