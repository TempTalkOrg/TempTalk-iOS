//
//  DTStepTextFiled.m
//  Signal
//
//  Created by hornet on 2022/10/4.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTStepTextFiled.h"
#import <TTMessaging/Theme.h>
#import <TTMessaging/UIColor+OWS.h>
#import <TTServiceKit/DTParamsBaseUtils.h>
#import <TTServiceKit/CALayer+DTFrame.h>
//#import "DTStepTextFiled.h"

#define kFlickerAnimation @"kFlickerAnimation"

@implementation DTStepTextFieldConfig

- (instancetype)init{
    if (self = [super init]) {
        _inputBoxBorderWidth = 1.0/[UIScreen mainScreen].scale;
        _inputBoxSpacing = 5;
        _inputBoxColor = [UIColor lightGrayColor];
        _tintColor = [UIColor blueColor];
        _font = [UIFont boldSystemFontOfSize:16];
        _textColor = [UIColor blackColor];
        _showFlickerAnimation = YES;
        _underLineColor = [UIColor lightGrayColor];
        _autoShowKeyboardDelay = 0.5;
    }
    return self;
}

@end

@interface DTStepTextFiled()
@property (strong,  nonatomic) DTStepTextFieldConfig *config;
@property (strong,  nonatomic) UITextField *textView;
@property (nonatomic,  assign) BOOL inputFinish;
@property (nonatomic,  assign) NSUInteger inputFinishIndex;
@property (nonatomic,  assign) BOOL isResetContentText;

@end

@implementation DTStepTextFiled

- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithFrame:(CGRect)frame config:(DTStepTextFieldConfig *)config{
    if (self = [super initWithFrame:frame]) {
        _config = config;
        [self jhSetupViews:frame];
    }
    return self;
}

- (void)jhSetupViews:(CGRect)frame
{
    if (frame.size.width <= 0 ||
        frame.size.height <= 0 ||
        _config.inputBoxNumber == 0 ||
        _config.inputBoxWidth > frame.size.width) {
        return;
    }
    
    //优先考虑 inputBoxWidth
    CGFloat inputBoxSpacing = _config.inputBoxSpacing;
    
    CGFloat inputBoxWidth = 0;
    if (_config.inputBoxWidth > 0) {
        inputBoxWidth = _config.inputBoxWidth;
    }
    
    CGFloat leftMargin = 0;
    if (inputBoxWidth > 0) {
        _config.leftMargin = (CGRectGetWidth(frame)-inputBoxWidth*_config.inputBoxNumber-inputBoxSpacing*(_config.inputBoxNumber-1))*0.5;
        leftMargin = _config.leftMargin;
    }else{
        _config.inputBoxWidth = (CGRectGetWidth(frame)-inputBoxSpacing*(_config.inputBoxNumber-1)-_config.leftMargin*2)/_config.inputBoxNumber;
        inputBoxWidth = _config.inputBoxWidth;
    }
    
    if (_config.leftMargin < 0) {
        _config.leftMargin = 0;
        _config.inputBoxWidth = (CGRectGetWidth(frame)-inputBoxSpacing*(_config.inputBoxNumber-1)-_config.leftMargin*2)/_config.inputBoxNumber;
        
        leftMargin = _config.leftMargin;
        inputBoxWidth = _config.inputBoxWidth;
    }
    
    CGFloat inputBoxHeight = 0;
    if (_config.inputBoxHeight > CGRectGetHeight(frame)) {
        _config.inputBoxHeight = CGRectGetHeight(frame);
    }
    inputBoxHeight = _config.inputBoxHeight;
    
    if (_config.showUnderLine) {
        if (_config.underLineSize.width <= 0) {
            CGSize size = _config.underLineSize;
            size.width = inputBoxWidth;
            _config.underLineSize = size;
        }
        if (_config.underLineSize.height <= 0) {
            CGSize size = _config.underLineSize;
            size.height = 1;
            _config.underLineSize = size;
        }
    }
    
    for (NSUInteger i = 0; i < _config.inputBoxNumber; ++i) {
        UITextField *textField = [[UITextField alloc] init];
        textField.frame = CGRectMake(_config.leftMargin+(inputBoxWidth+inputBoxSpacing)*i, (CGRectGetHeight(frame)-inputBoxHeight)*0.5, inputBoxWidth, inputBoxHeight);
        textField.textAlignment = 1;
        if (_config.inputBoxBorderWidth > 0) {
            textField.layer.borderWidth = _config.inputBoxBorderWidth;
        }
        if (_config.inputBoxCornerRadius > 0) {
            textField.layer.cornerRadius = _config.inputBoxCornerRadius;
        }
        if (_config.inputBoxColor) {
            textField.layer.borderColor = _config.inputBoxColor.CGColor;
        }
        if (_config.tintColor) {
            if (inputBoxWidth > 2 && inputBoxHeight > 8) {
                CGFloat w = 2, y = 10, x = (inputBoxWidth-w)/2, h = inputBoxHeight-2*y;
                [textField.layer addSublayer:({
                    UIBezierPath *path = [UIBezierPath bezierPathWithRect:CGRectMake(x,y,w,h)];
                    CAShapeLayer *layer = [CAShapeLayer layer];
                    layer.path = path.CGPath;
                    layer.fillColor = _config.tintColor.CGColor;
                    [layer addAnimation:[self xx_alphaAnimation] forKey:kFlickerAnimation];
                    if (i != 0) {
                        layer.hidden = YES;
                    }
                    layer;
                })];
            }
        }
        if (_config.secureTextEntry) {
            textField.secureTextEntry = _config.secureTextEntry;
        }
        if (_config.font){
            textField.font = _config.font;
        }
        if (_config.textColor) {
            textField.textColor = _config.textColor;
        }
        if (_config.showUnderLine) {
            CGFloat x = (inputBoxWidth-_config.underLineSize.width)/2.0;
            CGFloat y = (inputBoxHeight-_config.underLineSize.height);
            CGRect tframe = CGRectMake(x, y, _config.underLineSize.width, _config.underLineSize.height);
            
            UIView *underLine = [[UIView alloc] init];
            underLine.tag = 100;
            underLine.frame = tframe;
            underLine.backgroundColor = _config.underLineColor;
            [textField addSubview:underLine];
            
        }
        
        textField.tag = (NSInteger)i;
        textField.userInteractionEnabled = false;
        [self addSubview:textField];
    }
    
    [self addGestureRecognizer:({
        [[UITapGestureRecognizer alloc]initWithTarget:self action:@selector(xx_tap)];
    })];
    
    _textView = [[UITextField alloc] init];
    _textView.frame = CGRectMake(0, CGRectGetHeight(frame), 0, 0);
    _textView.secureTextEntry = _config.useSystemPasswordKeyboard;
    _textView.keyboardType = _config.keyboardType;
    _textView.hidden = YES;
    if (@available(iOS 12.0, *)) {
        _textView.textContentType = UITextContentTypeOneTimeCode;
    }
    [self addSubview:_textView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(xx_textChange:) name:UITextFieldTextDidChangeNotification object:_textView];
    //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(xx_didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    if (_config.autoShowKeyboard) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_config.autoShowKeyboardDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self->_textView becomeFirstResponder];
        });
    }
}

