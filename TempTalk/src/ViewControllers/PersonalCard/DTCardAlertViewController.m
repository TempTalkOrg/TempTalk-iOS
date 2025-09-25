//
//  DTCardAlertViewController.m
//  Wea
//
//  Created by hornet on 2022/5/31.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTCardAlertViewController.h"
#import <TTServiceKit/TTServiceKit-swift.h>
#import <TTServiceKit/DTToastHelper.h>
#import <TTServiceKit/OWSRequestFactory.h>
#import <TTServiceKit/SignalAccount.h>
#import <TTServiceKit/UIButton+DTExtend.h>

@interface DTCardAlertViewController ()<UITextViewDelegate>
@property (nonatomic, strong) UIView *maskView;
@property (nonatomic, strong) UIView *contentView;
@property (nonatomic, strong) UIView *showContentView;//父contentView
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UITextView *contentTextView;
@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, assign) DTCardAlertViewType alertType;
@property (nonatomic, strong) UITextView *sectionTextView;
@property (nonatomic, strong) UITextView *inputTextView;//不做展示
@property (nonatomic, strong) UILabel *tipLabel;
@property (nonatomic, strong) NSString *recipientId;
@end

@implementation DTCardAlertViewController

- (instancetype)init:(NSString *)recipientId type:(DTCardAlertViewType)alertType;{
    self = [super init];
    if (self) {
        self.recipientId = recipientId;
        self.alertType = alertType;
        self.view.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupContent];
    [self setThemeColor];
    
}

- (void)applyTheme {
    [super applyTheme];
    [self.view removeAllSubviews];
    [self setupContent];
    if (self.alertType == DTCardAlertViewTypeTextView) {
        [self setThemeColor];
    } else {
        
    }
}

- (void)setThemeColor {
    self.showContentView.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x2B3139] : [UIColor colorWithRGBHex:0xFFFFFF];
    self.contentView.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x2B3139] : [UIColor colorWithRGBHex:0xFFFFFF];
    self.contentTextView.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x2B3139] : [UIColor colorWithRGBHex:0xFFFFFF];
    self.titleLabel.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x2B3139] : [UIColor colorWithRGBHex:0xFFFFFF];
    [self.confirmButton setBackgroundColor:Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x2B3139] : [UIColor colorWithRGBHex:0xFFFFFF]  forState:UIControlStateNormal];
    [self.confirmButton setBackgroundColor:Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x2B3139] : [UIColor colorWithRGBHex:0xFFFFFF]  forState:UIControlStateHighlighted];
}



- (void)setupContent {
    [self setupViews];
    [self setupLayouts];
    if (self.alertType == DTCardAlertViewTypeTextView) {
    } else {
        self.contentTextView.userInteractionEnabled = false;
    }
    _inputTextView.inputAccessoryView = [self alertInputAccessoryView];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hitViewClick:)];
    [self.view addGestureRecognizer:tap];
}

- (void)hitViewClick:(UITapGestureRecognizer *)tap {
    if (self.alertType == DTCardAlertViewTypeTextView) {
        [self.view endEditing:true];
        [self dismissViewControllerAnimated:true completion:nil];
    } else {
        [self dismisAnimation];
    }
}

- (void)setupViews {
    if (self.alertType == DTCardAlertViewTypeDefault) {
        [self.view addSubview:self.showContentView];
        [self.showContentView addSubview:self.contentView];
        [self.contentView addSubview:self.titleLabel];
        [self.contentView addSubview:self.contentTextView];
        [self.contentView addSubview:self.confirmButton];
    } else {
        [self.view addSubview:self.showContentView];
        [self.showContentView addSubview:self.inputTextView];
    }
}

- (void)setupLayouts {
//    [self.showContentView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.view];
    [self.showContentView autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.view];
    [self.showContentView autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.view];
    [self.showContentView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.view];
    if (self.alertType == DTCardAlertViewTypeDefault) {
        [self setupDefaultViewLayout];
    } else {
        [self setupTextViewLayout];
    }
}

- (void)setupTextViewLayout {
    self.inputTextView.frame = CGRectMake(0, 0, 0, 0);
}

