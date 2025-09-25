//
//  DTLayoutButton.m
//  Signal
//
//  Created by Ethan on 2022/3/12.
//

#import "DTLayoutButton.h"

@implementation DTLayoutButton

- (instancetype)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    if (self) {
        self.titleAlignment = DTButtonTitleAlignmentTypeLeft;
    }
    return self;
}

- (instancetype)init {
    
    DTLayoutButton *btn = [[DTLayoutButton alloc] initWithFrame:CGRectZero];
    
    return btn;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGSize selfSize = self.frame.size;
    CGFloat selfWidth = selfSize.width;
    CGFloat selfHeight = selfSize.height;
    
    CGFloat titleWidth = [self.titleLabel.text boundingRectWithSize:CGSizeMake(MAXFLOAT, self.titleLabel.frame.size.height)
                                                            options:NSStringDrawingUsesLineFragmentOrigin
                                                         attributes:@{NSFontAttributeName : self.titleLabel.font} context:nil].size.width;
    CGSize titleLabelSize = self.titleLabel.frame.size;
    CGFloat titleLabelWidth = MIN(selfWidth, titleWidth);
    CGFloat titleLabelHeight = titleLabelSize.height;
    
    CGSize imageViewSize = self.imageView.frame.size;
    CGFloat imageViewWidth = imageViewSize.width;
    CGFloat imageViewHeight = imageViewSize.height;
    
    CGFloat totalWidth = imageViewWidth + self.spacing + titleLabelWidth;
    CGFloat totalHeight = imageViewHeight + self.spacing + titleLabelHeight;
    CGFloat verticalTopMargin = (selfHeight - totalHeight) / 2;
    CGFloat horizontalLeftMargin = (selfWidth - totalWidth) / 2;

    CGFloat titleLabelX = 0;
    CGFloat titleLabelY = 0;
    CGFloat imageViewX = 0;
    CGFloat imageViewY = 0;
    
    if (self.titleAlignment == DTButtonTitleAlignmentTypeLeft) {
        titleLabelY = (selfHeight - titleLabelHeight) / 2;
        titleLabelX = horizontalLeftMargin;
        
        imageViewX = titleLabelX + titleLabelWidth + self.spacing;
        imageViewY = (selfHeight - imageViewHeight) / 2;
    }

    if (self.titleAlignment == DTButtonTitleAlignmentTypeRight) {
        imageViewX = horizontalLeftMargin;
        imageViewY = (selfHeight - imageViewHeight) / 2;
        
        titleLabelY = (selfHeight - titleLabelHeight) / 2;
        titleLabelX = imageViewX + imageViewWidth + self.spacing;
    }

    if (self.titleAlignment == DTButtonTitleAlignmentTypeTop) {
        titleLabelY = verticalTopMargin;
        titleLabelX = (selfWidth - titleLabelWidth) / 2;
        
        imageViewY = verticalTopMargin + titleLabelHeight + self.spacing;
        imageViewX = (selfWidth - imageViewWidth) / 2;
    }

    if (self.titleAlignment == DTButtonTitleAlignmentTypeBottom) {
        imageViewX = (selfWidth - imageViewWidth) / 2;
        imageViewY = verticalTopMargin;
        
        titleLabelX = (selfWidth - titleLabelWidth) / 2;
        titleLabelY = verticalTopMargin + imageViewHeight + self.spacing;
    }
    
    self.titleLabel.frame = CGRectMake(titleLabelX, titleLabelY, titleLabelWidth, titleLabelHeight);
    
    self.imageView.frame = CGRectMake(imageViewX, imageViewY, imageViewWidth, imageViewHeight);
}

@end
