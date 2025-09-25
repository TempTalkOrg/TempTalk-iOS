//
//  UIAlertController+TapOutside.m
//  SignalX
//
//  Created by anonymous on 2021/4/2.
//  Copyright © 2021 anonymous. All rights reserved.
//

#import "UIAlertController+TapOutside.h"

@implementation UIAlertController (TapOutside)

- (void)listenTapOutside
{
    NSArray * arrayViews = [UIApplication sharedApplication].keyWindow.subviews;
    if (arrayViews.count>0) {
        UIView * backView = arrayViews.lastObject;
        backView.userInteractionEnabled = YES;
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(outsidetapped)];
        [backView addGestureRecognizer:tap];
    }
}

-(void)outsidetapped
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