- (void)setupDefaultViewLayout {
   
    [self.contentView autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:self.showContentView];
    [self.contentView autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.showContentView];
    [self.contentView autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.showContentView];
    [self.contentView autoPinBottomToSuperviewMargin];
    [self.contentView autoSetDimension:ALDimensionHeight toSize:244];
    
    [self.titleLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:self.showContentView];
    [self.titleLabel autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.showContentView];
    [self.titleLabel autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.showContentView];
    [self.titleLabel autoSetDimension:ALDimensionHeight toSize:48];
    
    UIView *lineView = [self lineView];
    [self.contentView addSubview:lineView];
    [lineView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.titleLabel];
    [lineView autoSetDimension:ALDimensionHeight toSize:1.0];
    [lineView autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.contentView];
    [lineView autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.contentView];
    
    [self.contentTextView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:lineView];
    [self.contentTextView autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.showContentView withOffset:24];
    [self.contentTextView autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.showContentView withOffset:-24];
    [self.contentTextView autoSetDimension:ALDimensionHeight toSize:148];
    
    UIView *lineView01 = [self lineView];
    [self.contentView addSubview:lineView01];
    [lineView01 autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:self.contentTextView];
    [lineView01 autoSetDimension:ALDimensionHeight toSize:1.0];
    [lineView01 autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.contentView];
    [lineView01 autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.contentView];
    
    [self.confirmButton autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:lineView01];
    [self.confirmButton autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.showContentView];
    [self.confirmButton autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.showContentView];
    [self.confirmButton autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:self.contentView];
    [self.confirmButton autoSetDimension:ALDimensionHeight toSize:48];
}

- (UIView *)alertInputAccessoryView {
    UIView * alertInputAccessoryView = [UIView new];
    if (@available(iOS 11.0, *)) {
        alertInputAccessoryView.layer.maskedCorners = (CACornerMask)(UIRectCornerTopLeft|UIRectCornerTopRight);
    } else {
        
    };
    alertInputAccessoryView.layer.cornerRadius = 8;
    alertInputAccessoryView.clipsToBounds = true;
    UIColor *lightColor = [UIColor colorWithRGBHex:0x1773EB];
    UIColor *darkColor = [UIColor colorWithRGBHex:0x4DA0FF];
    
    alertInputAccessoryView.frame = CGRectMake(0, 0, 0, 171);
    alertInputAccessoryView.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x2B3139] : [UIColor colorWithRGBHex:0xFFFFFF];
    UIButton *cancelButton = [UIButton new];
    [cancelButton setTitle:@"Cancel" forState:UIControlStateNormal];
    [cancelButton setTitleColor:Theme.isDarkThemeEnabled ? darkColor : lightColor  forState:UIControlStateNormal];
    [cancelButton addTarget:self action:@selector(cancelButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    UIButton *saveButton = [UIButton new];
    [saveButton setTitle:@"Save" forState:UIControlStateNormal];
   
    [saveButton setTitleColor:Theme.isDarkThemeEnabled ? darkColor : lightColor  forState:UIControlStateNormal];
    [saveButton addTarget:self action:@selector(saveButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    
    [alertInputAccessoryView addSubview:cancelButton];
    [alertInputAccessoryView addSubview:saveButton];
    
    [cancelButton autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:alertInputAccessoryView withOffset:16];
    [cancelButton autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:alertInputAccessoryView withOffset:16];
    [cancelButton autoSetDimension:ALDimensionHeight toSize:20];
    
    [saveButton autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:alertInputAccessoryView withOffset:16];
    [saveButton autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:alertInputAccessoryView withOffset:-16];
    [saveButton autoSetDimension:ALDimensionHeight toSize:20];
    
    UITextView *sectionTextView = [[UITextView alloc] init];
    self.sectionTextView = sectionTextView;
    sectionTextView.font = [UIFont systemFontOfSize:14];
    [alertInputAccessoryView addSubview:sectionTextView];
    sectionTextView.delegate = self;
    [sectionTextView autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:cancelButton withOffset:12];
    [sectionTextView autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:cancelButton];
    [sectionTextView autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:saveButton];
    [sectionTextView autoSetDimension:ALDimensionHeight toSize:89];
    sectionTextView.layer.cornerRadius = 4;
    sectionTextView.layer.borderWidth = 1;
    sectionTextView.layer.borderColor = (Theme.isDarkThemeEnabled ? darkColor : lightColor).CGColor;
    sectionTextView.tintColor = Theme.isDarkThemeEnabled ? lightColor : darkColor;
    sectionTextView.keyboardType = UIKeyboardTypeDefault;
    if (_contentString.length) {
        sectionTextView.text = _contentString;
        NSString * contentString = [NSString stringWithFormat:@"%lu/%lu",_contentString.length,self.maxLength];
        [self renderCountAttributedStringWithString:contentString];
    }
    
    [alertInputAccessoryView addSubview:self.tipLabel];
    [self.tipLabel autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:sectionTextView];
    [self.tipLabel autoPinEdge:ALEdgeTop toEdge:ALEdgeBottom ofView:sectionTextView withOffset:4];
    
    return alertInputAccessoryView;
}

- (void)renderCountAttributedStringWithString:(NSString *)contentString {
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:contentString];
    NSString *subStr;
    if (contentString.length > 3) {
        subStr = [contentString substringToIndex:contentString.length - 3];
        NSRange range = [contentString rangeOfString:subStr];
        if (self.sectionTextView.text.length == self.maxLength) {
            [attributedString addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithRGBHex:0xF84135] range:range];
        } else {
            [attributedString addAttribute:NSForegroundColorAttributeName value:Theme.primaryTextColor range:range];
        }
        self.tipLabel.attributedText = attributedString;
    } else {
        self.tipLabel.attributedText = attributedString;
    }
}


+ (NSMutableAttributedString *)commonContentAttributesString:(nonnull NSString *)string withFont:(int)fontSize{
    string = string?:@"";
    if (string.length ==0 || !string) {
        return nil;
    }
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineSpacing = 5;// 行间隔
    paragraphStyle.firstLineHeadIndent = 0;// 行间隔
    paragraphStyle.headIndent = 0;// 行间隔
    NSMutableAttributedString *attributes = [[NSMutableAttributedString alloc] initWithString:string];
    [attributes addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:fontSize] range:NSMakeRange(0, string.length)];
    [attributes addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, string.length)];
    return attributes;
}


