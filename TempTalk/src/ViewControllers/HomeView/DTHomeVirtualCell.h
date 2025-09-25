//
//  DTHomeVirtualCell.h
//  Wea
//
//  Created by Felix on 2022/5/16.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HomeViewCell.h"

NS_ASSUME_NONNULL_BEGIN

@class DTVirtualThread;

@interface DTHomeVirtualCell : UITableViewCell

@property (nonatomic, weak) id<DTMeetingBarTapDelegate> meetingBarDelegate;
@property (nonatomic, readonly) DTVirtualThread *virtualThread;
@property (nonatomic, readonly) UILabel *callDurationLabel;

+ (NSString *)cellReuseIdentifier;

- (void)configWithThread:(DTVirtualThread *)virtualThread;

@end

NS_ASSUME_NONNULL_END
