//
//  HomeEmptyBoxView.h
//  Wea
//
//  Created by Ethan on 2021/11/11.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface HomeEmptyBoxView : UIView

@property (nonatomic, copy) NSString *emptyText;

- (void)applyTheme;

@end

NS_ASSUME_NONNULL_END