- (void)cancelButtonClick:(UIButton *)sender {
    [self.view endEditing:true];
    [self dismissViewControllerAnimated:false completion:nil];
    if ([self.alertDelegate respondsToSelector:@selector(cardAlert:actionType:changedText:defaultText:)]) {
        [self.alertDelegate cardAlert:self actionType:DTCardAlertActionTypeCancel changedText:self.sectionTextView.text.ows_stripped defaultText:self.contentString];
    }
}

- (void)saveButtonClick:(UIButton *)sender {
    [self.view endEditing:true];
    if (self.alertType == DTCardAlertViewTypeTextView) {
        [self dismissViewControllerAnimated:true completion:nil];
        [UIView animateWithDuration:0.1 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0];
        } completion:^(BOOL finished) {
        }];
    }
    if ([self.alertDelegate respondsToSelector:@selector(cardAlert:actionType:changedText:defaultText:)]) {
        [self.alertDelegate cardAlert:self actionType:DTCardAlertActionTypeConfirm changedText:self.sectionTextView.text.ows_stripped defaultText:self.contentString];
    }
}


- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    NSUInteger maxLength = self.maxLength;
    if (textView.text.length > maxLength - 1 && ![text isEqualToString:@""]) {
        return NO;
    }
    return YES;
}

- (void)textViewDidChange:(UITextView *)textView {
    NSUInteger maxLength = self.maxLength;
    if (textView.text.length > maxLength) {
        NSString *text = textView.text;
        text = [text substringToIndex:maxLength];
        textView.text = text;
    }
    NSString * contentString = [NSString stringWithFormat:@"%lu/%lu",textView.text.length,self.maxLength];
    [self renderCountAttributedStringWithString:contentString];
    if (textView.text.length == maxLength) {
        textView.layer.borderColor = [UIColor colorWithRGBHex:0xF84135].CGColor;
    } else {
        UIColor *lightColor = [UIColor colorWithRGBHex:0x1773EB];
        UIColor *darkColor = [UIColor colorWithRGBHex:0x4DA0FF];
        textView.layer.borderColor = (Theme.isDarkThemeEnabled ? darkColor : lightColor).CGColor;
    }
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.alertType == DTCardAlertViewTypeTextView) {
        [UIView animateWithDuration:0.2 delay:0.01 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        } completion:nil];
    }
    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.alertType == DTCardAlertViewTypeDefault) {
        [self presentAnimation];
    } else {
        [self.inputTextView becomeFirstResponder];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.sectionTextView becomeFirstResponder];
        });
    }
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)presentAnimation {
    CGRect frame = self.showContentView.frame;
    CGRect superViewFrame = self.view.frame;
    [UIView animateWithDuration:0.2 delay:0.1 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
        self.showContentView.frame = CGRectMake(frame.origin.x, superViewFrame.size.height - frame.size.height, frame.size.width, frame.size.height);
    } completion:nil];
}

- (void)dismisAnimation {
    CGRect frame = self.showContentView.frame;
    CGRect superViewFrame = self.view.frame;
    [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0];
        self.showContentView.frame = CGRectMake(frame.origin.x, superViewFrame.size.height, frame.size.width, frame.size.height);
    } completion:^(BOOL finished) {
        self.view.hidden = true;
        [self dismissViewControllerAnimated:false completion:nil];
    }];
}


- (void)confirmButtonClick:(UIButton *)sender {
    [self dismisAnimation];
}

