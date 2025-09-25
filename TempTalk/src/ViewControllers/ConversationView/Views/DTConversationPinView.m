//
//  DTConversationPinView.m
//  Wea
//
//  Created by Ethan on 2022/3/14.
//

#import "DTConversationPinView.h"
#import "TempTalk-Swift.h"
#import <TTMessaging/Theme.h>
#import "DTPinPageControl.h"
#import <TTServiceKit/TTServiceKit-Swift.h>

@interface DTConversationPinView ()<DTPinPageControlDelegate>

//@property (nonatomic, weak) UIVisualEffectView *blurView;
@property (nonatomic, weak) UILabel *lbTitle;
@property (nonatomic, weak) UILabel *lbIndex;
@property (nonatomic, weak) UILabel *lbMessage;
@property (nonatomic, weak) UIButton *btnPinnedDetail;
//@property (nonatomic, weak) UIView *topSeparator;
@property (nonatomic, weak) UIView *bottomSeparator;
@property (nonatomic, weak) DTPinPageControl *pageControl;
@property (nonatomic, weak) UIView *superView;
@property (nonatomic, strong) NSLayoutConstraint *topMargin;

@property (nonatomic, strong) NSArray <TSMessage *> *pinnedMessages;
@property (nonatomic, assign) NSUInteger currentIndex;

@end

@implementation DTConversationPinView

- (instancetype)init {
    
    if (self = [super init]) {
        [self createContents];
        [self applyTheme];

        _currentIndex = 0;
    }
    
    return self;
}

- (void)applyTheme {
    
//    self.blurView.effect = Theme.barBlurEffect;
//    if (@available(iOS 15.0, *)) {
//        self.blurView.contentView.backgroundColor = [Theme.navbarBackgroundColor colorWithAlphaComponent:0.8];
//    }
//    self.topSeparator.backgroundColor = Theme.tableView2SeparatorColor;
    self.backgroundColor = Theme.backgroundColor;
    self.lbTitle.textColor = Theme.themeBlueColor;
    self.lbIndex.textColor = Theme.themeBlueColor;
    self.btnPinnedDetail.imageView.tintColor = Theme.themeBlueColor;
    self.bottomSeparator.backgroundColor = Theme.tableView2SeparatorColor;
}

- (UIFont *)labelFont {
    return [UIFont systemFontOfSize:15];
}

