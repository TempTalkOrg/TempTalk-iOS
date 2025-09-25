//
//  DTPersonalStatusHeader.h
//  Wea
//
//  Created by user on 2022/9/2.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DTPersonalStatusHeaderDelegate <NSObject>

- (void)clearCurrentSetting;

@end

@interface DTPersonalStatusHeader : UIView
@property (nonatomic, weak) id<DTPersonalStatusHeaderDelegate> delegate;
- (void)updateInfo:(NSString *_Nullable)title;

@end

NS_ASSUME_NONNULL_END
