//
//  DTPinPageControl.m
//  Wea
//
//  Created by Ethan on 2022/3/15.
//

#import "DTPinPageControl.h"
#import "DTPinPageDot.h"
#import "TempTalk-Swift.h"
#import <TTMessaging/Theme.h>

#define DTPinPageControlHeight 50.0
#define DTPinPageControlWidth  2.0

static NSString *DTPinPageDotID = @"DTPinPageDotID";

@interface DTPinPageControl ()<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, assign) NSInteger numberOfPages;

@end

@implementation DTPinPageControl

- (instancetype)init {
    
    if (self = [super initWithFrame:CGRectZero]) {
        
        self.numberOfPages = 0;
        [self createSubviews];
    }
    
    return self;
}

- (void)createSubviews {
    
    [self addSubview:self.tableView];
    
    [self.tableView autoPinEdgesToSuperviewEdges];
//    [self.tableView autoPinEdgeToSuperviewEdge:ALEdgeTrailing];
//    [self.tableView autoPinEdgeToSuperviewEdge:ALEdgeTop withInset:7.0];
//    [self.tableView autoPinEdgeToSuperviewEdge:ALEdgeBottom withInset:7.0];
}

- (UITableView *)tableView {
    
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        _tableView.backgroundColor = [UIColor clearColor];
        _tableView.showsVerticalScrollIndicator = NO;
        _tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
        _tableView.delegate = self;
        _tableView.dataSource = self;
        _tableView.tableHeaderView = ({
            UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, 7)];
            header;
        });
        _tableView.tableFooterView = ({
            UIView *footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kScreenWidth, 7)];
            footer;
        });
        [_tableView registerNib:[UINib nibWithNibName:NSStringFromClass(DTPinPageDot.class) bundle:nil] forCellReuseIdentifier:DTPinPageDotID];
    }
    
    return _tableView;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return self.numberOfPages;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
        
    DTPinPageDot *dot = [tableView dequeueReusableCellWithIdentifier:DTPinPageDotID forIndexPath:indexPath];
    
    return dot;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (self.numberOfPages == 0) {
        return CGFLOAT_MIN;
    } else if (self.numberOfPages == 1) {
        return DTPinPageControlHeight - 14;
    } else if (self.numberOfPages == 2) {
        return (DTPinPageControlHeight - 14) / 2;
    } else if (self.numberOfPages == 3) {
        return (DTPinPageControlHeight - 14) / 3;
    } else if (self.numberOfPages == 4) {
        return (DTPinPageControlHeight - 14) / 4;
    }
    
    return (DTPinPageControlHeight) / 5;
}

- (void)reloadPageNumbers {
    
    self.numberOfPages = [self.delegate numberOfPages];
    [self.tableView reloadData];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self scrollToIndex:self.numberOfPages - 1 animated:YES];
    });
}

- (void)scrollToIndex:(NSInteger)index animated:(BOOL)animated {
    
    if (index < 0) return;
    
//    UITableViewScrollPosition scrollPosition = UITableViewScrollPositionMiddle;
//    if (self.numberOfPages < 5) {
//        scrollPosition = UITableViewScrollPositionNone;
//    }
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
    [self.tableView selectRowAtIndexPath:indexPath animated:animated scrollPosition:UITableViewScrollPositionMiddle];
}

@end
