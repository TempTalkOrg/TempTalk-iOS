//
//  DTConversationPinView.h
//  Wea
//
//  Created by Ethan on 2022/3/14.
//

#import <UIKit/UIKit.h>
@class DTConversationPinView;
@class TSMessage;

NS_ASSUME_NONNULL_BEGIN

@protocol DTConversationPinDelegate <NSObject>

- (NSArray <TSMessage *> *)pinnedMessagesForPreview;

- (void)pinView:(DTConversationPinView *)pinView didSelectIndex:(NSUInteger)index;

- (void)rightItemActionOfPinView:(DTConversationPinView *)pinView;

@end

@interface DTConversationPinView : UIView

@property (nonatomic, weak) id<DTConversationPinDelegate> delegate;
    
- (void)addPinViewToSuperview:(UIView *)superview
                     animated:(BOOL)animated
                      handler:(void(^)(void))handler;
- (void)removePinViewHandler:(void(^)(void))handler;

- (void)reloadData;

- (void)applyTheme;


@end

NS_ASSUME_NONNULL_END
