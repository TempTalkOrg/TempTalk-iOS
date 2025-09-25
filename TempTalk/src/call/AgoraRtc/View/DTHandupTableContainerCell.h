//
//  DTExpandControlCell.h
//  TempTalk
//
//  Created by Henry on 2025/7/4.
//  Copyright © 2025 Difft. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTHandupTableContainerCell : UICollectionViewCell

- (void)configureWithHandupList:(NSArray<NSString *> *)handups
                    isExpanded:(BOOL)isExpanded
                     maxCount:(NSInteger)maxCount
                    onToggle:(void(^)(BOOL expanded))onToggle;

+ (NSString *)reuseIdentifier;

@end

NS_ASSUME_NONNULL_END
