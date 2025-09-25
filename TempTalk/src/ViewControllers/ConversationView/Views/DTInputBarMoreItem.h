//
//  DTInputBarMoreCell.h
//  Wea
//
//  Created by Ethan on 2022/2/15.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^DTInputBarMoreItemAction)(void);

typedef enum : NSUInteger {
    DTToolBarMoreItemTypePhoto,
    DTToolBarMoreItemTypeCamera,
    DTToolBarMoreItemTypeVoiceCall,
    DTToolBarMoreItemTypeVideoCall,
    DTToolBarMoreItemTypeContact,
    DTToolBarMoreItemTypeFile,
    DTToolBarMoreItemTypeConfide,
    DTToolBarMoreItemTypeMention
} DTToolBarMoreItemType;

@interface DTInputToolBarMoreItem : NSObject

@property (nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) NSString *imageName;
@property (nonatomic, readonly) DTToolBarMoreItemType itemType;
@property (nonatomic, copy, nullable) DTInputBarMoreItemAction action;

- (instancetype)initWithTitle:(NSString *)title
                    imageName:(NSString *)imageName
                     itemType:(DTToolBarMoreItemType)itemType
                       action:(nullable DTInputBarMoreItemAction)action;

@end

NS_ASSUME_NONNULL_END
