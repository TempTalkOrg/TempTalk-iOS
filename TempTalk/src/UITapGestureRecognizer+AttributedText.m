//
//  UITapGestureRecognizer+AttributedText.m
//  Wea
//
//  Created by Kris.s on 2021/12/25.
//

#import "UITapGestureRecognizer+AttributedText.h"

@implementation UITapGestureRecognizer (AttributedText)

/**
 Returns YES if the tap gesture was within the specified range of the attributed text of the label.
 */
- (BOOL)didTapAttributedTextInLabel:(UILabel *)label inRanges:(NSArray *)ranges {
    NSParameterAssert(label != nil);

    CGSize labelSize = label.bounds.size;
    // create instances of NSLayoutManager, NSTextContainer and NSTextStorage
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:CGSizeZero];
    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:label.attributedText];

    // configure layoutManager and textStorage
    [layoutManager addTextContainer:textContainer];
    [textStorage addLayoutManager:layoutManager];

    // configure textContainer for the label
    textContainer.lineFragmentPadding = 0.0;
    textContainer.lineBreakMode = label.lineBreakMode;
    textContainer.maximumNumberOfLines = (NSUInteger)label.numberOfLines;
    textContainer.size = labelSize;

    // find the tapped character location and compare it to the specified range
    CGPoint locationOfTouchInLabel = [self locationInView:label];
    CGRect textBoundingBox = [layoutManager usedRectForTextContainer:textContainer];
    CGPoint textContainerOffset = CGPointMake((labelSize.width - textBoundingBox.size.width) * 0.5 - textBoundingBox.origin.x,
                                              (labelSize.height - textBoundingBox.size.height) * 0.5 - textBoundingBox.origin.y);
    CGPoint locationOfTouchInTextContainer = CGPointMake(locationOfTouchInLabel.x - textContainerOffset.x,
                                                         locationOfTouchInLabel.y - textContainerOffset.y);
    NSUInteger indexOfCharacter = [layoutManager characterIndexForPoint:locationOfTouchInTextContainer
                                                            inTextContainer:textContainer
                                   fractionOfDistanceBetweenInsertionPoints:nil];
    
    __block BOOL result = NO;
    [ranges enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ([obj isKindOfClass:NSValue.class]) {
          
            NSRange range = ((NSValue *)obj).rangeValue;
            if (range.location != NSNotFound &&
                range.length != NSNotFound &&
                NSLocationInRange(indexOfCharacter, range)) {
                
                result = YES;
                *stop = YES;
            }
        }
    }];
    
    return result;
}

@end