- (void)createContents {
        
//    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:Theme.barBlurEffect];
//    _blurView = blurView;
//    [self addSubview:blurView];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapAction:)];
    [self addGestureRecognizer:tap];
    
    DTPinPageControl *pageControl = [DTPinPageControl new];
    _pageControl = pageControl;
    pageControl.delegate = self;
    pageControl.hidden = YES;
    [self addSubview:pageControl];
    
    UILabel *lbTitle = [UILabel new];
    _lbTitle = lbTitle;
    lbTitle.text = @"Pinned Message";
    lbTitle.textColor = Theme.themeBlueColor;
    lbTitle.font = [self.labelFont ows_semibold];
    [self addSubview:lbTitle];
    
    UILabel *lbIndex = [UILabel new];
    _lbIndex = lbIndex;
    lbIndex.clipsToBounds = YES;
    lbIndex.textColor = Theme.themeBlueColor;
    lbIndex.font = [self.labelFont ows_semibold];
    [self addSubview:lbIndex];
    
    UILabel *lbMessage = [UILabel new];
    _lbMessage = lbMessage;
    lbMessage.clipsToBounds = YES;
    lbMessage.font = self.labelFont;
    [self addSubview:lbMessage];
    
    UIButton *btnPinnedDetail = [UIButton buttonWithType:UIButtonTypeCustom];
    _btnPinnedDetail = btnPinnedDetail;
    btnPinnedDetail.imageView.tintColor = Theme.themeBlueColor;
    UIImage *btnImage = [[UIImage imageNamed:@"ic_pin_list"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [btnPinnedDetail setImage:btnImage forState:UIControlStateNormal];
    [btnPinnedDetail setImage:btnImage forState:UIControlStateHighlighted];
    [btnPinnedDetail addTarget:self action:@selector(btnPinnedDetailAction:) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:btnPinnedDetail];
    
//    UIView *topSeparator = [UIView new];
//    _topSeparator = topSeparator;
//    [self addSubview:topSeparator];
    
    UIView *bottomSeparator = [UIView new];
    _bottomSeparator = bottomSeparator;
    [self addSubview:bottomSeparator];
    
    CGFloat separatorHeight = 1.0/[UIScreen mainScreen].scale;
    
//    [blurView autoPinEdgesToSuperviewEdges];
    
//    [topSeparator autoPinEdgeToSuperviewEdge:ALEdgeTop];
//    [topSeparator autoPinEdgeToSuperviewEdge:ALEdgeLeading];
//    [topSeparator autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
//    [topSeparator autoSetDimension:ALDimensionHeight toSize:separatorHeight];
    
    [btnPinnedDetail autoPinEdgeToSuperviewEdge:ALEdgeTop];
    [btnPinnedDetail autoPinEdgeToSuperviewEdge:ALEdgeBottom];
    [btnPinnedDetail autoPinEdgeToSuperviewEdge:ALEdgeRight withInset:8.f];
    [btnPinnedDetail autoSetDimension:ALDimensionWidth toSize:30.f];
    
    [pageControl autoPinEdgeToSuperviewEdge:ALEdgeTop];
    [pageControl autoPinEdgeToSuperviewEdge:ALEdgeBottom];
    [pageControl autoPinEdgeToSuperviewEdge:ALEdgeLeading withInset:10.f];
    [pageControl autoSetDimension:ALDimensionWidth toSize:2.f];
    
    [lbTitle autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:5.f];
    [lbTitle autoPinEdge:ALEdgeLeading toEdge:ALEdgeTrailing ofView:pageControl withOffset:10.f];
    
    [lbIndex autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:lbTitle];
    [lbIndex autoPinEdge:ALEdgeLeading toEdge:ALEdgeTrailing ofView:lbTitle withOffset:10.f];

    [lbMessage autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:6.f];
    [lbMessage autoPinLeadingToEdgeOfView:lbTitle];
    [lbMessage autoPinEdge:ALEdgeTrailing toEdge:ALEdgeLeading ofView:btnPinnedDetail withOffset:-3.f relation:NSLayoutRelationLessThanOrEqual];
    
    [bottomSeparator autoPinEdgeToSuperviewEdge:ALEdgeBottom];
    [bottomSeparator autoPinEdgeToSuperviewEdge:ALEdgeLeading];
    [bottomSeparator autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
    [bottomSeparator autoSetDimension:ALDimensionHeight toSize:separatorHeight];
}

- (void)btnPinnedDetailAction:(id)sender {
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(rightItemActionOfPinView:)]) {
        [self.delegate rightItemActionOfPinView:self];
    }
}

- (void)tapAction:(UITapGestureRecognizer *)tap {
    
    if (!CGRectContainsPoint(CGRectMake(0, 0, self.width - 48.0, self.height), [tap locationInView:self])) {
        return;
    }
    
    if (self.pinnedMessages.count == 0) {
        return;
    }
    
    NSUInteger lastIndex = self.currentIndex;
    CATransitionSubtype subtype = kCATransitionFromBottom;
    if (self.currentIndex == 0) {
        self.currentIndex = self.pinnedMessages.count - 1;
        subtype = kCATransitionFromTop;
    } else {
        self.currentIndex --;
    }
    
    TSMessage *pinnedMessage = self.pinnedMessages[self.currentIndex];
    if (self.currentIndex == self.pinnedMessages.count - 1) {
        self.lbIndex.text = @"";
    } else {
        self.lbIndex.text = [NSString stringWithFormat:@"#%ld", self.currentIndex + 1];
    }
    self.lbMessage.text = [self pinnedMessagePreviewText:pinnedMessage];
    
    if (self.pinnedMessages.count > 1) {
        CATransition *transition = [CATransition animation];
        transition.duration = 0.3;
        transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
        transition.type = @"oglFlip";
        transition.subtype = subtype;

        [self.lbIndex.layer addAnimation:transition forKey:nil];
        [self.lbMessage.layer addAnimation:transition forKey:nil];
    }
    
    [self.pageControl scrollToIndex:(NSInteger)self.currentIndex animated:YES];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(pinView:didSelectIndex:)]) {
        [self.delegate pinView:self didSelectIndex:lastIndex];
    }
}

