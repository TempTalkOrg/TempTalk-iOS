//
//  DTImageBrowserView.h
//  Signal
//
//  Created by hornet on 2022/7/20.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <UIKit/UIKit.h>
@class TSThread;

NS_ASSUME_NONNULL_BEGIN

/// Single picture's info.
@interface DTImageViewModel : NSObject
@property (nonatomic, strong) UIView *thumbView;
@property (nonatomic, assign) CGSize largeImageSize;
@property (nonatomic, strong) NSURL *largeImageURL;
@property (nonatomic, strong, nullable) UIImage *image;
@property (nullable, copy, nonatomic) NSDictionary *avatar;
@property (nullable, strong, nonatomic) NSString *receptid;
@property (nullable, strong, nonatomic) TSThread *thread;
@end

@interface DTImageBrowserView : UIView
@property (nonatomic, readonly) NSArray<DTImageViewModel*> *groupItems;
@property (nonatomic, readonly) NSInteger currentPage;
@property (nonatomic, assign) BOOL blurEffectBackground;


- (instancetype)init UNAVAILABLE_ATTRIBUTE;
- (instancetype)initWithFrame:(CGRect)frame UNAVAILABLE_ATTRIBUTE;
+ (instancetype)new UNAVAILABLE_ATTRIBUTE;
- (instancetype)initWithGroupItems:(NSArray *)groupItems;

//目前只是支持单张图片，多张图片有问题 还没来得及修复
- (void)presentFromImageView:(UIView *)fromView
                 toContainer:(UIView *)container
                    animated:(BOOL)animated
                  completion:(void (^ __nullable)(void))completion;

- (void)updateCurrentItemWith:(DTImageViewModel *)viewModel;
- (void)updateCurrentImage:(UIImage *)image;
- (void)dismissAnimated:(BOOL)animated completion:(void (^ __nullable)(void))completion;
- (void)dismiss;
@end




NS_ASSUME_NONNULL_END
