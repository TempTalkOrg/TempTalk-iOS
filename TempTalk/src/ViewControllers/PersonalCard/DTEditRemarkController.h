//
//  DTEditRemarkController.h
//  Wea
//
//  Created by hornet on 2022/12/19.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <TTMessaging/TTMessaging.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTEditRemarkController : OWSViewController
- (void)configureWithRecipientId:(NSString *)recipientId defaultRemarkText:(NSString *)remark;
@end

NS_ASSUME_NONNULL_END
