//
//  Copyright (c) 2018 Open Whisper Systems. All rights reserved.
//


//#import "ConversationItemMacro.h"
#import <TTServiceKit/DTReplyModel.h>
NS_ASSUME_NONNULL_BEGIN

// View model which has already fetched any attachments.
@interface OWSQuotedReplyModel : DTReplyModel

@property (nonatomic, assign) BOOL manualBuild ;//是否是手动构建

@property (nonatomic,assign,getter=isLongPressed) BOOL longPressed;

@end

NS_ASSUME_NONNULL_END
