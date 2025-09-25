//
//  DTMultiMeetingView.m
//  Signal
//
//  Created by Ethan on 2022/7/29.
//  Copyright © 2022 Difft. All rights reserved.
//

#import "DTMultiMeetingView.h"
#import "DTMultiMeetingMiniCell.h"
#import "DTMultiChatItemModel.h"
#import "TempTalk-Swift.h"
#import <TTServiceKit/TTServiceKit-Swift.h>
#import "DTHandupTableContainerCell.h"

#define LineSpacing 8.f
static NSInteger maxExpandCount = 5;

@interface DTMultiMeetingView ()<UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>

@property (nonatomic, assign) DTMultiMeetingMode mode;
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) NSArray <DTMultiChatItemModel *> *broadcasters;
@property (nonatomic, strong) NSArray <DTMultiChatItemModel *> *handupAudiences;

@property (nonatomic, assign) BOOL isLiveStream;

@end

@implementation DTMultiMeetingView

- (instancetype)initWithMode:(DTMultiMeetingMode)mode
                isLiveStream:(BOOL)isLiveStream {
    self = [super init];
    if (self) {
        _mode = mode;
        _isLiveStream = isLiveStream;
        
        [self addSubview:self.collectionView];
        [self.collectionView autoPinEdgesToSuperviewEdges];
        if (mode == DTMultiMeetingModeDefault) {
            UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressAction:)];
            [self.collectionView addGestureRecognizer:longPress];
        }
    }
    return self;
}

- (void)longPressAction:(UILongPressGestureRecognizer *)longPress {
    
    if (longPress.state != UIGestureRecognizerStateBegan) {
        return;
    }
    
    CGPoint location = [longPress locationInView:self.collectionView];
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:location];
    UICollectionViewCell *cell = [self.collectionView cellForItemAtIndexPath:indexPath];
    if (cell) {
        DTMultiChatItemModel *itemModel = self.broadcasters[(NSUInteger)indexPath.item];
        OWSLogDebug(@"%@ - %ld - %@ - %@", self.logTag, indexPath.item, itemModel.displayName, itemModel.account);
        if (self.meetingViewDelegate && [self.meetingViewDelegate respondsToSelector:@selector(meetingView:didSelectUserViewAtItemModel:)]) {
            [self.meetingViewDelegate meetingView:self didSelectUserViewAtItemModel:itemModel];
        }
    }
}

#pragma mark - update
- (void)updateWithBroadcasters:(NSArray<DTMultiChatItemModel *> *)broadcasters
               handupAudiences:(nullable NSArray<DTMultiChatItemModel *> *)handupAudiences {

    self.broadcasters = broadcasters;
    self.handupAudiences = handupAudiences;
    
    DispatchMainThreadSafe(^{
        [self.collectionView reloadData];
    });
}

- (void)udpateCollectionContents {
    DispatchMainThreadSafe(^{
        [self.collectionView reloadData];
    });
}

- (CGSize)adjustCellSize {
    
    if (self.mode == DTMultiMeetingModeMini) {
        return CGSizeMake(184, 48);
    }
    
    NSUInteger countPerLine = 2;

    CGFloat totalWidth = MIN(kScreenWidth, kScreenHeight) - 32;
    CGFloat cellWidth = floor((totalWidth - (countPerLine - 1) * LineSpacing) / (CGFloat)countPerLine);

    return CGSizeMake(cellWidth, cellWidth);
}

