//
//  DTInviteRequestHandler.h
//  TempTalk
//
//  Created by Kris.s on 2025/4/24.
//  Copyright © 2025 Difft. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DTInviteRequestHandler : NSObject

@property(nonatomic, strong) UIViewController *sourceVc;

- (instancetype)initWithSourceVc:(UIViewController *)sourceVc;

- (void)queryUserAccountByInviteCode:(NSString *)inviteCode;

@end

NS_ASSUME_NONNULL_END
