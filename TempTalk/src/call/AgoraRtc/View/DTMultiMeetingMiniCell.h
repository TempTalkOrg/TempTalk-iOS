//
//  DTMultiMeetingMiniCell.h
//  Signal
//
//  Created by Ethan on 2022/7/29.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DTMultiChatItemModel.h"

NS_ASSUME_NONNULL_BEGIN

@interface DTMultiMeetingMiniCell : UICollectionViewCell

@property (nonatomic, strong) DTMultiChatItemModel *itemModel;
- (void)setDisplayBackground:(BOOL)needBackground
               displayCorner:(BOOL)displayCorner;

+ (NSString *)reuseIdentifier;

@end

NS_ASSUME_NONNULL_END
