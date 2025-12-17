//
//  DTHomeViewController.h
//  Signal
//
//  Created by Ethan on 2022/10/19.
//  Copyright © 2022 Difft. All rights reserved.
//

#import <TTMessaging/TTMessaging.h>
@class HomeViewController;

NS_ASSUME_NONNULL_BEGIN

@interface DTHomeViewController : OWSViewController

@property (nonatomic, assign) BOOL isFromRegistration;
@property (nonatomic, readonly) HomeViewController *conversationVC;

- (void)logWindowHierarchyWithTag:(nullable NSString *)tag;

@end

NS_ASSUME_NONNULL_END