- (UICollectionView *)collectionView {
    if (!_collectionView) {
        UICollectionViewFlowLayout *flowLayout = [UICollectionViewFlowLayout new];
        flowLayout.scrollDirection = UICollectionViewScrollDirectionVertical;
        if (self.mode == DTMultiMeetingModeMini) {
            flowLayout.sectionInset = UIEdgeInsetsZero;
            flowLayout.minimumLineSpacing = 0;
            flowLayout.minimumInteritemSpacing = 0;
        } else {
            flowLayout.sectionInset = UIEdgeInsetsMake(10, 16, 130, 16);
            flowLayout.minimumLineSpacing = LineSpacing;
            flowLayout.minimumInteritemSpacing = LineSpacing;
        }
        _collectionView = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:flowLayout];
        _collectionView.backgroundColor = [UIColor clearColor];
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        _collectionView.alwaysBounceVertical = YES;
        _collectionView.showsVerticalScrollIndicator = YES;
        _collectionView.showsHorizontalScrollIndicator = NO;
        _collectionView.backgroundView = ({
            UIView *backgroundView = [UIView new];
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapCollectionBackgroundAction:)];
            [backgroundView addGestureRecognizer:tap];
            backgroundView;
        });

        _collectionView.layer.masksToBounds = YES;
        [_collectionView registerClass:[DTMultiMeetingMiniCell class]
            forCellWithReuseIdentifier:[DTMultiMeetingMiniCell reuseIdentifier]];
        [_collectionView registerClass:[DTHandupGuestHeader class]
            forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                   withReuseIdentifier:DTHandupGuestHeader.reuseIdentifier];
        [_collectionView registerClass:[DTHandupGuestFooter class]
            forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                   withReuseIdentifier:DTHandupGuestFooter.reuseIdentifier];
        [_collectionView registerClass:[DTHandupTableContainerCell class]
            forCellWithReuseIdentifier:[DTHandupTableContainerCell reuseIdentifier]];

    }
    
    return _collectionView;
}

- (void)tapCollectionBackgroundAction:(UITapGestureRecognizer *)tap {
    
    if (!_tapBackgroundHandler) return;
    self.tapBackgroundHandler();
}

//MARK: UICollectionViewDataSource/UICollectionViewDelegate
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return !self.isLiveStream ? 1 : 2;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
    
    if (!self.isLiveStream) {
        BOOL hasHands = self.getHangupList.count > 0;
        NSInteger cellCount = hasHands ? 1:0;
        return (NSInteger)self.broadcasters.count + cellCount;
    }
    
    NSInteger numberOfItems = (NSInteger)(section == 0 ? MIN(self.handupAudiences.count, 3) : self.broadcasters.count);
    return numberOfItems;
}

- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (self.isLiveStream) {
        DTMultiMeetingMiniCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[DTMultiMeetingMiniCell reuseIdentifier] forIndexPath:indexPath];
        if (indexPath.section == 0) {
            if ((NSUInteger)indexPath.item < self.handupAudiences.count) {
                DTMultiChatItemModel *itemModel = self.handupAudiences[(NSUInteger)indexPath.item];
                cell.itemModel = itemModel;
                BOOL displayCorner = ((NSUInteger)indexPath.item == MIN(self.handupAudiences.count, 3) - 1);
                [cell setDisplayBackground:YES displayCorner:displayCorner];
            }
        } else {
            if ((NSUInteger)indexPath.item < self.broadcasters.count) {
                DTMultiChatItemModel *itemModel = self.broadcasters[(NSUInteger)indexPath.item];
                cell.itemModel = itemModel;
                [cell setDisplayBackground:NO displayCorner:NO];
            }
        }
        return cell;
    } else {
        if (self.getHangupList.count > 0 ) {
            if (indexPath.item == 0) {
                DTHandupTableContainerCell *handupCell = [collectionView dequeueReusableCellWithReuseIdentifier:[DTHandupTableContainerCell reuseIdentifier] forIndexPath:indexPath];
                [handupCell configureWithHandupList:self.getHangupList
                                  isExpanded:self.isHandupExpanded
                                   maxCount:maxExpandCount
                                   onToggle:^(BOOL expanded) {
                    self.isHandupExpanded = expanded;
                    [collectionView reloadItemsAtIndexPaths:@[indexPath]];
                }];
                return handupCell;
            } else {
                DTMultiMeetingMiniCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[DTMultiMeetingMiniCell reuseIdentifier] forIndexPath:indexPath];
                DTMultiChatItemModel *itemModel = self.broadcasters[(NSUInteger)indexPath.item - 1];
                cell.itemModel = itemModel;
                [cell setDisplayBackground:NO displayCorner:NO];
                return cell;
            }
        } else {
            DTMultiMeetingMiniCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:[DTMultiMeetingMiniCell reuseIdentifier] forIndexPath:indexPath];
            DTMultiChatItemModel *itemModel = self.broadcasters[(NSUInteger)indexPath.item];
            cell.itemModel = itemModel;
            [cell setDisplayBackground:NO displayCorner:NO];
            return cell;
        }
        
    }
    return [[UICollectionViewCell alloc] init];
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
  sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.item == 0 && self.getHangupList.count > 0) {
        NSArray *hands = self.getHangupList;
        NSInteger headerHeight = 44;
        NSInteger controlHeight = 25;
        CGFloat height = 0;
        if (hands.count > maxExpandCount) {
            // 大于数量分2部
            if (self.isHandupExpanded) {
                height = hands.count * 44 + headerHeight + controlHeight;
            } else {
                height = maxExpandCount * 44 + headerHeight + controlHeight;
            }
        } else {
            height = hands.count * 44 + headerHeight + 8;
        }
        return CGSizeMake(collectionView.bounds.size.width, height);
    }
    
    return self.adjustCellSize;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {

    if (self.meetingViewDelegate && [self.meetingViewDelegate respondsToSelector:@selector(meetingView:didSelectItemAtItemModel:)]) {
        DTMultiChatItemModel *itemModel = nil;
        if (self.mode == DTMultiMeetingModeMini) {
            if (self.isLiveStream) {
                if (indexPath.section == 0) {
                    itemModel = self.handupAudiences[(NSUInteger)indexPath.item];
                } else {
                    itemModel = self.broadcasters[(NSUInteger)indexPath.item];
                }
            } else {
                itemModel = self.broadcasters[(NSUInteger)indexPath.item];
            }
        } else {
            itemModel = self.broadcasters[(NSUInteger)indexPath.item];
        }
        [self.meetingViewDelegate meetingView:self didSelectItemAtItemModel:itemModel];
    }
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView 
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath {

    if (self.mode == DTMultiMeetingModeDefault) {
        return nil;
    }
    
    if (indexPath.section == 1) {
        return nil;
    }
 
    UICollectionReusableView *supplementaryView;
 
    if ([kind isEqualToString:UICollectionElementKindSectionHeader]) {
   
        DTHandupGuestHeader *headerView = (DTHandupGuestHeader *)[collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:DTHandupGuestHeader.reuseIdentifier forIndexPath:indexPath];
        [headerView updateGuestCount:self.handupAudiences.count];
        
        supplementaryView = headerView;
     } else if ([kind isEqualToString:UICollectionElementKindSectionFooter]){
   
         DTHandupGuestFooter *footerView = (DTHandupGuestFooter *)[collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:DTHandupGuestFooter.reuseIdentifier forIndexPath:indexPath];
         
         supplementaryView = footerView;
     }
     
     return supplementaryView;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {

    if (self.mode == DTMultiMeetingModeDefault) {
        return CGSizeZero;
    }
    
    if (section == 1) {
        return CGSizeZero;
    }
    
    if (self.handupAudiences.count == 0) {
        return CGSizeZero;
    }
    
    return CGSizeMake(self.adjustCellSize.width, 32);
}
 
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section {

    if (self.mode == DTMultiMeetingModeDefault) {
        return CGSizeZero;
    }
    
    if (section == 1) {
        return CGSizeZero;
    }
    
    if (self.handupAudiences.count == 0) {
        return CGSizeZero;
    }
    
    return CGSizeMake(self.adjustCellSize.width, 4);
}



- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    
    if (!self.meetingViewDelegate || ![self.meetingViewDelegate respondsToSelector:@selector(meetingViewWillBeginDragging:)]) {
        return;
    }
    
    [self.meetingViewDelegate meetingViewWillBeginDragging:self];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    
    if (!self.meetingViewDelegate || ![self.meetingViewDelegate respondsToSelector:@selector(meetingViewDidEndDragging:)]) {
        return;
    }
    [self.meetingViewDelegate meetingViewDidEndDragging:self];
}

@end