- (CABasicAnimation *)xx_alphaAnimation{
    CABasicAnimation *alpha = [CABasicAnimation animationWithKeyPath:@"opacity"];
    alpha.fromValue = @(1.0);
    alpha.toValue = @(0.0);
    alpha.duration = 1.0;
    alpha.repeatCount = (float) CGFLOAT_MAX;
    alpha.removedOnCompletion = NO;
    alpha.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    return alpha;
}

- (void)xx_tap{
    [_textView becomeFirstResponder];
}

- (void)xx_didBecomeActive{
    // restart Flicker Animation
    if (_config.showFlickerAnimation && _textView.text.length < self.subviews.count) {
        UITextField *textField = self.subviews[_textView.text.length];
        CALayer *layer = textField.layer.sublayers[0];
        [layer removeAnimationForKey:kFlickerAnimation];
        [layer addAnimation:[self xx_alphaAnimation] forKey:kFlickerAnimation];
    }
}



- (void)xx_textChange:(NSNotification *)noti
{
    if (_textView != noti.object) {
        return;
    }
    NSString *text = [_textView.text stringByReplacingOccurrencesOfString:@" " withString:@""];
    [self resetContentWIthString:text];
}

- (void)xx_setDefault
{
    for (NSUInteger i = 0; i < _config.inputBoxNumber; ++i) {
        UITextField *textField = self.subviews[i];
        textField.text = @"";
        
        if (_config.inputBoxColor) {
            textField.layer.borderColor = _config.inputBoxColor.CGColor;
        }
        if (_config.showFlickerAnimation) {
            CALayer *layer = textField.layer.sublayers[0];
            layer.hidden = YES;
            [layer removeAnimationForKey:kFlickerAnimation];
        }
        if (_config.showUnderLine) {
            UIView *underLine = [textField viewWithTag:100];
            underLine.backgroundColor = _config.underLineColor;
        }
    }
}

- (void)xx_flickerAnimation:(NSString *)text
{
    if (_config.showFlickerAnimation && text.length < self.subviews.count) {
        UITextField *textField = self.subviews[text.length];
        CALayer *layer = textField.layer.sublayers[0];
        layer.hidden = NO;
        [layer addAnimation:[self xx_alphaAnimation] forKey:kFlickerAnimation];
    }
}

