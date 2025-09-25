//
//  DTConversationNameView.h
//  Signal
//
//  Created by Ethan on 2022/8/30.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <TTServiceKit/DTGroupMemberEntity.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DTConversationNameType) {
    DTConversationNameTypeContact = 0,
    DTConversationNameTypeGroup
};

@interface DTConversationNameView : UIStackView

@property (nonatomic, assign) DTConversationNameType type;

/// 控件id,接到通知时判断是否需要更新
@property (nonatomic, copy) NSString *identifier;
/// 用户名，和attributeName不同时使用，后使用的会覆盖先使用的
@property (nonatomic, strong, nullable) NSString *name;
@property (nonatomic, strong, nullable) UIFont *nameFont;
@property (nonatomic, strong, nullable) UIColor *nameColor;
@property(nonatomic) NSLineBreakMode lineBreakMode;

/// 富文本name
@property (nonatomic, strong, nullable) NSAttributedString *attributeName;
/// RAPID标签
@property (nonatomic, assign) DTGroupRAPIDRole rapidRole;
/// 是否是外部用户(VIP/other subteam...)
@property (nonatomic, assign, getter=isExternal) BOOL external;

- (void)prepareForReuse;

@end

NS_ASSUME_NONNULL_END
