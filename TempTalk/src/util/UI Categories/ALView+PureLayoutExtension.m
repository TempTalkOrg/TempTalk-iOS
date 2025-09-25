//
//  ALView+PureLayoutExtension.m
//  Signal
//
//  Created by Jaymin on 2024/01/02.
//  Copyright © 2024 Difft. All rights reserved.
//

#import <PureLayout/PureLayout.h>
#import "ALView+PureLayoutExtension.h"


@implementation ALView (PureLayoutExtension)

- (NSLayoutConstraint *)autoPinEdge:(ALEdge)edge
                             toEdge:(ALEdge)toEdge
                             ofView:(ALView *)otherView
                         withOffset:(CGFloat)offset
                           priority:(UILayoutPriority)priority
{
    NSLayoutConstraint *constraint = [self autoPinEdge:edge toEdge:toEdge ofView:otherView withOffset:offset];
    constraint.priority = priority;
    return constraint;
}

@end
