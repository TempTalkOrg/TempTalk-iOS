//
//  DTPinPageDot.m
//  Wea
//
//  Created by Ethan on 2022/3/17.
//

#import "DTPinPageDot.h"
#import "UIColor+OWS.h"
#import <TTMessaging/Theme.h>

@interface DTPinPageDot ()

@property (weak, nonatomic) IBOutlet UIView *dot;

@end

@implementation DTPinPageDot

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
    UIView *backgroundView = [UIView new];
    backgroundView.backgroundColor = [UIColor clearColor];
    self.selectedBackgroundView = backgroundView;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    
    self.dot.backgroundColor = selected ? Theme.themeBlueColor : [UIColor ows_lightGray02Color];
}

@end
