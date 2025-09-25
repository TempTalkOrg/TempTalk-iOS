//
//  DTPinPageControl.h
//  Wea
//
//  Created by Ethan on 2022/3/15.
//

#import <UIKit/UIKit.h>
@class DTPinPageControl;

NS_ASSUME_NONNULL_BEGIN

@protocol DTPinPageControlDelegate <NSObject>

- (NSInteger)numberOfPages;

- (void)pageControl:(DTPinPageControl *)pageControl scrollToIndex:(NSInteger)index;

@end

@interface DTPinPageControl : UIView

@property (nonatomic, weak) id<DTPinPageControlDelegate> delegate;

- (void)scrollToIndex:(NSInteger)index animated:(BOOL)animated;

- (void)reloadPageNumbers;

@end

NS_ASSUME_NONNULL_END
