//
//  DTLayoutButton.h
//  Signal
//
//  Created by Ethan on 2022/3/12.
//

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, DTButtonTitleAlignmentType) {
    
    DTButtonTitleAlignmentTypeLeft,
    DTButtonTitleAlignmentTypeRight,
    DTButtonTitleAlignmentTypeTop,
    DTButtonTitleAlignmentTypeBottom
};


NS_ASSUME_NONNULL_BEGIN

@interface DTLayoutButton : UIButton

@property (nonatomic, assign) CGFloat spacing;
@property (nonatomic, assign) DTButtonTitleAlignmentType titleAlignment;

@end

NS_ASSUME_NONNULL_END
