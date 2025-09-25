//
//  DTWatermarkLayer.m
//  TTServiceKit
//
//  Created by hornet on 2021/11/24.
//

#import "DTWatermarkLayer.h"

//CGSize CGSizeCeilFrom(CGSize size);
@implementation DTWatermarkLayer

- (instancetype)initWithFrame:(CGRect)frame LayeString:(NSString *) message {
    self = [super init];
    if (self) {
        [self addWatermarkSubLayersWithSuperBounds:CGRectMake(0, 0, frame.size.width, frame.size.height) message:message];
        self.backgroundColor = [UIColor colorWithRed:255/255.0 green:0 blue:0 alpha:0.005].CGColor;
    }
    return self;
}

- (void)addWatermarkSubLayersWithSuperBounds:(CGRect)bounds message:(NSString *)string {
    int maxWidth = bounds.size.width;
    int maxHeight = bounds.size.height;
    int h_margin = 10;
    int v_margin = 10;
    CGSize watermarkTextSize = [self getSizeWithText:string font:[UIFont systemFontOfSize:13] maxWidth:maxWidth];
    int watermarkTextWidth = watermarkTextSize.width + h_margin;
    int watermarkTextHeight = watermarkTextSize.height + v_margin;
    
    int h_count = maxWidth/watermarkTextWidth +1;
    int v_count = maxHeight/watermarkTextHeight +1;
    
    @autoreleasepool {
        for (int i=0; i < v_count; i++) {
            for (int j=0; j < h_count; j++) {
                CATextLayer *textLayer = [CATextLayer layer];
                UIFont *font = [UIFont fontWithName:@"HelveticaNeue-Medium" size:13];
                CFStringRef fontName = (__bridge CFStringRef)font.fontName;
                CGFontRef fontRef = CGFontCreateWithFontName(fontName);
                textLayer.font = fontRef;
                textLayer.fontSize = font.pointSize;
                textLayer.foregroundColor = [UIColor colorWithRed:0 green:1.0 blue:0 alpha:0.005].CGColor;
                textLayer.alignmentMode = kCAAlignmentCenter;
                textLayer.backgroundColor = [UIColor clearColor].CGColor;
                textLayer.string = string;
                textLayer.frame = CGRectMake(j*watermarkTextWidth, i*watermarkTextHeight, watermarkTextWidth, watermarkTextHeight);
                textLayer.contentsScale = [UIScreen mainScreen].scale;
                textLayer.transform = CATransform3DMakeRotation(M_PI/18, 0, 0, 1);
                [self addSublayer:textLayer];
                CGFontRelease(fontRef);
            }
        }
    }
}

- (CGSize)getSizeWithText:(NSString *)string font:(UIFont *)font maxWidth:(int)maxWidth {
    CGRect labelRect = [string boundingRectWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX) options:(NSStringDrawingUsesLineFragmentOrigin) attributes:@{NSFontAttributeName: font} context:nil];
    return labelRect.size;
}

- (void)dealloc {
    
}

@end

//CGSize CGSizeCeilFrom(CGSize size) {
//    return CGSizeMake((CGFloat)ceil(size.width), (CGFloat)ceil(size.height));
//}