- (void)reloadData {
    
    if (!self.delegate || ![self.delegate respondsToSelector:@selector(pinnedMessagesForPreview)]) {
        return;
    }
    self.pinnedMessages = [self.delegate pinnedMessagesForPreview];
    
    NSString *btnImageName = nil;
//    if (self.pinnedMessages.count > 1) {
        btnImageName = @"ic_pin_list";
//    } else {
//        btnImageName = @"ic_pin_cancel";
//    }
    UIImage *btnImage = [[UIImage imageNamed:btnImageName] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self.btnPinnedDetail setImage:btnImage forState:UIControlStateNormal];
    [self.btnPinnedDetail setImage:btnImage forState:UIControlStateHighlighted];
    
    self.currentIndex = self.pinnedMessages.count - 1;
    self.lbMessage.text = [self pinnedMessagePreviewText:self.pinnedMessages.lastObject];
    self.lbIndex.text = @"";
    
    self.pageControl.hidden = NO;
    [self.pageControl reloadPageNumbers];
}

- (NSString *)pinnedMessagePreviewText:(TSMessage *)pinnedMessage {

    if ([pinnedMessage conformsToProtocol:@protocol(OWSPreviewText)]) {
        id<OWSPreviewText> previewable = (id<OWSPreviewText>)pinnedMessage;
        __block NSString *previewText = @"";
        [self.databaseStorage readWithBlock:^(SDSAnyReadTransaction * _Nonnull transaction) {
            previewText = [previewable previewTextWithTransaction:transaction].filterStringForDisplay;
        }];
        previewText = [previewText stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        previewText = [previewText stringByReplacingOccurrencesOfString:@"\r" withString:@" "];
        return previewText;
    } else {
        return @"";
    }
}

- (void)addPinViewToSuperview:(UIView *)superview
                     animated:(BOOL)animated
                      handler:(void(^)(void))handler {
    
    _superView = superview;
    
    self.hidden = YES;
    [superview addSubview:self];
    [self autoSetDimension:ALDimensionHeight toSize:50.f];
    [self autoPinEdgeToSuperviewEdge:ALEdgeLeading];
    [self autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
    self.topMargin = [self autoPinEdgeToSuperviewSafeArea:ALEdgeTop withInset:-50];

    if (animated) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.hidden = NO;
            [NSLayoutConstraint deactivateConstraints:@[self.topMargin]];
            self.topMargin = [self autoPinEdgeToSuperviewSafeArea:ALEdgeTop];
            [UIView animateWithDuration:0.3 animations:^{
                if (handler) handler();
                [superview layoutIfNeeded];
            }];
        });
    } else {
        self.hidden = NO;
        [NSLayoutConstraint deactivateConstraints:@[self.topMargin]];
//        self.topMargin = [self autoPinEdgeToSuperviewSafeArea:ALEdgeTop];
        self.topMargin = [self autoPinEdgeToSuperviewSafeArea:ALEdgeTop];
        if (handler) handler();
        [superview layoutIfNeeded];
    }
}

- (void)removePinViewHandler:(void(^)(void))handler {
    
    [NSLayoutConstraint deactivateConstraints:@[self.topMargin]];
    self.topMargin = [self autoPinEdgeToSuperviewSafeArea:ALEdgeTop withInset:-50];
    [UIView animateWithDuration:0.3 animations:^{
        if (handler) handler();
        [self.superView layoutIfNeeded];
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

//MARK: DTPinPageControlDelegate
- (NSInteger)numberOfPages {
    
    return (NSInteger)self.pinnedMessages.count;
}

- (void)pageControl:(DTPinPageControl *)pageControl scrollToIndex:(NSInteger)index {
    
}

@end
