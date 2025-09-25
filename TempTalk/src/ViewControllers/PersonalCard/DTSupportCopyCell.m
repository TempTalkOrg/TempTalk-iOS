//
//  DTSupportCopyCell.m
//  Wea
//
//  Created by hornet on 2022/6/1.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTSupportCopyCell.h"

@implementation DTSupportCopyCell



- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
//    if (action == @selector(copyEmail)) {
//        return YES;
//    }
    return NO; //隐藏系统默认的菜单项
}

@end
