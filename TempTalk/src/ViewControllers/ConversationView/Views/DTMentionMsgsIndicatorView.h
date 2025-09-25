//
//  DTMentionMsgsIndicatorView.h
//  Signal
//
//  Created by Kris.s on 2022/7/21.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTMentionMsgsIndicatorView : UIView

@property (nonatomic, copy) void (^tapBlock)(void);

@property (nonatomic, copy) NSString *badgeCount;


@end

NS_ASSUME_NONNULL_END
