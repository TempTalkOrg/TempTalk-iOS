//
//  ALView+PureLayoutExtension.h
//  Signal
//
//  Created by Jaymin on 2024/01/02.
//  Copyright © 2024 Difft. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <PureLayout/PureLayoutDefines.h>

PL__ASSUME_NONNULL_BEGIN

@interface ALView (PureLayoutExtension)

- (NSLayoutConstraint *)autoPinEdge:(ALEdge)edge
                             toEdge:(ALEdge)toEdge
                             ofView:(ALView *)otherView
                         withOffset:(CGFloat)offset
                           priority:(UILayoutPriority)priority;

@end

PL__ASSUME_NONNULL_END
