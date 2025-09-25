//
//  DTTextField.m
//  TTMessaging
//
//  Created by hornet on 2021/12/2.
//

#import "DTTextField.h"

@implementation DTTextField
//控制文本所在的的位置，左右缩 10
- (CGRect)textRectForBounds:(CGRect)bounds {
//    return CGRectInset(bounds, 10, 0);
    return UIEdgeInsetsInsetRect(bounds,UIEdgeInsetsMake(0, 10, 0, 10));
}
 
//控制编辑文本时所在的位置，左右缩 10
- (CGRect)editingRectForBounds:(CGRect)bounds {
    return UIEdgeInsetsInsetRect(bounds,UIEdgeInsetsMake(0, 10, 0, 10));
}
@end
