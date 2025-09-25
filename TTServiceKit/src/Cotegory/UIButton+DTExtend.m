//
//  UIButton+DTSExtend.m
//  DTSClassRoom
//
//  Created by hornet on 2021/11/16.
//

#import "UIButton+DTExtend.h"
#import "UIImage+OWS.h"

@implementation UIButton (DTSExtend)
    
- (void)setBackgroundColor:(UIColor *)backgroundColor forState:(UIControlState)state {
    [self setBackgroundImage:[UIImage imageWithColor:backgroundColor] forState:state];
}
    
@end
