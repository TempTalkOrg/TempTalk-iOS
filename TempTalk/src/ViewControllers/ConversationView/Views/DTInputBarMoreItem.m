//
//  DTInputBarMoreCell.m
//  Wea
//
//  Created by Ethan on 2022/2/15.
//

#import "DTInputBarMoreItem.h"
#import <TTMessaging/Theme.h>
#import "UIColor+OWS.h"

@implementation DTInputToolBarMoreItem

- (instancetype)initWithTitle:(NSString *)title
                    imageName:(NSString *)imageName
                     itemType:(DTToolBarMoreItemType)itemType
                       action:(nullable DTInputBarMoreItemAction)action {
    
    if (self = [super init]) {
        _title = title;
        _imageName = imageName;
        _itemType = itemType;
        _action = action;
    }
    
    return self;
}

@end
