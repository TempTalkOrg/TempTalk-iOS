//
//  DTSelectedAccountToolView.m
//  Wea
//
//  Created by hornet on 2022/1/5.
//

#import "DTSelectedAccountToolView.h"
#import "DTAddToGroupItem.h"
#import <TTMessaging/UIView+SignalUI.h>
#import <TTMessaging/TTMessaging-Swift.h>

extern NSString *const kDTAddToGroupItemIdentifier;

static CGFloat const kDTSelectedItemWidth = 64;
// Tall-host threshold: at/above this the redesigned avatar+name item is used.
static CGFloat const kDTSelectedTallHostMinHeight = 60;
static CGFloat const kDTSelectedItemSpacing = 12;

@interface DTSelectedAccountToolView()<UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@property(nonatomic,strong) UICollectionView *collectionView;
@property(nonatomic,strong) NSArray *dataSource;
@end

@implementation DTSelectedAccountToolView

- (instancetype)initWithDataSource:(NSArray *)dataSource {
    self = [super init];
    if (self) {
        self.dataSource = dataSource;
        [self creatSubView];
        [self configLayout];
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (void)creatSubView {
    [self addSubview:self.collectionView];
}

- (void)configLayout {
    [self.collectionView autoPinEdgesToSuperviewEdges];
}
- (void)reloadWithData:(NSArray *)datasource {
    self.dataSource = datasource;
    [self.collectionView reloadData];
    if (self.dataSource.count >0) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:(NSInteger)self.dataSource.count-1 inSection:0];
        [self.collectionView scrollToItemAtIndexPath:indexPath atScrollPosition:UICollectionViewScrollPositionNone animated:false];
    }
}
#pragma mark collectionView delegate
//collectionView的代理方法及数据源方法
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

//每个section的item个数
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {

    return (NSInteger)self.dataSource.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    DTAddToGroupItem *item = [collectionView dequeueReusableCellWithReuseIdentifier:kDTAddToGroupItemIdentifier forIndexPath:indexPath];
    if (indexPath.row <= (NSInteger)self.dataSource.count -1) {
        [item configWithReceptId:[self.dataSource objectAtIndex:(NSUInteger)indexPath.row]];
    }

    return item;
}
//设置每个item的尺寸
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    CGFloat available = CGRectGetHeight(collectionView.bounds);
    // Tall host: 64-wide avatar+name item; legacy short host: square avatar-only item.
    if (available >= kDTSelectedTallHostMinHeight) {
        return CGSizeMake(kDTSelectedItemWidth, available);
    }
    CGFloat side = available > 0 ? available : kDTSelectedItemWidth;
    return CGSizeMake(side, side);
}

// No-op: the OK button was removed; kept for API compatibility (DTGroupMemberController).
- (void)showOKBtn:(BOOL)show {
}
- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section{
    return UIEdgeInsetsMake(0, 0, 0, 0);
}

//设置每个item垂直间距
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section {
    return 0;
}

//设置每个item水平间距
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section {
    return kDTSelectedItemSpacing;
}
//设置item选中的状态
- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    return true;
}
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.toolViewDelegate && [self.toolViewDelegate respondsToSelector:@selector(dtSelectedAccountToolView:collectionView:didSelectItemAtIndexPath:)]) {
        [self.toolViewDelegate dtSelectedAccountToolView:self collectionView:collectionView didSelectItemAtIndexPath:indexPath];
    }
}

#pragma mark setter & getter

- (UICollectionView *)collectionView {
    if (!_collectionView) {
        UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
        layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectMake(0,0, 0, 0) collectionViewLayout:layout];
        _collectionView.delegate = self;
        _collectionView.dataSource = self;
        _collectionView.showsVerticalScrollIndicator = NO;
        _collectionView.showsHorizontalScrollIndicator=NO;
        [_collectionView registerClass:[DTAddToGroupItem class] forCellWithReuseIdentifier:kDTAddToGroupItemIdentifier];
        _collectionView.backgroundColor = [UIColor clearColor];
        _collectionView.bounces = NO;
    }
    return _collectionView;
}

- (NSArray *)dataSource {
    if (!_dataSource) {
        _dataSource = @[];
    }
    return _dataSource;
}
@end
