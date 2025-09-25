//
//  DTQuickActionCell.h
//  Wea
//
//  Created by hornet on 2022/5/27.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
typedef enum : NSUInteger {
    DTQuickActionTypeShare = 0,            // 不在会议中
    DTQuickActionTypeCall = 1,            // 不在会议中
    DTQuickActionTypeMessage = 2,            // 不在会议中
} DTQuickActionType;

@class DTQuickActionCell;
@class DTLayoutButton;

@protocol DTQuickActionCellDelegate <NSObject>
- (void)quickActionCell:(DTQuickActionCell *)cell button:(DTLayoutButton *)sender actionType:(DTQuickActionType) type;
@end

@interface DTQuickActionCell : UITableViewCell
@property (nonatomic, weak) id <DTQuickActionCellDelegate> cellDelegate;
@property (nonatomic, assign) BOOL haveCall;
@property (nonatomic, assign) BOOL isFriend;

- (void)setupAllSubViews;
@end

NS_ASSUME_NONNULL_END
