//
//  DTSelectedAccountToolView.h
//  Wea
//
//  Created by hornet on 2022/1/5.
//

#import <UIKit/UIKit.h>


NS_ASSUME_NONNULL_BEGIN

@class DTSelectedAccountToolView;
@protocol DTSelectedAccountToolViewDelegate <NSObject>
- (void)dtSelectedAccountToolView:(DTSelectedAccountToolView *)toolView collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath;
@optional
- (void)dtSelectedAccountToolView:(DTSelectedAccountToolView *)toolView okBtnClick:(UIButton*)sender;
@end

@interface DTSelectedAccountToolView : UIView
@property(nonatomic,weak) id <DTSelectedAccountToolViewDelegate> toolViewDelegate;
- (void)showOKBtn:(BOOL)show;
- (instancetype)initWithDataSource:(NSArray *)dataSource;
- (void)reloadWithData:(NSArray *)datasource;
@end

NS_ASSUME_NONNULL_END
