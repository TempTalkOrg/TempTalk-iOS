//
//  DTPersonalGenderController.m
//  Wea
//
//  Created by hornet on 2021/11/16.
//

#import "DTPersonalGenderController.h"
#import "UIView+SignalUI.h"

@interface DTPersonalGenderController ()
@property(nonatomic,strong) UINavigationBar *topBar;

@end

@implementation DTPersonalGenderController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    [self addSubviews];
    [self configUI];
}

- (void)addSubviews {
    [self.view addSubview:self.topBar];
}

- (void)configUI {
    [self.topBar autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:self.view withOffset:0];
    [self.topBar autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self.view];
    [self.topBar autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self.view];
    [self.topBar autoSetDimension:ALDimensionHeight toSize:44];
}

- (UINavigationBar *)topBar {
    if (!_topBar) {
        _topBar = [[UINavigationBar alloc] init];
        _topBar.backgroundColor = [UIColor redColor];
    }
    return _topBar;
}

@end
