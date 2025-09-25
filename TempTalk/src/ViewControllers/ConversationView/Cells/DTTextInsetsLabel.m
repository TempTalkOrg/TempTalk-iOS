//
//  DTTextInsetsLabel.m
//  Wea
//
//  Created by hornet on 2022/1/12.
//

#import "DTTextInsetsLabel.h"
#import <TTServiceKit/Localize_Swift.h>

@interface DTTextInsetsLabel()
@property (nonatomic, strong) UIPasteboard *pasteBoard;
@end

@implementation DTTextInsetsLabel

- (instancetype)init {
    if (self = [super init]) {
        _textInsets = UIEdgeInsetsZero;
        [self attachLongPress];
        self.pasteBoard = [UIPasteboard generalPasteboard];
    }
    return self;
}
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _textInsets = UIEdgeInsetsZero;
    }
    return self;
}
- (void)drawTextInRect:(CGRect)rect {
    [super drawTextInRect:UIEdgeInsetsInsetRect(rect, _textInsets)];
}

- (void)attachLongPress{
    self.userInteractionEnabled = YES;
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressAction:)];
    [self addGestureRecognizer:longPress];
}

- (void)longPressAction:(UILongPressGestureRecognizer *)longPressGesture {
    if (longPressGesture.state == UIGestureRecognizerStateBegan) {
        [self becomeFirstResponder];
        UIMenuItem *copyMenuItem = [[UIMenuItem alloc]initWithTitle:Localized(@"MESSAGE_ACTION_COPY_MEDIA", @"") action:@selector(copyAction:)];
        UIMenuController *menuController = [UIMenuController sharedMenuController];
        [menuController setMenuItems:[NSArray arrayWithObjects:copyMenuItem, nil]];
        [menuController setTargetRect:self.frame inView:self.superview];
        [menuController setMenuVisible:YES animated:YES];
    }
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(copyAction:)) {
        return YES;
    }
    if (action == @selector(pasteAction:)) {
        return YES;
    }
    if (action == @selector(cutAction:)) {
        return YES;
    }
    return NO; //隐藏系统默认的菜单项
}

- (void)copyAction:(id)sender {
    self.pasteBoard.string = self.text;
}

- (void)pasteAction:(id)sender {
    self.text = self.pasteBoard.string;
}

- (void)cutAction:(id)sender  {
    self.pasteBoard.string = self.text;
    self.text = nil;
}

@end