- (void)xx_setValue:(NSString *)text
{
    _inputFinish = (text.length == _config.inputBoxNumber);
    
    //修改光标位置
    if (_config.tintColor && text.length < _config.inputBoxNumber) {
        [self clearFieldLayers];
        UITextField *nextTextField = self.subviews[text.length];
        if (_config.inputBoxWidth > 2 && _config.inputBoxHeight > 8) {
            CGFloat w = 2, y = 10, x = (_config.inputBoxWidth-w)/2, h = _config.inputBoxHeight-2*y;
            [nextTextField.layer addSublayer:({
                UIBezierPath *path = [UIBezierPath bezierPathWithRect:CGRectMake(x,y,w,h)];
                CAShapeLayer *layer = [CAShapeLayer layer];
                layer.path = path.CGPath;
                layer.fillColor = _config.tintColor.CGColor;
                [layer addAnimation:[self xx_alphaAnimation] forKey:kFlickerAnimation];
                layer;
            })];
        }
    } else {
        [self clearFieldLayers];
    }
    
    for (NSUInteger i = 0; i < text.length; ++i) {
        unichar c = [text characterAtIndex:i];
        UITextField *textField = self.subviews[i];
        textField.text = [NSString stringWithFormat:@"%c",c];
        if (!textField.secureTextEntry && _config.customInputHolder.length > 0) {
            textField.text = _config.customInputHolder;
        }
        
        // Input Status
        UIFont *font = _config.font;
        UIColor *color = _config.textColor;
        UIColor *inputBoxColor = _config.inputBoxHighlightedColor;
        UIColor *underLineColor = _config.underLineHighlightedColor;
        
        // Finish Status
        if (_inputFinish) {
            if (_inputFinishIndex < _config.finishFonts.count) {
                font = _config.finishFonts[_inputFinishIndex];
            }
            if (_inputFinishIndex <  _config.finishTextColors.count) {
                color = _config.finishTextColors[_inputFinishIndex];
            }
            if (_inputFinishIndex < _config.inputBoxFinishColors.count) {
                inputBoxColor = _config.inputBoxFinishColors[_inputFinishIndex];
            }
            if (_inputFinishIndex < _config.underLineFinishColors.count) {
                underLineColor = _config.underLineFinishColors[_inputFinishIndex];
            }
        }
        
        textField.font = font;
        textField.textColor = color;
        
        if (inputBoxColor) {
            textField.layer.borderColor = inputBoxColor.CGColor;
        }
        if (_config.showUnderLine && underLineColor) {
            UIView *underLine = [textField viewWithTag:100];
            underLine.backgroundColor = underLineColor;
        }
    }
}

- (void)clearFieldLayers {
    for (int i = 0; i < _config.inputBoxNumber; i++) {
        UITextField *field = self.subviews[i];
        [field.layer removeAllSublayers];
    }
}

- (void)setContentTextValue:(NSString *)content {
    
    [self resetContentWIthString:content];
}

- (void)resetContentWIthString:(NSString *) content {
    [self xx_setDefault];
    // trim space
    NSString *text = [content stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    // number & alphabet
    NSMutableString *mstr = @"".mutableCopy;
    for (NSUInteger i = 0; i < text.length; ++i) {
        unichar c = [text characterAtIndex:i];
        if (_config.inputType == DTStepTextFieldConfigInputType_Number_Alphabet) {
            if ((c >= '0' && c <= '9') ||
                (c >= 'A' && c <= 'Z') ||
                (c >= 'a' && c <= 'z')) {
                [mstr appendFormat:@"%c",c];
            }
        }else if (_config.inputType == DTStepTextFieldConfigInputType_Number) {
            if ((c >= '0' && c <= '9')) {
                [mstr appendFormat:@"%c",c];
            }
        }else if (_config.inputType == DTStepTextFieldConfigInputType_Alphabet) {
            if ((c >= 'A' && c <= 'Z') ||
                (c >= 'a' && c <= 'z')) {
                [mstr appendFormat:@"%c",c];
            }
        }
    }
    
    text = mstr;
    NSUInteger count = _config.inputBoxNumber;
    if (text.length > count) {
        text = [text substringToIndex:count];
    }
    _textView.text = text;
    if (_inputBlock) {
        _inputBlock(text);
    }
    
    // set value
    [self xx_setValue:text];
    
    // Flicker Animation
    [self xx_flickerAnimation:text];
    
    if (_inputFinish) {
        [self xx_finish];
    }
}

- (void)xx_finish
{
    if (_finishBlock) {
        _finishBlock(self, _textView.text);
    }
    
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        [self endEditing:YES];
//    });
}

#pragma mark - public

- (void)clear
{
    _textView.text = @"";
    
    [self xx_setDefault];
    [self xx_flickerAnimation:_textView.text];
}

- (void)showInputFinishColorWithIndex:(NSUInteger)index
{
    _inputFinishIndex = index;
    
    [self xx_setValue:_textView.text];
}

@end