- (UIView *)maskView {
    if (!_maskView) {
        _maskView = [UIView new];
        _maskView.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x000000] : [UIColor colorWithRGBHex:0x000000];
        _maskView.alpha = 0;
    }
    return _maskView;
}

- (UIView *)contentView {
    if (!_contentView) {
        _contentView = [UIView new];
        _contentView.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x181A20] : [UIColor colorWithRGBHex:0xFFFFFF];
        _contentView.layer.cornerRadius = 8;
        _contentView.clipsToBounds = true;
        if (@available(iOS 11.0, *)) {
            _contentView.layer.maskedCorners = (CACornerMask)(UIRectCornerTopLeft|UIRectCornerTopRight);
        } else {
            
        };
    }
    return _contentView;
}

- (UIView *)showContentView {
    if (!_showContentView) {
        _showContentView = [UIView new];
//        _showContentView.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x181A20] : [UIColor colorWithRGBHex:0xFFFFFF];
        _showContentView.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x2B3139] : [UIColor colorWithRGBHex:0xFFFFFF];
        _showContentView.layer.cornerRadius = 8;
        _showContentView.clipsToBounds = true;
        if (@available(iOS 11.0, *)) {
            _showContentView.layer.maskedCorners = (CACornerMask)(UIRectCornerTopLeft|UIRectCornerTopRight);
        } else {
            
        };
    }
    return _showContentView;
}


- (void)setAttributedContentString:(NSAttributedString *)attributedContentString {
    self.contentTextView.attributedText = attributedContentString;
    self.contentTextView.textColor = Theme.primaryTextColor;
}

- (void)setContentString:(NSString *)contentString {
    _contentString = contentString;
    if (self.alertType == DTCardAlertViewTypeDefault) {
        NSMutableAttributedString *attributedString = [self.class commonContentAttributesString:contentString withFont:14];
        self.contentTextView.attributedText = attributedString;
        self.contentTextView.textColor = Theme.primaryTextColor;
    } else {
        self.sectionTextView.text = contentString;
    }
    if (self.maxLength > 0) {
        NSString *lengthLimit = [NSString stringWithFormat:@"%lu/%lu", contentString.length, self.maxLength];
        [self renderCountAttributedStringWithString:lengthLimit];
    }
}

- (void)setTitleString:(NSString *)titleString {
    self.titleLabel.text = titleString;
}

- (UILabel *)titleLabel {
    if (!_titleLabel) {
        _titleLabel = [UILabel new];
        _titleLabel.font = [UIFont fontWithName:@"PingFangSC-Medium" size:16];
        _titleLabel.textColor = Theme.primaryTextColor;
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        
    }
    return _titleLabel;
}

- (UITextView *)contentTextView {
    if (!_contentTextView) {
        _contentTextView = [UITextView new];
        _contentTextView.font = [UIFont systemFontOfSize:14];
        _contentTextView.textAlignment = NSTextAlignmentLeft;
        _contentTextView.userInteractionEnabled = false;
        _contentTextView.textColor = Theme.primaryTextColor;
        _contentTextView.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x181A20] : [UIColor colorWithRGBHex:0xFFFFFF] ;
    }
    return _contentTextView;
}

- (UITextView *)inputTextView {
    if (!_inputTextView) {
        _inputTextView = [UITextView new];
        _inputTextView.font = [UIFont systemFontOfSize:14];
        _inputTextView.textAlignment = NSTextAlignmentLeft;
    }
    return _inputTextView;
}

- (UIButton *)confirmButton {
    if (!_confirmButton) {
        _confirmButton = [UIButton new];
        _confirmButton.titleLabel.font = [UIFont fontWithName:@"PingFangSC-Medium" size:16];
        _confirmButton.titleLabel.textColor = [UIColor colorWithRGBHex:0x4DA0FF];
        [_confirmButton setTitleColor:[UIColor colorWithRGBHex:0x4DA0FF] forState:UIControlStateNormal];
        [_confirmButton setTitle:@"OK" forState:UIControlStateNormal];
        [_confirmButton addTarget:self action:@selector(confirmButtonClick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _confirmButton;
}

- (UIView *)lineView {
    UIView *lineView = [UIView new];
    lineView.backgroundColor = Theme.isDarkThemeEnabled ? [UIColor colorWithRGBHex:0x474D57] : [UIColor colorWithRGBHex:0xEAECEF];
    return lineView;
}

- (UILabel *)tipLabel {
    if (!_tipLabel) {
        _tipLabel = [UILabel new];
        _tipLabel.textColor = [UIColor lightGrayColor];
        _tipLabel.font = [UIFont systemFontOfSize:13];
    }
    return _tipLabel;
}

@end
