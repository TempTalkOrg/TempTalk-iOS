//
//  ContactEditingViewController.h
//  Signal
//
//  Created by anonymous on 2019/4/3.
//  Copyright © 2019 anonymous. All rights reserved.
//

#import <TTMessaging/OWSViewController.h>

NS_ASSUME_NONNULL_BEGIN

@interface ContactEditingViewController : OWSViewController

- (void)configureWithRecipientId:(NSString *)recipientId;

@end

NS_ASSUME_NONNULL_END
