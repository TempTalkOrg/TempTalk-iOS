//
//  DTSelectedAccountToolView.m
//  Wea
//
//  Created by hornet on 2022/1/5.
//

#import "DTSelectedAccountToolView.h"
#import "DTAddToGroupItem.h"
#import <TTMessaging/UIView+SignalUI.h>
#import <TTMessaging/Theme.h>

extern NSString *const kDTAddToGroupItemIdentifier;

@interface DTSelectedAccountToolView()<UICollectionViewDelegate, UICollectionViewDataSource>
@property(nonatomic,strong) UIButton *OKBtn;
@property(nonatomic,strong) UICollectionView *collectionView;
@property(nonatomic,strong) NSArray *dataSource;
@property(nonatomic,strong) NSLayoutConstraint *collectionViewRightConstraint;
@property(nonatomic,strong) NSLayoutConstraint *oKBtnWidth;
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
    [self addSubview:self.OKBtn];
    
}

- (void)configLayout {
    [self.OKBtn autoVCenterInSuperview];
    [self.OKBtn autoPinEdge:ALEdgeRight toEdge:ALEdgeRight ofView:self withOffset:0];
    [self.OKBtn autoSetDimension:ALDimensionHeight toSize:30];
    self.oKBtnWidth = [self.OKBtn autoSetDimension:ALDimensionWidth toSize:50];
    
    [self.collectionView autoPinEdge:ALEdgeTop toEdge:ALEdgeTop ofView:self];
    [self.collectionView autoPinEdge:ALEdgeLeft toEdge:ALEdgeLeft ofView:self withOffset:0];
    self.collectionViewRightConstraint = [self.collectionView autoPinEdge:ALEdgeRight toEdge:ALEdgeLeft ofView:self.OKBtn withOffset:-10];
    [self.collectionView autoPinEdge:ALEdgeBottom toEdge:ALEdgeBottom ofView:self];
   
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
    return CGSizeMake(self.frame.size.height,self.frame.size.height);
}
- (void)showOKBtn:(BOOL)show {
    if (show) {
        self.OKBtn.hidden = false;
        self.oKBtnWidth.constant = 50;
        self.collectionViewRightConstraint.constant = -10;
    }else {
        self.oKBtnWidth.constant = 0;
        self.collectionViewRightConstraint.constant = 0;
        self.OKBtn.hidden = true;
    }
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
    return 2;
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

- (void)OKBtnClick:(UIButton *)sender {
    if (self.toolViewDelegate && [self.toolViewDelegate respondsToSelector:@selector(dtSelectedAccountToolView:okBtnClick:)]) {
        [self.toolViewDelegate dtSelectedAccountToolView:self okBtnClick:sender];
    }
}

#pragma mark setter & getter
- (UIButton *)OKBtn {
    if (!_OKBtn) {
        _OKBtn = [[UIButton alloc] init];
        [_OKBtn setTitle:@"OK" forState:UIControlStateNormal];
        [_OKBtn addTarget:self action:@selector(OKBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        _OKBtn.layer.cornerRadius = 5;
        _OKBtn.layer.masksToBounds = true;
        [_OKBtn setBackgroundColor:Theme.accentBlueColor];
    }
    return _OKBtn;
}

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
